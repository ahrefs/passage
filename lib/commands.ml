open Printf
open Util.Show

let die = Exn.die
let verbose_eprintlf = Util.verbose_eprintlf
let eprintfn = Util.eprintfn
let printfn = Util.printfn

module Init = struct
  let init ?use_sudo () =
    try
      (* create private and pub key, ask for user's name *)
      let () =
        print_endline
          {|
Welcome to passage initial setup.

Passage will now create the default dirs for secrets and recipients keys.
A recipient identity will also be added, as well as an empty group file for root users.

The layout will be:
~/.config/passage
├── identity.key
├── keys
│   └── root.group
│   └── <user_name>.pub
└── secrets

The location of these can be overriden using environment variables. Please check `passage --help` for details.

What should be the name used for your recipient identity?|}
      in
      let user_name =
        let input = String.trim @@ In_channel.input_all stdin in
        let buf = Buffer.create (String.length input) in
        String.iter
          (fun c ->
            match c with
            | ' ' -> Buffer.add_char buf '_'
            | '\n' -> ()
            | c -> Buffer.add_string buf (Char.escaped c))
          input;
        Buffer.contents buf
      in
      let () = Shell.age_generate_identity_key_root_group_exn ?use_sudo user_name in
      verbose_eprintlf "I: Passage setup completed.\n"
    with exn ->
      (* Error out and delete everything, so we can start fresh next time *)
      FileUtil.rm ~recurse:true [ Lazy.force !Config.base_dir ];
      die ~exn "E: Passage init failed"
end

module Get = struct
  let get_secret ?use_sudo ?expected_kind ?line_number ?(with_comments = false) ?(trim_new_line = false) secret_name =
    let secret_exists =
      try Storage.Secrets.secret_exists secret_name with exn -> die ~exn "E: %s" (show_name secret_name)
    in
    (match secret_exists with
    | false ->
      if Path.is_directory Storage.Secrets.(to_path secret_name |> Path.abs) then
        die "E: %s is a directory" (show_name secret_name)
      else die "E: no such secret: %s" (show_name secret_name)
    | true -> ());
    let get_line_exn secret line_number =
      if line_number < 1 then die "Line number should be greater than 0";
      let lines = String.split_on_char '\n' secret in
      (* user specified line number is 1-indexed *)
      match List.nth_opt lines (line_number - 1) with
      | None -> die "There is no secret at line %d" line_number
      | Some l -> l
    in
    let plaintext =
      try Storage.Secrets.decrypt_exn ?use_sudo secret_name
      with exn -> die ~exn "E: failed to decrypt %s" (show_name secret_name)
    in
    let secret =
      match with_comments, line_number with
      | true, None -> plaintext
      | true, Some ln -> get_line_exn plaintext ln
      | false, _ ->
        let secret =
          try Secret.Validation.parse_exn plaintext
          with exn -> die ~exn "E: failed to parse %s" (show_name secret_name)
        in
        let kind = secret.kind in
        (* we can have this validation only here because we don't have expected kinds when using the cat command
            (the with_comments = true branch) *)
        (match Option.is_some expected_kind && Option.get expected_kind <> kind with
        | true ->
          die "E: %s is expected to be a %s secret but it is a %s secret" (show_name secret_name)
            (Secret.kind_to_string @@ Option.get expected_kind)
            (Secret.kind_to_string kind)
        | false -> ());
        (match line_number with
        | None -> secret.text
        | Some ln -> get_line_exn secret.text ln)
    in
    let secret =
      match trim_new_line, String.ends_with ~suffix:"\n" secret with
      (* some of the older secrets were not trimmed before storing, so they have trailing new lines *)
      | true, true -> String.sub secret 0 (String.length secret - 1)
      | false, false -> sprintf "%s\n" secret
      | true, false | false, true -> secret
    in
    secret
end

module List_ = struct
  let list_secrets path =
    let raw_path = show_path path in
    let secret_exists = try Storage.Secrets.secret_exists_at path with _exn -> false in
    match secret_exists with
    | true -> [ Storage.Secrets.(name_of_file (Path.abs path) |> show_name) ]
    | false ->
      let is_dir = try Path.is_directory (Path.abs path) with exn -> die ~exn "E: %s" raw_path in
      (match is_dir with
      | true -> Storage.(Secrets.get_secrets_tree path |> List.sort Secret_name.compare) |> List.map show_name
      | false -> die "No secrets at %s" raw_path)
end

module Recipients = struct
  let add_recipients_if_none_exists recipients secret_path =
    match Storage.Secrets.no_keys_file (Path.dirname secret_path) with
    | false -> ()
    | true ->
      (* also adds root group by default for all new secrets *)
      let root_recipients_names = Storage.Secrets.recipients_of_group_name_exn ~map_fn:Fun.id "@root" in
      let () = eprintfn "\nI: using recipient group @root for secret %s" (show_path secret_path) in
      (* avoid repeating names if the user creating the secret is already in the root group *)
      let recipients_names =
        List.filter_map
          (fun r ->
            match List.mem r.Age.name root_recipients_names with
            | true -> None
            | false ->
              let () = eprintfn "I: using recipient %s for secret %s" r.name (show_path secret_path) in
              Some r.name)
          recipients
      in
      let () = flush stderr in
      let recipients_names_with_root_group = "@root" :: (recipients_names |> List.sort String.compare) in
      let recipients_file_path = Storage.Secrets.get_recipients_file_path secret_path in
      let (_ : Path.t) = Path.ensure_parent recipients_file_path in
      Util.save_as ~mode:0o666 ~path:(show_path recipients_file_path) @@ fun oc ->
      List.iter (fun line -> Printf.fprintf oc "%s\n" line) recipients_names_with_root_group

  let rewrite_recipients_file ?use_sudo secret_name new_recipients_list =
    let secret_path = path_of_secret_name secret_name in
    let sorted_base_recipients = Storage.Secrets.get_recipients_names secret_path in
    let secret_recipients_file = Storage.Secrets.get_recipients_file_path secret_path in
    let (_ : Path.t) = Path.ensure_parent secret_recipients_file in
    (* Deduplicate and sort recipients *)
    let deduplicated_recipients = List.sort_uniq String.compare new_recipients_list in
    let () =
      Out_channel.with_open_text (show_path secret_recipients_file) (fun oc ->
        List.iter (fun line -> Printf.fprintf oc "%s\n" line) deduplicated_recipients)
    in
    let sorted_updated_recipients_names = Storage.Secrets.get_recipients_names secret_path in
    if sorted_base_recipients <> sorted_updated_recipients_names then (
      let secrets_affected = Storage.Secrets.get_secrets_in_folder (Path.folder_of_path secret_path) in
      (* it might be that we are creating a secret in a new folder and adding new recipients,
         so we have no extra affected secrets. Only refresh if there are affected secrets *)
      if secrets_affected <> [] then Storage.Secrets.refresh ?use_sudo ~force:true ~verbose:false secrets_affected
      else ())
    else prerr_endline "I: no changes made to the recipients"

  let add_recipients_to_secret ?use_sudo secret_name recipients_to_add =
    let secret_path = path_of_secret_name secret_name in
    Util.Secret.check_path_exists_or_die secret_name secret_path;
    Invariant.run_if_recipient ~op_string:"add recipients" ~path:secret_path ~f:(fun () ->
      let () =
        match Validation.validate_recipients_for_commands recipients_to_add with
        | Error msg -> die "%s" msg
        | Ok () -> ()
      in
      let current_recipients = Storage.Secrets.get_recipients_names secret_path in
      let new_recipients = List.sort_uniq String.compare (current_recipients @ recipients_to_add) in
      match List.equal String.equal current_recipients new_recipients with
      | true -> prerr_endline "I: no changes made - all specified recipients are already present"
      | false ->
        let () = rewrite_recipients_file ?use_sudo secret_name new_recipients in
        let added_count = List.length new_recipients - List.length current_recipients in
        eprintfn "I: added %d recipient%s" added_count (if added_count = 1 then "" else "s"))

  let remove_recipients_from_secret ?use_sudo secret_name recipients_to_remove =
    let secret_path = path_of_secret_name secret_name in
    Util.Secret.check_path_exists_or_die secret_name secret_path;
    Invariant.run_if_recipient ~op_string:"remove recipients" ~path:secret_path ~f:(fun () ->
      let current_recipients = Storage.Secrets.get_recipients_names secret_path in
      let new_recipients = List.filter (fun r -> not (List.mem r recipients_to_remove)) current_recipients in
      (* Check for non-existent recipients to warn about *)
      let non_existent = List.filter (fun r -> not (List.mem r current_recipients)) recipients_to_remove in
      if new_recipients = [] then die "E: cannot remove all recipients - at least one recipient must remain"
      else if current_recipients = new_recipients then (
        match non_existent with
        | [] -> prerr_endline "I: no changes made - specified recipients were already absent"
        | _ -> die "E: recipients not found: %s" (String.concat ", " non_existent))
      else (
        (* Show warnings for non-existent recipients before proceeding *)
        let () =
          if non_existent <> [] then eprintfn "W: recipients not found to remove: %s" (String.concat ", " non_existent)
          else ()
        in
        let () = rewrite_recipients_file ?use_sudo secret_name new_recipients in
        let removed_count = List.length current_recipients - List.length new_recipients in
        eprintfn "I: removed %d recipient%s" removed_count (if removed_count = 1 then "" else "s")))

  let list_recipient_secrets ?use_sudo ?(verbose = false) recipients_names =
    if recipients_names = [] then die "E: Must specify at least one recipient name";
    let number_of_recipients = List.length recipients_names in
    let all_recipient_names = Storage.Keys.all_recipient_names () in
    List.iter
      (fun recipient_name ->
        let open Storage in
        match List.mem recipient_name all_recipient_names, Age.is_group_recipient recipient_name with
        | false, false -> eprintfn "E: no such recipient %s" recipient_name
        | _ ->
        match Secrets.get_secrets_for_recipient recipient_name with
        | [] -> eprintfn "\nNo secrets found for %s" recipient_name
        | secrets ->
          let () =
            if number_of_recipients > 1 then eprintfn "\nSecrets which %s is a recipient of:" recipient_name else ()
          in
          let sorted = List.sort Secret_name.compare secrets in
          let print_secret secret =
            match verbose with
            | false -> printfn "%s" (show_name secret)
            | true ->
            try
              let plaintext = Util.Secret.decrypt_silently ?use_sudo secret in
              printfn "%s" (Secret.Validation.validity_to_string (show_name secret) plaintext)
            with _ -> printfn "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret)
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
          | [] -> eprintfn "W: no keys found for %s" r.name
          | _ -> ());
          print_endline r.name)
        recipients
    in
    match Age.is_group_recipient string_path with
    | true ->
      Storage.Secrets.recipients_of_group_name_exn ~map_fn:Storage.Secrets.recipient_of_name string_path
      |> print_from_recipient_list
    | false ->
    match Storage.Secrets.secret_exists_at path || Storage.Secrets.get_secrets_tree path <> [] with
    | false -> die "E: no such secret %s" (show_path path)
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
                Storage.Secrets.recipients_of_group_name_exn ~map_fn:Storage.Secrets.recipient_of_name recipient_name
              in
              [ Age.Key.inject "" ]
            with exn ->
              printfn "E: couldn't retrieve recipients for group %s. Reason: %s" recipient_name (Printexc.to_string exn);
              []
          in
          (match recipient_keys with
          | [] -> eprintfn "W: no keys found for %s" recipient_name
          | _ -> ());
          print_endline recipient_name)
        recipients_names
