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
  | Singleline -> "single-line"
  | Multiline -> "multi-line"

let singleline_from_text_description text description =
  let text = String.trim text in
  match description with
  | "" -> text
  | _ -> Printf.sprintf "%s\n\n%s" text description

let multiline_from_text_description text description =
  let text = String.trim text in
  let description = String.trim description in
  match description with
  | "" -> Printf.sprintf "\n\n%s" text
  | _ -> Printf.sprintf "\n%s\n\n%s" description text

let format_explainer =
  {|

# Secrets and comments formats:
#
# Single-line secret with comments format:
#     secret one line
#     <empty line>
#     comments until end of file
#
# Single-line secret without comments format:
#     secret one line
#
# Multi-line secret with comments format:
#     <empty line>
#     possibly several lines of comments
#     without empty lines
#     <empty line>
#     secret until end of file
#
# Multi-line secret without comments format:
#     <empty line>
#     <empty line>
#     secret until end of file
#
# (single-line secrets are never newline-terminated)
# (multi-line secrets/comments are trimmed so '\na\nb\n' becomes 'a\nb')
# (an <empty line> is exactly '\n')
|}

module Validation = struct
  type validation_error =
    | SingleLineLegacy
    | MultilineEmptySecret
    | EmptySecret
    | InvalidFormat

  let split p l =
    let rec aux acc p =
      function
        | [] -> (List.rev acc, [])
        | x :: xs ->
          if p x
          then aux (x :: acc) p xs
          else (List.rev acc, xs)
    in
    aux [] p l

  let validate_aux ?(allow_legacy = false) plaintext : (t, string * validation_error) result =
    let parse_comments comment_lines =
      match comment_lines with [] -> None | _ -> Some (Base.unlines comment_lines |> String.trim)
    in
    let parse_text secret_lines = Base.unlines secret_lines |> String.trim in
    if String.trim plaintext = "" then Error ("empty secrets are not allowed", EmptySecret)
    else match Base.lines plaintext with
      (* multi-line with comments *)
      | "" :: comment :: rest when comment <> "" ->
        (* find the empty line that introduces the secret and make sure that it has content *)
        let comment_lines, secret_lines = split ((<>) "") (comment :: rest) in
        let text = parse_text secret_lines in
        if text = "" then Error ("multiline: empty secret", MultilineEmptySecret)
        else Ok {kind = Multiline; text; comments = parse_comments comment_lines}
      (* multi-line without comments *)
      | "" :: "" :: secret :: rest ->
        let text = parse_text (secret :: rest) in
        if text <> "" then (Ok { kind = Multiline; text; comments = None})
        else (Error ("multiline: empty secret", MultilineEmptySecret))
      (* single-line with comments *)
      | secret :: "" :: comments when String.trim secret <> "" ->
        (Ok { kind = Singleline; text = secret; comments = parse_comments comments})
      (* We don't want to allow the creation of new secrets in legacy single-line format *)
      | secret :: (_ :: _ as comments) when String.trim secret <> "" ->
        if allow_legacy then
          Ok { kind = Singleline; text = secret; comments = parse_comments comments}
        else
        Error
          ( "single-line secrets with comments should have an empty line between the secret and the comments.",
            SingleLineLegacy )
      (* single-line without comments *)
      | [ secret ] when String.trim secret <> "" -> (Ok { kind = Singleline; text = secret; comments = None})
      | _ -> Error ("invalid format", InvalidFormat)

  let validate = validate_aux ~allow_legacy:false

  let parse_exn plaintext_content =
    match validate_aux ~allow_legacy:true plaintext_content with
    | Ok secret -> secret
    | Error (e, _typ) -> failwith e
end
