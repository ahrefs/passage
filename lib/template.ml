let parse s =
  let lexbuf = Template_lexer.Encoding.from_string s in
  let lexer = Sedlexing.with_tokenizer Template_lexer.token lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Template_parser.template in
  parser lexer

let parse_file file =
  In_channel.with_open_bin (Path.project file) @@ fun ic ->
  let s = In_channel.input_all ic in
  parse s

let substitute_iden node =
  match node with
  | Template_ast.Text _ -> node
  | Template_ast.Iden name ->
    let secret_name = Storage.Secret_name.inject name in
    (try
       let plaintext = Secret_helpers.decrypt_silently secret_name in
       let secret = Secret.Validation.parse_exn plaintext in
       Template_ast.Text secret.text
     with
    | Failure s -> failwith ("unable to decrypt secret: " ^ s)
    | exn ->
      let () = Printf.eprintf "E: could not decrypt secret %s\n" (Storage.Secret_name.project secret_name) in
      raise exn)

let build_text_from_ast ast =
  List.map
    (fun node ->
      match node with
      | Template_ast.Text s -> s
      | Template_ast.Iden secret_name -> Devkit.Exn.fail "found unsubstituted secret %s" secret_name)
    ast
  |> String.concat ""

let substitute ~template ?(file_out = None) () =
  let substituted_ast = List.map substitute_iden template in
  let contents = build_text_from_ast substituted_ast in
  match file_out with
  | None ->
    print_string contents
  | Some target_file ->
    Devkit.Files.save_as (Path.project target_file) ~mode:0o600 (fun oc -> Out_channel.output_string oc contents)

let substitute_file ~template_file ~target_file =
  let template = parse_file template_file in
  substitute ~template ~file_out:target_file ()
