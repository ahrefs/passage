let parse s =
  let lexbuf = Template_lexer.Encoding.from_string s in
  let lexer = Sedlexing.with_tokenizer Template_lexer.token lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Template_parser.template in
  parser lexer

let parse_file file =
  In_channel.with_open_bin (Path.project file) @@ fun ic ->
  let s = In_channel.input_all ic in
  parse s

let substitute_iden ?use_sudo node =
  match node with
  | Template_ast.Text _ -> node
  | Template_ast.Iden name ->
    let secret_name = Storage.Secret_name.inject name in
    (try
       let plaintext = Util.Secret.decrypt_silently ?use_sudo secret_name in
       let secret = Secret.Validation.parse_exn plaintext in
       Template_ast.Text secret.text
     with
    | Failure s -> Exn.die "unable to decrypt secret: %s" s
    | exn ->
      let () = Util.eprintfn "E: could not decrypt secret %s" (Storage.Secret_name.project secret_name) in
      raise exn)

let build_text_from_ast ast =
  List.map
    (fun node ->
      match node with
      | Template_ast.Text s -> s
      | Template_ast.Iden secret_name -> failwith (Printf.sprintf "found unsubstituted secret %s" secret_name))
    ast
  |> String.concat ""
