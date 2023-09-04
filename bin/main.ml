open Devkit
open Passage
open Printf

type output_mode =
  | Clipboard
  | QrCode
  | Stdout

type verbosity =
  | Normal
  | Verbose

let verbosity = ref Normal

let verbose_printlf fmt =
  ksprintf
    (fun msg ->
      match !verbosity with
      | Verbose -> Lwt_io.printl msg
      | Normal -> Lwt.return_unit)
    fmt

let program = Filename.basename Sys.executable_name
let show_path p = Path.project p
let show_name name = Storage.SecretName.project name

let die ?exn fmt =
  kfprintf
    (fun out ->
      (match exn with
      | None -> fprintf out "\n"
      | Some exn -> fprintf out " : %s\n" (Exn.to_string exn));
      exit 1)
    stderr fmt

let yesno prompt =
  printf "%s [y/N] " prompt;
  let ans = read_line () in
  match ans with
  | "Y" | "y" -> true
  | _ -> false

let with_secure_tmpfile secret_name f =
  let shm_dir = Path.inject "/dev/shm" in
  let has_sufficient_perms =
    try
      Path.access shm_dir [ F_OK; W_OK; X_OK ];
      true
    with Unix.Unix_error _ -> false
  in
  let parent =
    match Path.is_directory shm_dir && has_sufficient_perms with
    | true -> Some shm_dir
    | false ->
    match
      yesno
        {|Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?|}
    with
    | false -> exit 1
    | true -> None
  in
  Storage.Secrets.with_secure_tmpfile ?parent ~prefix:program secret_name f

let get_recipients ?(warn = true) path =
  let recipients =
    try Storage.Secrets.get_recipients_from_path_exn path with exn -> die ~exn "E: failed to get recipients"
  in
  if warn then
    List.iter
      (fun r ->
        match Age.(r.keys) with
        | [] -> printfn "W: no keys found for %s" r.name
        | _ -> ())
      recipients;
  recipients

let encrypt_exn ~plaintext ~secret_name recipients =
  let%lwt () =
    verbose_printlf "I: encrypting %s for %s" (show_name secret_name)
      (List.map (fun r -> Age.(r.name)) recipients |> String.concat ", ")
  in
  Storage.Secrets.encrypt_exn ~plaintext ~secret_name recipients

let encrypt_with_retry ~plaintext ~secret_name recipients =
  let rec loop () =
    try%lwt encrypt_exn ~plaintext ~secret_name recipients
    with exn ->
      let%lwt () = Lwt_io.eprintlf "Encryption failed: %s" (Exn.to_string exn) in
      let%lwt () = Lwt_io.(flush stderr) in
      (match yesno "Would you like to try again?" with
      | false -> die "E: retry cancelled"
      | true -> loop ())
  in
  loop ()

let print_as_qrcode ~secret_name ~secret =
  match Qrc.encode secret with
  | None -> die "Failed to encode %s as QR code. Data capacity exceeded!" (show_name secret_name)
  | Some m -> Qrc_fmt.pp_utf_8_half ~invert:true Format.std_formatter m

