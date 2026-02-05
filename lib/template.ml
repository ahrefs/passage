let parse s =
  let lexbuf = Template_lexer.Encoding.from_string s in
  let lexer = Sedlexing.with_tokenizer Template_lexer.token lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Template_parser.template in
  parser lexer

let parse_file file =
  In_channel.with_open_bin (Path.project file) @@ fun ic ->
  let s = In_channel.input_all ic in
  parse s

let try_substitute_iden ?use_sudo node =
  match node with
  | Template_ast.Text _ -> Ok node
  | Template_ast.Iden name ->
    let secret_name = Storage.Secret_name.inject name in
    (try
       let plaintext = Util.Secret.decrypt_silently ?use_sudo secret_name in
       let secret = Secret.Validation.parse_exn plaintext in
       Ok (Template_ast.Text secret.text)
     with
    | Failure s -> Error (name, Printf.sprintf "unable to decrypt secret: %s" s)
    | exn -> Error (name, Printf.sprintf "could not decrypt secret: %s" (Printexc.to_string exn)))

let substitute_all ?use_sudo ast =
  let results = List.map (try_substitute_iden ?use_sudo) ast in
  let successes, failures =
    List.partition_map
      (function
        | Ok node -> Left node
        | Error (name, msg) -> Right (name, msg))
      results
  in
  match failures with
  | [] -> Ok successes
  | failures -> Error failures

let build_text_from_ast ast =
  List.map
    (fun node ->
      match node with
      | Template_ast.Text s -> s
      | Template_ast.Iden secret_name -> Exn.die "found unsubstituted secret %s" secret_name)
    ast
  |> String.concat ""