end

module Refresh = struct
  let refresh_secrets ?use_sudo ?(verbose = false) paths =
    let secrets =
      List.fold_left
        (fun acc path_or_recip ->
          (match Age.is_group_recipient path_or_recip with
            | true ->
              (* we need to clarify if the recipient is a group or a recipient, since we use the same syntax for both *)
              let recipient =
                let r =
                  if String.starts_with ~prefix:"@" path_or_recip then
                    String.sub path_or_recip 1 (String.length path_or_recip - 1)
                  else path_or_recip
                in
                match List.mem r (Storage.Secrets.all_groups_names ()), r = "everyone" with
                | false, false -> r
                | _ -> path_or_recip
              in
              (match Storage.Secrets.get_secrets_for_recipient recipient with
              | [] -> die "E: no secrets found for recipient %s" path_or_recip
              | secrets -> secrets)
            | false ->
              let path =
                try Path.build_rel_path path_or_recip with Failure s -> die "E: invalid path %s: %s" path_or_recip s
              in
              (match Storage.Secrets.get_secrets_tree path with
              | _ :: _ as secrets -> secrets
              | [] ->
              match Storage.Secrets.secret_exists_at path with
              | true -> [ secret_name_of_path path ]
              | false -> die "E: no secrets at %s" path_or_recip))
          @ acc)
        [] paths
    in
    let secrets = List.sort_uniq Storage.Secret_name.compare secrets in
    Storage.Secrets.refresh ?use_sudo ~verbose secrets
