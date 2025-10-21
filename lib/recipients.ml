(** Recipient management utilities *)
open Util.Show

let add_recipients_if_none_exists recipients secret_path =
  match Storage.Secrets.no_keys_file (Path.dirname secret_path) with
  | false -> ()
  | true ->
    (* also adds root group by default for all new secrets *)
    let root_recipients_names = Storage.Secrets.recipients_of_group_name ~map_fn:Fun.id "@root" in
    let () = Devkit.eprintfn "\nI: using recipient group @root for secret %s" (show_path secret_path) in
    (* avoid repeating names if the user creating the secret is already in the root group *)
    let recipients_names =
      List.filter_map
        (fun r ->
          match List.mem r.Age.name root_recipients_names with
          | true -> None
          | false ->
            let () = Printf.eprintf "I: using recipient %s for secret %s\n" r.name (show_path secret_path) in
            Some r.name)
        recipients
    in
    let () = flush stderr in
    let recipients_names_with_root_group = "@root" :: (recipients_names |> List.sort String.compare) in
    let recipients_file_path = Storage.Secrets.get_recipients_file_path secret_path in
    let (_ : Path.t) = Path.ensure_parent recipients_file_path in
    Devkit.Control.with_open_out_txt (show_path recipients_file_path) (fun oc ->
        List.iter (fun line -> Printf.fprintf oc "%s\n" line) recipients_names_with_root_group)

let rewrite_recipients_file secret_name new_recipients_list =
  let secret_path = path_of_secret_name secret_name in
  let sorted_base_recipients = Storage.Secrets.get_recipients_names secret_path in
  let secret_recipients_file = Storage.Secrets.get_recipients_file_path secret_path in
  let (_ : Path.t) = Path.ensure_parent secret_recipients_file in
  (* Deduplicate and sort recipients *)
  let deduplicated_recipients = List.sort_uniq String.compare new_recipients_list in
  let () =
    Devkit.Control.with_open_out_txt (show_path secret_recipients_file) (fun oc ->
        List.iter (fun line -> Printf.fprintf oc "%s\n" line) deduplicated_recipients)
  in
  let sorted_updated_recipients_names = Storage.Secrets.get_recipients_names secret_path in
  if sorted_base_recipients <> sorted_updated_recipients_names then (
    let secrets_affected = Storage.Secrets.get_secrets_in_folder (Path.folder_of_path secret_path) in
    (* it might be that we are creating a secret in a new folder and adding new recipients,
       so we have no extra affected secrets. Only refresh if there are affected secrets *)
    if secrets_affected <> [] then Storage.Secrets.refresh ~force:true ~verbose:false secrets_affected else ())
  else prerr_endline "I: no changes made to the recipients"

