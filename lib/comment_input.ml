open Validation
open Prompt

let get_comments_from_stdin ?(help_message = None) ?(error_prefix = "E:") () =
  let () =
    match help_message with
    | None -> ()
    | Some msg -> input_help_if_user_input ~msg ()
  in
  let new_comments = read_input_from_stdin () in
  let new_comments = String.trim new_comments in
  match validate_comments new_comments with
  | Error e -> Shell.die "%s %s" error_prefix e
  | Ok () -> new_comments

let get_comments_from_editor ?initial ~name ?(error_prefix = "E:") () =
  let validate_and_return_comments content =
    let content = String.trim content in
    match validate_comments content with
    | Ok () -> Ok content
    | Error e -> Error e
  in
  match
    File_utils.edit_with_validation ~initial:(Option.value ~default:"" initial) ~name
      ~validate:validate_and_return_comments ()
  with
  | Ok comments -> comments
  | Error e -> Shell.die "%s %s" error_prefix e

let get_comments ?initial ~name ?(help_message = None) ?(error_prefix = "E:") () =
  match is_TTY with
  | false -> get_comments_from_stdin ~help_message ~error_prefix ()
  | true -> get_comments_from_editor ?initial ~name ~error_prefix ()