end

module Template = struct
  open Template
  let substitute ~template =
    match substitute_all template with
    | Ok substituted_ast -> build_text_from_ast substituted_ast
    | Error failures ->
      let n = List.length failures in
      eprintfn "E: failed to decrypt %d %s:" n (if n = 1 then "secret" else "secrets");
      List.iter (fun (name, msg) -> eprintfn "  - %s: %s" name msg) failures;
      exit 1

  let substitute_file ~template_file =
    let template = parse_file template_file in
    substitute ~template

  let list_template_secrets template_file =
    let tree = try parse_file template_file with exn -> die ~exn "Failed to parse the file" in
    List.filter_map
      (fun node ->
        match node with
        | Template_ast.Text _ -> None
        | Template_ast.Iden secret_name -> Some secret_name)
      tree
    |> List.sort_uniq String.compare
end

module Realpath = struct
  let realpath paths =
    paths
    |> List.map (fun path ->
      let abs_path = Path.abs path in
      if Storage.Secrets.secret_exists_at path then (
        let secret_name = secret_name_of_path path in
        Ok (show_path (Path.abs (Storage.Secrets.agefile_of_name secret_name))))
      else if Path.is_directory abs_path then (
        let str = show_path abs_path in
        if Path.is_dot (Path.build_rel_path (show_path path)) then Ok (Storage.Secrets.get_secrets_dir () ^ "/")
        else Ok (str ^ if String.ends_with ~suffix:"/" str then "" else "/"))
      else Error (sprintf "real path of secret/folder %S not found" (show_path path)))
