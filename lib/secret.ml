type kind =
  | Singleline
  | Multiline

type t = {
  kind : kind;
  text : string;
  comments : string option;
}

let kind_to_string k =
  match k with
  | Singleline -> "singleline"
  | Multiline -> "multiline"

(*
 Multiline secret format:
     <empty line>
     possibly several lines of comments without empty lines
     <empty line>
     secret until end of file

 Single line secret format:
     secret one line
     comments until end of file
 *)
let parse plaintext_content =
  let lines = String.split_on_char '\n' plaintext_content in
  match lines with
  | "" :: tl ->
    (* multiline secret *)
    let text, comments, (_ : bool) =
      List.fold_left
        (fun (secret_text, comments, is_secret) line ->
          match is_secret with
          | true -> line :: secret_text, comments, true
          | false ->
          match line with
          | "" -> secret_text, comments, true
          | s -> secret_text, s :: comments, false)
        ([], [], false) tl
    in
    let text = List.rev text |> String.concat "\n" in
    let comments =
      match comments with
      | [] -> None
      | _ -> Some (List.rev comments |> String.concat "\n")
    in
    { kind = Multiline; text = String.trim text; comments }
  | text :: comments ->
    (* single line secret *)
    let comments =
      match comments with
      | [] -> None
      | _ -> Some (String.concat "\n" comments)
    in
    { kind = Singleline; text; comments }
  | [] ->
    (* arbitrarily assign empty secret as Singleline *)
    { kind = Singleline; text = ""; comments = None }
