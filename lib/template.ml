open Devkit

let parse s =
  let lexbuf = Template_lexer.Encoding.from_string s in
  let lexer = Sedlexing.with_tokenizer Template_lexer.token lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Template_parser.template in
  parser lexer

let parse_file file =
  In_channel.with_open_bin (Path.project file) @@ fun ic ->
  let s = In_channel.input_all ic in
  parse s

let substitute_iden name_mappings node =
  match node with
  | Template_ast.Text _ -> Lwt.return node
  | Template_ast.Iden name ->
    let secret_name = Hashtbl.find_opt name_mappings name |> Option.value ~default:name |> Storage.SecretName.inject in
    let%lwt plaintext = Storage.Secrets.decrypt_exn secret_name in
    let Secret.{ text; kind = _; comments = _comments } = Secret.parse plaintext in
    Lwt.return @@ Template_ast.Text text

let build_text_from_ast ast =
  List.map
    (fun node ->
      match node with
      | Template_ast.Text s -> s
      | Template_ast.Iden secret_name -> Exn.fail "found unsubstituted secret %s" secret_name)
    ast
  |> String.concat ""

let substitute_file ~template_file ~target_file name_mappings =
  let%lwt substituted_ast = parse_file template_file |> Lwt_list.map_p (substitute_iden name_mappings) in
  let contents = build_text_from_ast substituted_ast in
  Files.save_as (Path.project target_file) ~mode:0o600 (fun oc -> Out_channel.output_string oc contents);
  Lwt.return_unit