end

module Rm = struct
  let rm_secrets ~verbose ~paths ~force ?confirm () =
    List.iter
      (fun path ->
        let is_directory = Path.is_directory (Path.abs path) in
        (match Storage.Secrets.secret_exists_at path, is_directory with
        | false, false -> die "E: no secrets exist at %s" (show_path path)
        | _ -> ());
        let string_path = show_path path in
        let r =
          match (not (Unix.isatty Unix.stdin)) || force with
          | true -> Storage.Secrets.rm ~is_directory path
          | false ->
          match confirm with
          | Some f ->
            (match f ~path with
            | true -> Storage.Secrets.rm ~is_directory path
            | false -> Storage.Secrets.Skipped)
          | None -> die "E: please provide a confirmation function for TTY environments"
        in
        match r with
        | Storage.Secrets.Succeeded () -> verbose_eprintlf ~verbose "I: removed %s" string_path
        | Skipped -> eprintfn "I: skipped deleting %s" string_path
        | Failed exn -> die "E: failed to delete %s : %s" string_path (Printexc.to_string exn))
      paths
end

module Search = struct
  let search_secrets ?(verbose = false) ?use_sudo pattern path =
    let secrets = Storage.Secrets.get_secrets_tree path |> List.sort Storage.Secret_name.compare in
    let n_skipped, n_failed, n_matched, matched_secrets =
      List.fold_left
        (fun (n_skipped, n_failed, n_matched, matched_secrets) secret ->
          match Storage.Secrets.search ?use_sudo secret pattern with
          | Succeeded true -> n_skipped, n_failed, n_matched + 1, secret :: matched_secrets
          | Succeeded false -> n_skipped, n_failed, n_matched, matched_secrets
          | Skipped ->
            verbose_eprintlf ~verbose "I: skipped %s" (show_name secret);
            n_skipped + 1, n_failed, n_matched, matched_secrets
          | Failed exn ->
            eprintfn "W: failed to search %s : %s" (show_name secret) (Printexc.to_string exn);
            n_skipped, n_failed + 1, n_matched, matched_secrets)
        (0, 0, 0, []) secrets
    in
    List.rev matched_secrets |> List.iter (fun s -> print_endline (show_name s));
    eprintfn "I: skipped %d secrets, failed to search %d secrets and matched %d secrets" n_skipped n_failed n_matched