let edit_recipients secret_name =
  (* takes two sorted lists and returns three lists:
      first is items unique to l1, second is items unique to l2, third is items in both l1 and l2.

      Preserves the order in the outputs *)
  let diff_intersect_lists l1 r1 =
    let rec diff accl accr accb left right =
      match left, right with
      | [], [] -> List.rev accl, List.rev accr, List.rev accb
      | [], rh :: rt -> diff accl (rh :: accr) accb [] rt
      | lh :: lt, [] -> diff (lh :: accl) accr accb lt []
      | lh :: lt, rh :: rt ->
        let comp = compare lh rh in
        if comp < 0 then diff (lh :: accl) accr accb lt right
        else if comp > 0 then diff accl (rh :: accr) accb left rt
        else diff accl accr (lh :: accb) lt rt
    in
    diff [] [] [] l1 r1
  in
  let path_to_secret = path_of_secret_name secret_name in
  let sorted_base_recipients =
    try Storage.Secrets.get_recipients_names path_to_secret with exn -> Util.Secret.die_failed_get_recipients ~exn ""
  in
  let recipients_groups, current_recipients_names = sorted_base_recipients |> List.partition Age.is_group_recipient in
  let left, right, common = diff_intersect_lists current_recipients_names (Storage.Keys.all_recipient_names ()) in
  let all_available_groups = Storage.Secrets.all_groups_names () |> List.map (fun g -> "@" ^ g) in
  let unused_groups = List.filter (fun g -> not (List.mem g recipients_groups)) all_available_groups in
  let recipient_lines =
    (if recipients_groups = [] then [] else ("# Groups " :: recipients_groups) @ [ "" ])
    @ ("# Recipients " :: common)
    @ [ "" ]
    @ (if left = [] then [] else "#" :: "# Warning, unknown recipients below this line " :: "#" :: left)
    @ "#"
      :: "# Uncomment recipients below to add them. You can also add valid groups names if you want."
      :: "#"
      ::
      (if unused_groups = [] then []
       else ("# Available groups:" :: List.map (fun g -> "# " ^ g) unused_groups) @ [ "#" ])
    @ if right = [] then [] else "# Available users:" :: List.map (fun r -> "# " ^ r) right
  in
  let initial_content =
    match recipient_lines with
    | [] -> ""
    | lines -> String.concat "\n" lines ^ "\n"
  in
  let validate_recipients content =
    (* Parse recipients from input, filtering out comments and empty lines *)
    let recipients_list =
      String.split_on_char '\n' content
      |> List.filter_map (fun line ->
             let trimmed = String.trim line in
             if trimmed = "" || String.starts_with ~prefix:"#" trimmed then None else Some trimmed)
    in
    match Validation.validate_recipients_for_editing recipients_list with
    | Error e -> Error e
    | Ok () -> Ok recipients_list
  in
  match Util.Editor.edit_with_validation ~initial:initial_content ~validate:validate_recipients () with
  | Ok new_recipients_list -> rewrite_recipients_file secret_name new_recipients_list
  | Error _ -> prerr_endline "E: no recipients provided"

let add_recipients_to_secret secret_name recipients_to_add =
  let secret_path = path_of_secret_name secret_name in
  Util.Secret.check_path_exists_or_die secret_name secret_path;
  Invariant.run_if_recipient ~op_string:"add recipients" ~path:secret_path ~f:(fun () ->
      let () =
        match Validation.validate_recipients_for_commands recipients_to_add with
        | Error msg -> Shell.die "%s" msg
        | Ok () -> ()
      in
      let current_recipients = Storage.Secrets.get_recipients_names secret_path in
      let new_recipients = List.sort_uniq String.compare (current_recipients @ recipients_to_add) in
      match List.equal String.equal current_recipients new_recipients with
      | true -> prerr_endline "I: no changes made - all specified recipients are already present"
      | false ->
        let () = rewrite_recipients_file secret_name new_recipients in
        let added_count = List.length new_recipients - List.length current_recipients in
        Devkit.eprintfn "I: added %d recipient%s" added_count (if added_count = 1 then "" else "s"))

let remove_recipients_from_secret secret_name recipients_to_remove =
  let secret_path = path_of_secret_name secret_name in
  Util.Secret.check_path_exists_or_die secret_name secret_path;
  Invariant.run_if_recipient ~op_string:"remove recipients" ~path:secret_path ~f:(fun () ->
      let current_recipients = Storage.Secrets.get_recipients_names secret_path in
      let new_recipients = List.filter (fun r -> not (List.mem r recipients_to_remove)) current_recipients in
      (* Check for non-existent recipients to warn about *)
      let non_existent = List.filter (fun r -> not (List.mem r current_recipients)) recipients_to_remove in
      if new_recipients = [] then Shell.die "E: cannot remove all recipients - at least one recipient must remain"
      else if current_recipients = new_recipients then (
        match non_existent with
        | [] -> prerr_endline "I: no changes made - specified recipients were already absent"
        | _ -> Shell.die "E: recipients not found: %s" (String.concat ", " non_existent))
      else (
        (* Show warnings for non-existent recipients before proceeding *)
        let () =
          if non_existent <> [] then
            Devkit.eprintfn "W: recipients not found to remove: %s" (String.concat ", " non_existent)
          else ()
        in
        let () = rewrite_recipients_file secret_name new_recipients in
        let removed_count = List.length current_recipients - List.length new_recipients in
        Devkit.eprintfn "I: removed %d recipient%s" removed_count (if removed_count = 1 then "" else "s")))

