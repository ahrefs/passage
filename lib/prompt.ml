(** User prompt and input utilities *)

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
