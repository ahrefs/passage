(** Unified validation functions for secrets, comments, and recipients *)

open Printf

(** Validate secret format using Secret.Validation module *)
let validate_secret secret =
  match Secret.Validation.validate secret with
  | Error (e, _typ) -> Error ("E: this secret is in an invalid format: " ^ e)
  | _ -> Ok secret

(** Validate comment format - no empty lines allowed in the middle *)
let validate_comments comments =
  match String.trim comments with
  | "" ->
    (* empty comments are allowed *)
    Ok ""
  | comments ->
    let has_empty_lines = String.split_on_char '\n' comments |> List.mem "" in
    (match has_empty_lines with
    | false -> Ok comments
    | true -> Error "empty lines are not allowed in the middle of the comments")

(** Validate recipients list against known recipients and groups *)
let validate_recipients ?(groups_only = false) recipients_list =
  let all_recipient_names = Storage.Keys.all_recipient_names () in
  let all_group_names = Storage.Secrets.all_groups_names () |> List.map (fun g -> "@" ^ g) in
  let valid_names = all_recipient_names @ all_group_names @ [ "@everyone" ] in
  let invalid_recipients =
    List.filter
      (fun name ->
        let is_invalid = not (List.mem name valid_names) in
        if groups_only then String.starts_with ~prefix:"@" name && is_invalid else is_invalid)
      recipients_list
  in
  match invalid_recipients with
  | [] -> Ok ()
  | invalid_recipients' ->
    let error_msg =
      match invalid_recipients' with
      | [ r ] -> sprintf "Invalid recipient: %s does not exist" r
      | _ -> sprintf "Invalid recipients: %s do not exist" (String.concat ", " invalid_recipients')
    in
    Error error_msg

(** Validate recipients for editing (groups only) *)
let validate_recipients_for_editing = validate_recipients ~groups_only:true

(** Validate recipients for commands (all recipients) *)
let validate_recipients_for_commands = validate_recipients ~groups_only:false
