open Passage.Make (Passage.Default_config)
open Validation
open Prompt

let get_comments_from_stdin ?help_message () =
  let () = Option.iter (fun msg -> input_help_if_user_input ~msg ()) help_message in
  match validate_comments @@ In_channel.input_all stdin with
  | Ok c -> c
  | Error e -> Shell.die "E: %s" e

let get_comments_from_editor ?(initial = "") () =
  match Editor.edit_with_validation ~initial ~validate:validate_comments () with
  | Ok c -> c
  | Error e -> Shell.die "E: %s" e

let get_comments ?initial ?help_message () =
  match is_TTY with
  | false -> get_comments_from_stdin ?help_message ()
  | true -> get_comments_from_editor ?initial ()
