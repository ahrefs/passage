type t = Template of string

let parse s =
  if String.is_valid_utf_8 s then Template s else invalid_arg "[Template.parse] templates must be valid UTF-8."

let parse_file path =
  let file = Path.project path in
  In_channel.with_open_bin file @@ fun ic ->
  let s = In_channel.input_all ic in
  if String.is_valid_utf_8 s then Template s
  else Printf.ksprintf invalid_arg "[Template.parse_file] templates must be valid UTF-8, %s is not." file

let substitute_aux (Template template : t) yield =
  let len = String.length template in
  let rec loop i =
    if i >= len then ()
    else (
      match template.[i] with
      | '{' when i + 2 < len && template.[i + 1] = '{' && template.[i + 2] = '{' ->
        let iden = Buffer.create 5 in
        let iden_start = i + 3 in
        let rec read_iden j =
          if iden_start + j >= len then
            (* Unterminated identifier: treat as literal text *)
            yield (`Text (String.sub template i (3 + j)))
          else (
            match template.[iden_start + j] with
            | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' | '/' | '.') as c ->
              Buffer.add_char iden c;
              read_iden (succ j)
            | '}'
              when j > 0 (* Literal {{{}}} are not replaced. *)
                   && iden_start + j + 2 < len
                   && template.[iden_start + j + 1] = '}'
                   && template.[iden_start + j + 2] = '}' ->
              let iden = Buffer.contents iden in
              yield (`Iden iden);
              loop (iden_start + j + 3)
            | _ ->
              yield (`Text (String.sub template i (3 + j)));
              loop (iden_start + j))
        in
        read_iden 0
      | c ->
        yield (`Char c);
        loop (succ i))
  in
  loop 0

let substitute_all ~substitute (Template t as template) =
  let errors = ref [] in
  let buf = Buffer.create (String.length t) in
  let yield what =
    match what with
    | `Text text -> Buffer.add_string buf text
    | `Char char -> Buffer.add_char buf char
    | `Iden iden ->
    match substitute iden with
    | Ok s -> Buffer.add_string buf s
    | Error e ->
      errors := (iden, e) :: !errors;
      Buffer.add_string buf ("{{{" ^ iden ^ "}}}")
  in
  substitute_aux template yield;
  match !errors with
  | [] -> Ok (Buffer.contents buf)
  | errors -> Error (List.rev errors)

let secrets template =
  let secrets = ref [] in
  let yield = function
    | `Iden secret -> secrets := secret :: !secrets
    | _ -> ()
  in
  substitute_aux template yield;
  List.rev !secrets

let dump template =
  let substitute secret = Ok ("[[[" ^ String.uppercase_ascii secret ^ "]]]") in
  substitute_all ~substitute template |> Result.get_ok