let list_recipient_secrets ?(verbose = false) recipients_names =
  if recipients_names = [] then Shell.die "E: Must specify at least one recipient name";
  let number_of_recipients = List.length recipients_names in
  let all_recipient_names = Storage.Keys.all_recipient_names () in
  List.iter
    (fun recipient_name ->
      let open Storage in
      match List.mem recipient_name all_recipient_names, Age.is_group_recipient recipient_name with
      | false, false -> Devkit.eprintfn "E: no such recipient %s" recipient_name
      | _ ->
      match Secrets.get_secrets_for_recipient recipient_name with
      | [] -> Devkit.eprintfn "\nNo secrets found for %s" recipient_name
      | secrets ->
        let () =
          if number_of_recipients > 1 then Devkit.eprintfn "\nSecrets which %s is a recipient of:" recipient_name
          else ()
        in
        let sorted = List.sort Secret_name.compare secrets in
        let print_secret secret =
          match verbose with
          | false -> Printf.printf "%s\n" (show_name secret)
          | true ->
          try
            let plaintext = Util.Secret.decrypt_silently secret in
            Printf.printf "%s\n" (Secret.Validation.validity_to_string (show_name secret) plaintext)
          with _ -> Printf.printf "🚨 %s [ WARNING: failed to decrypt ]\n" (show_name secret)
        in
        let () = List.iter print_secret sorted in
        flush stderr)
    recipients_names

let list_recipients path expand_groups =
  let string_path = show_path path in
  let print_from_recipient_list recipients =
    List.iter
      (fun (r : Age.recipient) ->
        (match r.keys with
        | [] -> Devkit.eprintfn "W: no keys found for %s" r.name
        | _ -> ());
        print_endline r.name)
      recipients
  in
  match Age.is_group_recipient string_path with
  | true ->
    Storage.Secrets.recipients_of_group_name ~map_fn:Storage.Secrets.recipient_of_name string_path
    |> print_from_recipient_list
  | false ->
  match Storage.Secrets.secret_exists_at path || Storage.Secrets.get_secrets_tree path <> [] with
  | false -> Shell.die "E: no such secret %s" (show_path path)
  | true ->
  match expand_groups with
  | true ->
    (match Storage.Secrets.get_recipients_from_path_exn path with
    | exception exn -> Util.Secret.die_failed_get_recipients ~exn ""
    | [] -> Util.Secret.die_no_recipients_found path
    | recipients -> print_from_recipient_list recipients)
  | false ->
  match Storage.Secrets.get_recipients_names path with
  | [] -> Util.Secret.die_no_recipients_found path
  | recipients_names ->
    List.iter
      (fun recipient_name ->
        let recipient_keys =
          match Age.is_group_recipient recipient_name with
          | false -> Storage.Keys.keys_of_recipient recipient_name
          | true ->
          try
            (* we don't need the group recipients, just to know that there are some *)
            let (_ : Age.recipient list) =
              Storage.Secrets.recipients_of_group_name ~map_fn:Storage.Secrets.recipient_of_name recipient_name
            in
            [ Age.Key.inject "" ]
          with exn ->
            Devkit.printfn "E: couldn't retrieve recipients for group %s. Reason: %s" recipient_name
              (Printexc.to_string exn);
            []
        in
        (match recipient_keys with
        | [] -> Devkit.eprintfn "W: no keys found for %s" recipient_name
        | _ -> ());
        print_endline recipient_name)
      recipients_names
