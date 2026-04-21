type t = Template_ast.ast_node list

let parse s =
  let lexbuf = Template_lexer.Encoding.from_string s in
  let lexer = Sedlexing.with_tokenizer Template_lexer.token lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Template_parser.template in
  parser lexer

let parse_file file =
  In_channel.with_open_bin (Path.project file) @@ fun ic ->
  let s = In_channel.input_all ic in
  parse s

let substitute_all ~substitute t =
  let results =
    List.map
      (fun node ->
        match node with
        | Template_ast.Text s -> Ok s
        | Template_ast.Iden name ->
        match substitute name with
        | Ok text -> Ok text
        | Error msg -> Error (name, msg))
      t
  in
  let texts, failures =
    List.partition_map
      (function
        | Ok text -> Left text
        | Error e -> Right e)
      results
  in
  match failures with
  | [] -> Ok (String.concat "" texts)
  | failures -> Error failures

let secrets t =
  List.filter_map
    (fun node ->
      match node with
      | Template_ast.Text _ -> None
      | Template_ast.Iden name -> Some name)
    t

let dump t = List.map Template_ast.to_string t |> String.concat ""
