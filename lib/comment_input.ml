open Validation
open File_utils
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
  let new_comments = input_and_validate_loop ~validate:validate_comments ?initial (new_text_from_editor ~name) in
  match new_comments with
  | Error e -> Shell.die "%s %s" error_prefix e
  | Ok comments -> String.trim comments

let get_comments ?initial ~name ?(help_message = None) ?(error_prefix = "E:") () =
  match is_TTY with
  | false -> get_comments_from_stdin ~help_message ~error_prefix ()
  | true -> get_comments_from_editor ?initial ~name ~error_prefix ()