let save_to_clipboard_exn ~program ~secret =
  let read_clipboard () = Shell.xclip_read_clipboard Config.x_selection in
  let copy_to_clipboard s =
    try%lwt Shell.xclip_copy_to_clipboard s ~x_selection:Config.x_selection
    with exn -> Exn.fail ~exn "E: Could not copy data to the clipboard"
  in
  let sleep_proc_name =
    let display_name = Option.value (Sys.getenv_opt "DISPLAY") ~default:"" in
    sprintf "%s sleep on display %s" program display_name
  in
  let restore_clipboard original_content =
    let%lwt () = Shell.sleep sleep_proc_name Config.clip_time in
    let%lwt current_content = read_clipboard () in
    (* It might be nice to programatically check to see if klipper exists,
       as well as checking for other common clipboard managers. But for now,
       this works fine -- if qdbus isn't there or if klipper isn't running,
       this essentially becomes a no-op.

       Clipboard managers frequently write their history out in plaintext,
       so we axe it here: *)
    let%lwt () =
      try%lwt Shell.clear_clipboard_managers ()
      with _ ->
        (* any exns raised are likely due to qdbus, klipper, etc., being absent.
           Thus, we swallow these exns so that it becomes a no-op *)
        Lwt.return_unit
    in
    match current_content = secret with
    | false ->
      (* clipboard was used and overwritten, so we don't attempt to perform any restoration *)
      Lwt.return_unit
    | true -> copy_to_clipboard original_content
  in
  (* kill all existing sleeping processes that were spawned from previous invocations *)
  let%lwt () = Shell.kill_processes sleep_proc_name in
  let%lwt original_content = read_clipboard () in
  let%lwt () = copy_to_clipboard secret in
  (* flush before forking to avoid double-flush *)
  let%lwt () = Lwt_io.flush_all () in
  match Nix.fork () with
  | `Child ->
    let (_ : int) = Unix.setsid () in
    restore_clipboard original_content
  | `Forked _ -> Lwt.return_unit

let save_to_clipboard ~secret_name ~secret =
  try%lwt
    let%lwt () = save_to_clipboard_exn ~program ~secret in
    Lwt_io.printlf "Copied %s to clipboard. Will clear in %d seconds." (show_name secret_name) Config.clip_time
  with exn -> die ~exn "E: failed to save to clipboard! Check if you have an X server running."

let edit_secret secret_name ~allow_retry ~get_updated_secret =
  let raw_secret_name = show_name secret_name in
  Lwt_main.run
  @@ let%lwt original_secret =
       match Storage.Secrets.secret_exist secret_name with
       | false -> Lwt.return ""
       | true ->
         (try%lwt Storage.Secrets.decrypt_exn secret_name
          with exn -> die ~exn "E: failed to decrypt %s" raw_secret_name)
     in
     try%lwt
       let%lwt updated_secret = get_updated_secret original_secret in
       match updated_secret = original_secret || updated_secret = "" with
       | true -> Exn.fail "I: secret unchanged"
       | false ->
         let recipients = Storage.Secrets.get_recipients_from_name_exn secret_name in
         (match allow_retry with
         | true -> encrypt_with_retry ~plaintext:updated_secret ~secret_name recipients
         | false ->
           (try%lwt encrypt_exn ~plaintext:updated_secret ~secret_name recipients
            with exn -> Exn.fail ~exn "E: encrypting %s failed" raw_secret_name))
     with Failure s -> die "%s" s

let append_to_secret secret_name =
  edit_secret secret_name ~allow_retry:false ~get_updated_secret:(fun original_secret ->
    let%lwt content_to_append = Lwt_io.(read stdin) in
    Lwt.return @@ original_secret ^ content_to_append)

let edit_secret_in_editor secret_name =
  edit_secret secret_name ~allow_retry:true ~get_updated_secret:(fun original_secret ->
    with_secure_tmpfile secret_name (fun (tmpfile, tmpfile_oc) ->
      let%lwt () = Lwt_io.write tmpfile_oc original_secret in
      (* close tmpfile_oc before opening in editor so that editor is the only one that has tmpfile open *)
      let%lwt () = Lwt_io.close tmpfile_oc in
      let%lwt () = Shell.editor tmpfile in
      Lwt_io.(with_file ~mode:Input tmpfile read)))

let replace_secret secret_name =
  Lwt_main.run
  @@ let%lwt plaintext = Lwt_io.(read stdin) in
     let recipients = Storage.Secrets.get_recipients_from_name_exn secret_name in
     try%lwt encrypt_exn ~plaintext ~secret_name recipients
     with exn -> die ~exn "E: encrypting %s failed" (show_name secret_name)

let get_secret ?expected_kind ?line_number ~with_comments secret_name output_mode =
  Lwt_main.run
  @@
  match Storage.Secrets.secret_exist secret_name with
  | false -> die "E: no such secret: %s" (show_name secret_name)
  | true ->
    let get_line_exn secret line_number =
      if line_number < 1 then die "Line number should be greater than 0";
      let lines = String.split_on_char '\n' secret in
      (* user specified line number is 1-indexed *)
      match List.nth_opt lines (line_number - 1) with
      | None -> die "There is no secret at line %d" line_number
      | Some l -> l
    in
    let%lwt plaintext =
      try%lwt Storage.Secrets.decrypt_exn secret_name
      with exn -> die ~exn "E: failed to decrypt %s" (show_name secret_name)
    in
    let secret = Secret.parse plaintext in
    let kind = secret.Secret.kind in
    (match expected_kind with
    | Some expected_kind when expected_kind <> kind ->
      die "E: %s is expected to be %s but it is %s" (show_name secret_name) (Secret.kind_to_string expected_kind)
        (Secret.kind_to_string kind)
    | _ -> ());
    let secret =
      match with_comments, line_number with
      | true, None -> plaintext
      | true, Some ln -> get_line_exn plaintext ln
      | false, None -> secret.text
      | false, Some ln -> get_line_exn secret.text ln
    in
    (match output_mode with
    | QrCode ->
      print_as_qrcode ~secret_name ~secret;
      Lwt.return_unit
    | Clipboard -> save_to_clipboard ~secret_name ~secret
    | Stdout ->
    match with_comments, kind with
    | false, Singleline ->
      (* When extracting the single line secret text, we discarded the newline
         separating the secret from the comments.
         Therefore, we need to print with a trailing new line here *)
      Lwt_io.printl secret
    | _ -> Lwt_io.print secret)

let list_recipients path =
  match get_recipients path with
  | [] -> die "E: no usable keys found for %s" (show_path path)
  | recipients -> List.iter (fun r -> print_endline r.Age.name) recipients

let list_secrets path =
  let raw_path = show_path path in
  Lwt_main.run
  @@
  match Storage.Secrets.secret_exist_at path with
  | true -> Lwt_io.printl Storage.(Secrets.name_of_file path |> show_name)
  | false ->
  match Path.is_directory path with
  | true ->
    Storage.(Secrets.get_secrets path |> List.sort SecretName.compare)
    |> Lwt_list.iter_s (fun s -> Lwt_io.printl @@ show_name s)
  | false -> die "No secrets at %s" raw_path

let list_secrets_tree path =
  let raw_path = show_path path in
  Lwt_main.run
  @@
  match Path.is_directory path, Storage.Secrets.secret_exist_at path with
  | false, true -> die "Did you mean : passage get %s" (Storage.Secrets.name_of_file path |> show_name)
  | false, false -> die "No secrets at this path : %s" raw_path
  | true, _ ->
    (* TODO: consider writing the below command in OCaml rather than using shell commands *)
    Shell.list_files_with_ext_and_strip_ext_tree ~path:raw_path ~ext:Storage.Secrets.ext

let list_recipient_secrets recipient_name =
  match Storage.Secrets.get_secrets_for_recipient recipient_name with
  | [] -> printfn "No secrets found for %s" recipient_name
  | secrets -> Storage.SecretName.(List.sort compare secrets |> project_list |> List.iter print_endline)

let refresh_secrets path =
  let secrets =
    match Storage.Secrets.get_secrets path with
    | _ :: _ as secrets -> secrets
    | [] ->
    match Storage.Secrets.secret_exist_at path with
    | true -> [ Storage.Secrets.name_of_file path ]
    | false -> die "E: No secrets at %s" (show_path path)
  in
  let secrets = List.sort Storage.SecretName.compare secrets in
  Lwt_main.run
  @@ let%lwt self_key = Age.Key.from_identity_file !!Config.identity_file in
     let%lwt n_skipped, n_refreshed, n_failed =
       Lwt_list.fold_left_s
         (fun (n_skipped, n_refreshed, n_failed) secret ->
           let raw_secret_name = show_name secret in
           let%lwt () = verbose_printlf "Attempting to refresh %s" raw_secret_name in
           match%lwt Storage.Secrets.refresh_exn secret self_key with
           | Succeeded () -> Lwt.return (n_skipped, n_refreshed + 1, n_failed)
           | Skipped ->
             let%lwt () = Lwt_io.printlf "I: skipping %s" raw_secret_name in
             Lwt.return (n_skipped + 1, n_refreshed, n_failed)
           | Failed exn ->
             let%lwt () = Lwt_io.printlf "W: failed to refresh %s : %s" raw_secret_name (Exn.to_string exn) in
             Lwt.return (n_skipped, n_refreshed, n_failed + 1))
         (0, 0, 0) secrets
     in
     Lwt_io.printlf "I: refreshed %d secrets, skipped %d, failed %d" n_refreshed n_skipped n_failed

let search_secrets pattern path =
  let secrets = Storage.Secrets.get_secrets path |> List.sort Storage.SecretName.compare in
  Lwt_main.run
  @@ let%lwt n_skipped, n_failed, n_matched, matched_secrets =
       Lwt_list.fold_left_s
         (fun (n_skipped, n_failed, n_matched, matched_secrets) secret ->
           match%lwt Storage.Secrets.search secret pattern with
           | Succeeded true -> Lwt.return (n_skipped, n_failed, n_matched + 1, secret :: matched_secrets)
           | Succeeded false -> Lwt.return (n_skipped, n_failed, n_matched, matched_secrets)
           | Skipped ->
             let%lwt () = verbose_printlf "I: skipped %s" (show_name secret) in
             Lwt.return (n_skipped + 1, n_failed, n_matched, matched_secrets)
           | Failed exn ->
             let%lwt () = Lwt_io.printlf "W: failed to search %s : %s" (show_name secret) (Exn.to_string exn) in
             Lwt.return (n_skipped, n_failed + 1, n_matched, matched_secrets))
         (0, 0, 0, []) secrets
     in
     let%lwt () =
       Lwt_io.printlf "I: skipped %d secrets, failed to search %d secrets and matched %d secrets" n_skipped n_failed
         n_matched
     in
     List.rev matched_secrets |> Lwt_list.iter_s (fun s -> Lwt_io.printl (show_name s))

let substitute_template template_file target_file name_mappings =
  Lwt_main.run
  @@
  let name_mappings = Hashtbl.of_seq (List.to_seq name_mappings) in
  try%lwt Template.substitute_file ~template_file ~target_file name_mappings
  with exn -> die ~exn "E: failed to substitute file"

open Cmdliner

let secret_arg =
  let parse secret_name = try Ok (Storage.Secrets.build_secret_name secret_name) with Failure s -> Error (`Msg s) in
  let print ppf p = Format.fprintf ppf "%s" (show_name p) in
  Arg.conv (parse, print)

let path_arg =
  let parse rel_path = try Ok (Storage.Secrets.build_path rel_path) with Failure s -> Error (`Msg s) in
  let print ppf p = Format.fprintf ppf "%s" (show_path p) in
  Arg.conv (parse, print)

let file_arg =
  let parse file = try Ok (Path.inject file) with Failure s -> Error (`Msg s) in
  let print ppf p = Format.fprintf ppf "%s" (show_path p) in
  Arg.conv (parse, print)

let pattern_arg =
  let parse pattern = try Ok (Re2.create_exn pattern) with Re2.Exceptions.Regex_compile_failed s -> Error (`Msg s) in
  let print ppf pattern = Format.fprintf ppf "%s" (Re2.to_string pattern) in
  Arg.conv (parse, print)

let recipient_name =
  let doc = "the name of the recipient" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"RECIPIENT_NAME" ~doc)

