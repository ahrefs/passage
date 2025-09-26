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
    let () = Printf.printf "%s [y/N] " prompt in
    let () = flush stdout in
    let ans = read_line () in
    (match ans with
    | "Y" | "y" -> TTY true
    | _ -> TTY false)

let input_help_if_user_input ?(msg = "Please type the secret and then do Ctrl+d twice to terminate input") () =
  match is_TTY with
  | true ->
    Printf.printf "I: reading from stdin. %s\n" msg;
    flush stdout
  | false -> ()

let read_input_from_stdin ?initial:_ () =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    try
      let n = input stdin chunk 0 4096 in
      if n = 0 then Buffer.contents buf
      else (
        Buffer.add_subbytes buf chunk 0 n;
        loop ())
    with End_of_file -> Buffer.contents buf
  in
  loop ()

(* Content preprocessing - removes bash comments and trailing newlines *)
let preprocess_content input =
  let remove_trailing_newlines s =
    (* reverse the string and count leading newlines instead of traversing the string
       multiple times to remove trailing newlines. Exit early if we find a non-newline character. *)
    let rev_s =
      let chars = List.of_seq (String.to_seq s) in
      String.of_seq (List.to_seq (List.rev chars))
    in
    let rec count_leading_newlines ?(acc = 0) ?(i = 0) s =
      try
        match s.[i] = '\n' with
        | true -> count_leading_newlines ~acc:(acc + 1) ~i:(i + 1) s
        | false -> i
      with _ -> i
    in
    let trailing_newlines = count_leading_newlines rev_s in
    let new_length = String.length s - trailing_newlines in
    if new_length <= 0 then "" else String.sub s 0 new_length
  in
  (* Remove bash commented lines from the secret and any trailing newlines, but keep leading newlines *)
  String.split_on_char '\n' input
  |> List.filter (fun line -> not (String.starts_with ~prefix:"#" line))
  |> String.concat "\n"
  |> remove_trailing_newlines

let rec input_and_validate_loop ~validate ?initial get_input =
  let input = get_input ?initial () in
  let secret = preprocess_content input in
  match validate secret with
  | Error e ->
    if is_TTY = false then Shell.die "This secret is in an invalid format: %s" e
    else (
      let () = Printf.printf "\nThis secret is in an invalid format: %s\n" e in
      if yesno "Edit again?" then input_and_validate_loop ~validate ~initial:input get_input else Error e)
  | _ -> Ok secret

(** Gets and validates user input reading from stdin. If the input has the wrong format, the user
    is prompted to reinput the secret with the correct format. Allows passing in a function for input
    transformation. Throws an error if the transformed input doesn't comply with the format and the
    user doesn't want to fix the input format. *)
let get_valid_input_from_stdin_exn ?(validate = Validation.validate_secret) () =
  match input_and_validate_loop ~validate read_input_from_stdin with
  | Error e -> Shell.die "This secret is in an invalid format: %s" e
  | Ok secret -> Ok secret