end

module Show = struct
  let list_secrets_tree path =
    let full_path = Path.abs path in
    match Path.is_directory full_path, Storage.Secrets.secret_exists_at path with
    | false, false -> die "No secrets at this path : %s" (show_path full_path)
    | false, true -> Get.get_secret ~with_comments:true (secret_name_of_path path)
    | true, _ ->
      let tree = Dirtree.of_path (Path.to_fpath (Path.abs path)) in
      Dirtree.pp tree
end

module Edit = struct
  let new_secret_recipients_notice =
    {|
If you are adding a new secret in a new folder, please keep recipients to a minimum and include the following:
- @root
- yourself
- people who help manage the secret, or people who would have access to it anyway
- people who need access to do their job
- servers/clusters that will consume the secret

If the secret is a staging secret, its only recipient should be @everyone.
|}

  let show_recipients_notice_if_true cond = if cond then prerr_endline new_secret_recipients_notice

  let edit_secret ?use_sudo ?(self_fallback = false) ?(verbose = false) ?allow_retry ~get_updated_secret secret_name =
    let secret_name_str = show_name secret_name in
    let original_secret =
      match Storage.Secrets.secret_exists secret_name with
      | false -> None
      | true ->
      try Some (Storage.Secrets.decrypt_exn ?use_sudo secret_name)
      with exn -> die ~exn "E: failed to decrypt %s" secret_name_str
    in
    try
      let updated_secret = Result.bind (get_updated_secret original_secret) Validation.validate_secret in
      match updated_secret, original_secret with
      | Error e, _ -> die "E: %s" e
      | Ok updated_secret, Some original_secret when updated_secret = original_secret ->
        prerr_endline "I: secret unchanged"
      | Ok updated_secret, _ ->
        let secret_path = path_of_secret_name secret_name in
        let secret_recipients' = Storage.Secrets.get_recipients_from_path_exn secret_path in
        let secret_recipients =
          if secret_recipients' = [] && self_fallback then (
            let own_recipients = Storage.Secrets.recipients_of_own_id ?use_sudo:None () in
            let () = Recipients.add_recipients_if_none_exists own_recipients secret_path in
            Storage.Secrets.get_recipients_from_path_exn secret_path)
          else secret_recipients'
        in
        if secret_recipients = [] then die "E: no recipients specified for this secret"
        else (
          let is_first_secret_in_new_folder = Option.is_none original_secret && secret_recipients' = [] in
          match allow_retry with
          | Some encrypt_with_retry ->
            show_recipients_notice_if_true is_first_secret_in_new_folder;
            encrypt_with_retry ~plaintext:updated_secret ~secret_name secret_recipients
          | None ->
          try
            show_recipients_notice_if_true is_first_secret_in_new_folder;
            Storage.Secrets.encrypt_exn ?use_sudo ~verbose ~plaintext:updated_secret ~secret_name secret_recipients
          with exn -> die ~exn "E: encrypting %s failed" secret_name_str)
    with Failure s -> die "%s" s
end