let secret_name =
  let doc = "the name of the secret" in
  Arg.(required & pos 0 (some secret_arg) None & info [] ~docv:"SECRET_NAME" ~doc)

let secret_output_mode =
  let qrcode =
    let doc = "encode and display the secret as a QRCode" in
    QrCode, Arg.info [ "q"; "qrcode" ] ~doc
  in
  let clipboard =
    let doc = "clips the secret to the system clipboard. Requires an X server to be running." in
    Clipboard, Arg.info [ "c"; "clip" ] ~doc
  in
  Arg.(value & vflag Stdout [ qrcode; clipboard ])

let secret_line_number =
  let doc = "the $(docv) of the specified secret to be output" in
  Arg.(value & opt (some int) None & info [ "l"; "line" ] ~docv:"LINE" ~doc)

let secrets_path =
  let doc = "the relative $(docv) from the secrets directory that will be used to process secrets" in
  Arg.(value & pos 0 path_arg (Storage.Secrets.build_path ".") & info [] ~docv:"PATH" ~doc)

let template_file =
  let doc = "the path of the template file" in
  Arg.(required & pos 0 (some file_arg) None & info [] ~doc ~docv:"TEMPLATE_FILE")

let target_file =
  let doc = "the target file for templating" in
  Arg.(required & pos 1 (some file_arg) None & info [] ~doc ~docv:"TARGET_FILE")

