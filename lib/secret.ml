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

  let validate plaintext =
    if String.trim plaintext = "" then Error ("empty secrets are not allowed", EmptySecret)
    else (
      (* We can only use String.trim on the individual lines as we'd be stripping
         out leading empty lines, thus missing multi-line secrets due to the format spec.

         We need to use String.trim below on each line read to make sure that we don't have
         spaces or other whitespace characters in lines that might lead to false negatives *)
      let lines = String.split_on_char '\n' plaintext in
      match lines with
      (* multi-line with comments *)
      | "" :: comment :: rest when String.trim comment <> "" ->
        (* find the empty line that introduces the secret and make sure that it has content *)
        let secret, _is_secret =
          List.fold_left
            (fun (secret, is_secret) line ->
              match is_secret, String.trim line with
              | true, s when s <> "" -> line :: secret, true
              | true, _ -> secret, true
              | false, "" -> secret, true
              | false, _ -> secret, false)
            ([], false) rest
        in
        if Stdlib.List.is_empty secret then Error ("multiline: empty secret", MultilineEmptySecret) else Ok Multiline
      (* multi-line without comments *)
      | "" :: "" :: secret :: _ when String.trim secret <> "" -> Ok Multiline
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
        | false -> Ok Singleline)
      (* We don't want to allow the creation of new secrets in legacy single-line format *)
      | secret :: comment :: _ when String.trim secret <> "" && String.trim comment <> "" ->
        Error
          ( "single-line secrets with comments should have an empty line between the secret and the comments.",
            SingleLineLegacy )
      (* single-line without comments *)
      | [ secret ] when String.trim secret <> "" -> Ok Singleline
      | _ -> Error ("invalid format", InvalidFormat))

  (**
 Multiline secret with comments format:
     <empty line>
     possibly several lines of comments without empty lines
     <empty line>
     secret until end of file

 Multiline secret without comments format:
     <empty line>
     <empty line>
     secret until end of file

 Single line secret with commments format:
     secret one line
     <empty line>
     comments until end of file

 Single line secret without commments format:
     secret one line

 Single line secret with commments legacy format [DEPRECATED]:
     secret one line
     comments until the end of file
 *)
  let parse_exn plaintext_content =
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
      let text, comments_lines, (_ : bool) =
        List.fold_left
          (fun (secret_text, comments, is_secret) line ->
            match is_secret, line with
            | true, _ -> line :: secret_text, comments, true
            | false, "" -> secret_text, comments, true
            | false, s -> secret_text, s :: comments, false)
          ([], [], false) tl
      in
      let text = List.rev text |> String.concat "\n" |> String.trim in
      if text = "" then failwith "broken format multi-line secret (empty secret text). Please fix secret."
      else { kind = Multiline; text; comments = to_comments_format (List.rev comments_lines) }
      (* We keep the second pattern to match legacy secrets,
         which didn't have an empty line to separate from comments *)
    | text :: "" :: comments_lines | text :: comments_lines ->
      (* single line secret *)
      { kind = Singleline; text; comments = to_comments_format comments_lines }
    | [] -> failwith "empty secrets are not allowed"

  let validity_to_string name secret_text =
    match validate secret_text with
    | Ok kind -> Printf.sprintf "✅ %s [ valid %s ]" name (kind_to_string kind)
    | Error (e, _typ) -> Printf.sprintf "❌ %s Invalid format: %s" name e
end