module Create = struct
  let base_check ?use_sudo secret_name =
    match Storage.Secrets.secret_exists secret_name with
    | true -> die "E: refusing to create: a secret by that name already exists"
    | false ->
      let path = Storage.Secrets.(to_path secret_name) in
      Invariant.die_if_invariant_fails ?use_sudo ~op_string:"create" path

  let add ?use_sudo ~comments secret_name secret_text =
    base_check ?use_sudo secret_name;
    Edit.edit_secret ?use_sudo secret_name ~self_fallback:true ~get_updated_secret:(fun _ ->
      let parsed_secret = Secret.Validation.parse_exn secret_text in
      let comments =
        match comments, parsed_secret.comments with
        | Some comment, None | None, Some comment -> Some comment
        | None, None -> None
        | Some _, Some _ ->
          die
            "E: secret text already contains comments. Either use the secret text with comments or use the --comment \
             flag."
      in
      match Validation.validate_comments (Option.value ~default:"" comments) with
      | Error e -> die "E: invalid comment format: %s" e
      | Ok comments -> Ok (Util.Secret.reconstruct_secret ~comments parsed_secret))

  let bare ?use_sudo ~f secret_name =
    base_check ?use_sudo secret_name;
    f secret_name
end

module Replace = struct
  let replace_secret secret_name new_secret_plaintext =
    let recipients = Util.Recipients.get_recipients_or_die secret_name in
    Invariant.run_if_recipient ~op_string:"replace secret"
      ~path:Storage.Secrets.(to_path secret_name)
      ~f:(fun () ->
        if new_secret_plaintext = "" then die "E: invalid input, empty secrets are not allowed.";
        let is_singleline_secret =
          (* New secret is single line if doesn't have a newline character or if it has only one,
              at the end of the first line. This input isn't supposed to follow the storage format,
             it only contains a secret and no comments *)
          match String.split_on_char '\n' new_secret_plaintext with
          | [ _ ] | [ _; "" ] -> true
          | _ -> false
        in
        let updated_secret =
          match Storage.Secrets.secret_exists secret_name with
          | false ->
            (* if the secret doesn't exist yet, create a new secret with the right format *)
            (match is_singleline_secret with
            | true -> new_secret_plaintext
            | false -> "\n\n" ^ new_secret_plaintext)
          | true ->
            (* if there is already a secret, recreate or replace it *)
            let original_secret =
              try
                let secret_plaintext = Storage.Secrets.decrypt_exn ~silence_stderr:true secret_name in
                Secret.Validation.parse_exn secret_plaintext
              with _e ->
                die
                  "E: unable to parse secret %s's format. If we proceed, the comments will be lost. Aborting. Please \
                   use the edit command to replace and fix this secret."
                  (show_name secret_name)
            in
            Util.Secret.reconstruct_with_new_text ~is_singleline:is_singleline_secret ~new_text:new_secret_plaintext
              ~existing_comments:original_secret.comments
        in
        try Storage.Secrets.encrypt_exn ~verbose:false ~plaintext:updated_secret ~secret_name recipients
        with exn -> die ~exn "E: encrypting %s failed" (show_name secret_name))

  let replace_comment ?use_sudo secret_name get_new_comments =
    let secret_name_str = show_name secret_name in
    let recipients = Util.Recipients.get_recipients_or_die secret_name in
    Invariant.run_if_recipient ~op_string:"replace comments"
      ~path:Storage.Secrets.(to_path secret_name)
      ~f:(fun () ->
        match Storage.Secrets.secret_exists secret_name with
        | false -> die "E: no such secret: %s" secret_name_str
        | true ->
          let original_secret =
            try Util.Secret.decrypt_and_parse ?use_sudo ~silence_stderr:true secret_name
            with _e ->
              die
                "E: unable to parse secret %s's format. Please fix it before replacing the comments,or use the edit \
                 command"
                secret_name_str
          in
          let new_comments = get_new_comments original_secret.comments in
          let updated_secret = Util.Secret.reconstruct_secret ~comments:new_comments original_secret in
          (try Storage.Secrets.encrypt_exn ?use_sudo ~verbose:false ~plaintext:updated_secret ~secret_name recipients
           with exn -> die ~exn "E: encrypting %s failed" secret_name_str))
end