let secret_name_mappings =
  let key_value_arg =
    let parse key_value =
      match String.split_on_char '=' key_value with
      | [ key; value ] when key <> "" && value <> "" -> Ok (key, value)
      | _ ->
        Error
          (`Msg (sprintf "failed to parse key-value pair. Expected format of 'KEY=VALUE' but received '%s'" key_value))
    in
    let print ppf (key, value) = Format.fprintf ppf "%s=%s" key value in
    Arg.conv (parse, print)
  in
  let doc = "the mappings from the identifier specified in the template file, to its actual secret name" in
  Arg.(value & pos_right 1 key_value_arg [] & info [] ~doc ~docv:"KEY_VALUE_PAIR")

let set_verbosity =
  let doc = "print verbose output during execution" in
  let verbose = Verbose, Arg.info [ "v"; "verbose" ] ~doc in
  let verbosity_term = Arg.(value & vflag Normal [ verbose ]) in
  Term.(const (fun v -> verbosity := v) $ verbosity_term)

let append_cmd =
  let doc = "append content to the specified secret" in
  let info = Cmd.info "append" ~doc in
  let term = Term.(const append_to_secret $ secret_name) in
  Cmd.v info term

let edit_cmd =
  let doc = "edit the contents of the specified secret" in
  let info = Cmd.info "edit" ~doc in
  let term = Term.(const edit_secret_in_editor $ secret_name) in
  Cmd.v info term

let replace_cmd =
  let doc = "replace the contents of the specified secret" in
  let info = Cmd.info "replace" ~doc in
  let term = Term.(const replace_secret $ secret_name) in
  Cmd.v info term

let get_cmd =
  let doc = "get the contents of the specified secret, including comments" in
  let info = Cmd.info "get" ~doc in
  let get secret_name output_mode line_number = get_secret ~with_comments:true ?line_number secret_name output_mode in
  let term = Term.(const get $ secret_name $ secret_output_mode $ secret_line_number) in
  Cmd.v info term

let head_cmd =
  let doc = "get the (only) line of the specified single-line secret, while excluding any comments" in
  let info = Cmd.info "head" ~doc in
  let head secret_name output_mode =
    get_secret ~expected_kind:Singleline ~with_comments:false secret_name output_mode
  in
  let term = Term.(const head $ secret_name $ secret_output_mode) in
  Cmd.v info term

let search_cmd =
  let pattern =
    let doc = "the pattern to match against" in
    Arg.(required & pos 0 (some pattern_arg) None & info [] ~docv:"PATTERN" ~doc)
  in
  let secrets_path =
    let doc = "the relative $(docv) from the secrets directory that will be searched" in
    Arg.(value & pos 1 path_arg (Storage.Secrets.build_path ".") & info [] ~docv:"PATH" ~doc)
  in
  let term = Term.(const (fun () -> search_secrets) $ set_verbosity $ pattern $ secrets_path) in
  let doc = "list secrets in the specified path, containing contents that match the specified pattern" in
  let info = Cmd.info "search" ~doc in
  Cmd.v info term

let secret_cmd =
  let doc = "get the contents of the specified secret, while excluding any comments" in
  let info = Cmd.info "secret" ~doc in
  let secret secret_name output_mode = get_secret ~with_comments:false secret_name output_mode in
  let term = Term.(const secret $ secret_name $ secret_output_mode) in
  Cmd.v info term

let list_cmd =
  let doc = "recursively list all secrets" in
  let info = Cmd.info "list" ~doc in
  let term = Term.(const list_secrets $ secrets_path) in
  Cmd.v info term

let ls_cmd =
  let doc = "an alias for the list command" in
  let info = Cmd.info "ls" ~doc in
  let term = Term.(const list_secrets $ secrets_path) in
  Cmd.v info term

let refresh_cmd =
  let doc = "re-encrypt secrets in the specified path" in
  let info = Cmd.info "refresh" ~doc in
  let term = Term.(const (fun () -> refresh_secrets) $ set_verbosity $ secrets_path) in
  Cmd.v info term

let show_cmd =
  let doc = "recursively list all secrets in a tree-like format" in
  let info = Cmd.info "show" ~doc in
  let term = Term.(const list_secrets_tree $ secrets_path) in
  Cmd.v info term

let template_cmd =
  let doc = "outputs target file by substituting all secrets in the template file" in
  let info = Cmd.info "template" ~doc in
  let term = Term.(const substitute_template $ template_file $ target_file $ secret_name_mappings) in
  Cmd.v info term

let who_cmd =
  let doc = "list all recipients of secrets in the specified path" in
  let info = Cmd.info "who" ~doc in
  let term = Term.(const list_recipients $ secrets_path) in
  Cmd.v info term

let what_cmd =
  let doc = "list secrets that a recipient has access to" in
  let info = Cmd.info "what" ~doc in
  let term = Term.(const list_recipient_secrets $ recipient_name) in
  Cmd.v info term

let () =
  let help = Term.(ret (const (`Help (`Pager, None)))) in
  let info = Cmd.info "passage" ~doc:"store and manage access to shared secrets" in
  let commands =
    [
      append_cmd;
      edit_cmd;
      get_cmd;
      head_cmd;
      list_cmd;
      ls_cmd;
      refresh_cmd;
      replace_cmd;
      search_cmd;
      secret_cmd;
      show_cmd;
      template_cmd;
      what_cmd;
      who_cmd;
    ]
  in
  let group = Cmd.group info ~default:help commands in
  exit @@ Cmd.eval ~catch:true group
