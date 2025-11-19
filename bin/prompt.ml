(** User prompt and input utilities *)
open Passage

open Util.Show

type prompt_reply =
  | NoTTY
  | TTY of bool

let is_TTY = Unix.isatty Unix.stdin

let yesno prompt =
  let () = Printf.printf "%s [y/N] " prompt in
  let () = flush stdout in
  let ans = read_line () in
  match ans with
  | "Y" | "y" -> true
  | _ -> false

let yesno_tty_check prompt =
  match is_TTY with
  | false -> NoTTY
  | true ->
    let () = Printf.printf "%s [y/N] %!" prompt in
    (match read_line () with
    | "Y" | "y" -> TTY true
    | _ -> TTY false)

let input_help_if_user_input ?(msg = "Please type the secret and then do Ctrl+d twice to terminate input") () =
  match is_TTY with
  | true -> Printf.printf "I: reading from stdin. %s\n%!" msg
  | false -> ()

(* Content preprocessing - removes bash-style comments and trailing newlines *)
let preprocess_content input =
  let remove_trailing_newlines s =
    (* copied from CCString.rdrop_while *)
    let open String in
    let i = ref (length s - 1) in
    while !i >= 0 && (( = ) '\n') (unsafe_get s !i) do
      decr i
    done;
    if !i < length s - 1 then sub s 0 (!i + 1) else s
  in
  (* Remove bash commented lines from the secret and any trailing newlines, but keep leading newlines *)
  String.split_on_char '\n' input
  |> List.filter (fun line -> not (String.starts_with ~prefix:"#" line))
  |> String.concat "\n"
  |> remove_trailing_newlines

(** Gets and validates user input reading from stdin. If the input has the wrong format, the user
    is prompted to reinput the secret with the correct format. Allows passing in a function for input
    transformation. Throws an error if the transformed input doesn't comply with the format and the
    user doesn't want to fix the input format. *)
let get_valid_input_from_stdin_exn () =
  let rec input_and_validate_loop ~validate ?initial get_input =
    match validate @@ preprocess_content @@ get_input ?initial () with
    | Ok s -> Ok s
    | Error e ->
      if is_TTY = false then Shell.die "%s" e
      else (
        let () = Printf.printf "\nThis secret is in an invalid format: %s\n" e in
        if yesno "Edit again?" then input_and_validate_loop ~validate ~initial:input get_input else Error e)
  in
  input_and_validate_loop ~validate:Validation.validate_secret (fun ?initial:_ () -> In_channel.input_all stdin)

module Editor = struct
  let shm_check =
    lazy
      (let shm_dir = Path.inject "/dev/shm" in
       let has_sufficient_perms =
         try
           Path.access shm_dir [ F_OK; W_OK ];
           true
         with Unix.Unix_error _ -> false
       in
       match Path.is_directory shm_dir && has_sufficient_perms with
       | true -> Some shm_dir
       | false ->
       match
         yesno
           {|Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?|}
       with
       | false -> exit 1
       | true -> None)

  let with_secure_tmpfile f =
    let temp_dir =
      match Lazy.force shm_check with
      | Some p -> show_path p
      | None -> Filename.get_temp_dir_name ()
    in
    Devkit.Control.with_open_out_temp_file ~temp_dir ~mode:[ Open_wronly; Open_creat; Open_excl ] f

  let rec edit_loop tmpfile =
    try
      let editor = Option.value (Sys.getenv_opt "EDITOR") ~default:"editor" in
      let raw_cmd = Printf.sprintf "%s %s" (Filename.quote editor) (Filename.quote tmpfile) in
      let stdout s = Bos.OS.Cmd.out_stdout s in
      Shell.run_cmd ~stdout raw_cmd;
      true
    with
    | _ when yesno "Editor was exited without saving successfully, try again?" -> edit_loop tmpfile
    | _ -> false

  (* Unified editor abstraction with validation and retry *)
  let edit_with_validation ?(initial = "") ~validate () =
    with_secure_tmpfile (fun (tmpfile, tmpfile_oc) ->
        (* Write initial content and close to make available to editor *)
        if initial <> "" then output_string tmpfile_oc initial;
        close_out tmpfile_oc;

        match edit_loop tmpfile with
        | false -> Error "Editor cancelled"
        | true ->
          let rec validate_and_edit () =
            match validate @@ preprocess_content @@ Std.input_file tmpfile with
            | Ok r -> r
            | Error e ->
            match is_TTY with
            | false -> Shell.die "%s" e
            | true ->
              let () = Printf.printf "\n%s\n" e in
              (match yesno "Edit again?" with
              | false -> Shell.die "%s" e
              | true ->
                let _ = edit_loop tmpfile in
                validate_and_edit ())
          in
          Ok (validate_and_edit ()))
end

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
  match Editor.edit_with_validation ~initial:initial_content ~validate:validate_recipients () with
  | Ok new_recipients_list -> Commands.Recipients.rewrite_recipients_file secret_name new_recipients_list
  | Error _ -> prerr_endline "E: no recipients provided"
