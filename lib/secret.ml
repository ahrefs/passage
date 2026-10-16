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
# (multi-line comments _should not_ have empty lines in them)
#
# Single line secret with commments format:
#     secret one line
#     <empty line>
#     comments until end of file
#
# Single line secret without commments format:
#     secret one line
#
# Multiline secret with comments format:
#     <empty line>
#     possibly several lines of comments
#     <empty line>
#     secret until end of file
#
# Multiline secret without comments format:
#     <empty line>
#     <empty line>
#     secret until end of file
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
    if String.trim plaintext = "" then Error ("empty secrets are not allowed", EmptySecret)
    else (
      (* We can only use String.trim on the individual lines as we'd be stripping
         out leading empty lines, thus missing multi-line secrets due to the format spec.

         We need to use String.trim below on each line read to make sure that we don't have
         spaces or other whitespace characters in lines that might lead to false negatives *)
      match Base.lines plaintext with
      (* multi-line with comments *)
      | "" :: comment :: rest when String.trim comment <> "" ->
        (* find the empty line that introduces the secret and make sure that it has content *)
        let comment_lines, secret_lines =
          split ((<>) "") (comment :: rest)
        in
        let text = Base.unlines secret_lines |> String.trim in
        let comments = Some (Base.unlines comment_lines) in
        if text = "" then Error ("multiline: empty secret", MultilineEmptySecret)
        else (Ok {kind = Multiline; text; comments})
      (* multi-line without comments *)
      | "" :: "" :: secret :: rest when String.trim secret <> "" ->
        (Ok { kind = Multiline; text = Base.unlines (secret :: rest); comments = None})
      (* single-line with comments *)
      | secret :: "" :: comments when String.trim secret <> "" ->
        let has_empty_lines_in_cmts =
          match comments with
          | [] -> false
          | cmts ->
            String.concat "\n" cmts |> String.trim |> String.split_on_char '\n' |> List.map String.trim |> List.mem ""
        in
        (match has_empty_lines_in_cmts with
        | true -> Error ("empty lines are not allowed in comments", InvalidFormat)
        | false -> (Ok { kind = Singleline; text = secret; comments = Some (Base.unlines comments)}))
      (* We don't want to allow the creation of new secrets in legacy single-line format *)
      | secret :: (comment :: _ as comments) when String.trim secret <> "" && String.trim comment <> "" ->
        if allow_legacy then
          Ok { kind = Singleline; text = secret; comments = Some (Base.unlines comments)}
        else
        Error
          ( "single-line secrets with comments should have an empty line between the secret and the comments.",
            SingleLineLegacy )
      (* single-line without comments *)
      | [ secret ] when String.trim secret <> "" -> (Ok { kind = Singleline; text = secret; comments = None})
      | _ -> Error ("invalid format", InvalidFormat))

  let validate = validate_aux ~allow_legacy:false

  let _parse_exn_old plaintext_content =
    if String.trim plaintext_content = "" then failwith "empty secrets are not allowed";
    let lines = String.split_on_char '\n' plaintext_content in
    let to_comments_format comments =
      match comments with
      | [] -> None
      | _ -> Some (comments |> String.concat "\n" |> String.trim)
    in
    match lines with
    | "" :: tl ->
      (* multi-line secret *)
      let (comments_lines, text) = split ((<>) "") tl in
      let text = text |> String.concat "\n" |> String.trim in
      if text = "" then failwith "broken format multi-line secret (empty secret text). Please fix secret."
      else { kind = Multiline; text; comments = to_comments_format (comments_lines) }
      (* We keep the second pattern to match legacy secrets,
         which didn't have an empty line to separate from comments *)
    | (text :: "" :: comments_lines | text :: comments_lines) when String.trim text <> "" ->
      (* single line secret *)
      { kind = Singleline; text; comments = to_comments_format comments_lines }
    | _ -> failwith "empty secrets are not allowed"

  let parse_exn plaintext_content =
    match validate_aux ~allow_legacy:true plaintext_content with
    | Ok secret -> secret
    | Error (e, _typ) -> failwith e
end
