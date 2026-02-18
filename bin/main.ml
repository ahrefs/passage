open Printf
open Cmdliner
open Comment_input
open Passage
open Prompt
open Util.Secret
open Util.Show

type output_mode =
  | Clipboard
  | QrCode
  | Stdout

let eprintfn = Util.eprintfn

module Converters = struct
  let secret_arg =
    let parse secret_name = try Ok (Storage.Secrets.build_secret_name secret_name) with Failure s -> Error (`Msg s) in
    let print ppf p = Format.fprintf ppf "%s" (show_name p) in
    Arg.conv (parse, print)

  let path_arg =
    let parse rel_path = try Ok (Path.build_rel_path rel_path) with Failure s -> Error (`Msg s) in
    let print ppf p = Format.fprintf ppf "%s" (show_path p) in
    Arg.conv (parse, print)

  let template_arg =
    let parse template = try Ok (Template.parse template) with Failure s -> Error (`Msg s) in
    let print ppf p = Format.fprintf ppf "%s" (String.concat " " (List.map Template_ast.to_string p)) in
    Arg.conv (parse, print)

  let file_arg =
    let parse file = try Ok (Path.inject file) with Failure s -> Error (`Msg s) in
    let print ppf p = Format.fprintf ppf "%s" (show_path p) in
    Arg.conv (parse, print)

  let pattern_arg =
    let parse pattern =
      try Ok (pattern, Re.Perl.compile_pat pattern) with
      | Re.Perl.Parse_error -> Error (`Msg (Printf.sprintf "invalid regex pattern: %s" pattern))
      | Re.Perl.Not_supported -> Error (`Msg (Printf.sprintf "regex pattern not supported: %s" pattern))
    in
    let print ppf (pattern, _) = Format.fprintf ppf "%s" pattern in
    Arg.conv (parse, print)
end

module Flags = struct
  let secret_line_number =
    let doc = "the $(docv) of the specified secret to be output" in
    Arg.(value & opt (some int) None & info [ "l"; "line" ] ~docv:"LINE" ~doc)

  let secret_name =
    let doc = "the name of the secret" in
    Arg.(required & pos 0 (some Converters.secret_arg) None & info [] ~docv:"SECRET_NAME" ~doc)

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

  let secrets_path =
    let doc = "the relative $(docv) from the secrets directory that will be used to process secrets" in
    Arg.(value & pos 0 Converters.path_arg (Path.inject ".") & info [] ~docv:"PATH" ~doc)

  let secrets_paths =
    let doc = "list of relative $(docv)s from the secrets directory that will be used to process secrets" in
    Arg.(value & pos_all Converters.path_arg [ Path.inject "." ] & info [] ~docv:"PATH" ~doc)

  let secrets_paths_or_recipients =
    let doc =
      "list of relative $(docv)s from the secrets directory or @recipient/@group names that will be used to process \
       secrets"
    in
    Arg.(value & pos_all string [ "." ] & info [] ~docv:"PATH" ~doc)

  let verbose =
    let doc = "print verbose output during execution" in
    Arg.(value & flag & info [ "v"; "verbose" ] ~doc)

  let template_file =
    let doc = "the path of the template file" in
    Arg.(required & pos 0 (some Converters.file_arg) None & info [] ~doc ~docv:"TEMPLATE_FILE")

  let comment =
    let doc = "optional comment to add to the secret" in
    Arg.(value & opt (some string) None & info [ "comment" ] ~docv:"COMMENT" ~doc)
end

module Add_who = struct
  let recipient_names =
    let doc = "the names of the recipients to add. Can be one or many" in
    Arg.(non_empty & pos_right 0 string [] & info [] ~docv:"RECIPIENT" ~doc)

  let add_who =
    let doc = "add recipients to the specified secret" in
    let info = Cmd.info "add-who" ~doc in
    let term =
      Term.(
        const (fun secret_name recipients_to_add ->
          try Commands.Recipients.add_recipients_to_secret secret_name recipients_to_add
          with Failure s -> Shell.die "%s" s)
        $ Flags.secret_name
        $ recipient_names)
    in
    Cmd.v info term
end

module Rm_who = struct
  let recipient_names =
    let doc = "the names of the recipients to remove. Can be one or many" in
    Arg.(non_empty & pos_right 0 string [] & info [] ~docv:"RECIPIENT" ~doc)

  let rm_who =
    let doc = "remove recipients from the specified secret" in
    let info = Cmd.info "rm-who" ~doc in
    let term =
      Term.(
        const (fun secret_name recipients_to_remove ->
          try Commands.Recipients.remove_recipients_from_secret secret_name recipients_to_remove
          with Failure s -> Shell.die "%s" s)
        $ Flags.secret_name
        $ recipient_names)
    in
    Cmd.v info term
end

module Create = struct
  let create_new_secret_from_stdin ~comments secret_name =
    try
      match get_valid_input_from_stdin_exn () with
      | Error e -> Shell.die "E: %s" e
      | Ok plaintext_secret -> Commands.Create.add ~comments secret_name plaintext_secret
    with Failure s -> Shell.die "%s" s
  let create =
    let doc =
      {| creates a new secret from stdin. If the folder doesn't have recipients specified already,
      tries to set them to the ones associated with \${PASSAGE_IDENTITY} |}
    in
    let info = Cmd.info "create" ~doc in
    let term =
      Term.(
        const (fun secret_name comments -> create_new_secret_from_stdin ~comments secret_name)
        $ Flags.secret_name
        $ Flags.comment)
    in
    Cmd.v info term
end

module Edit_cmd = struct
  let edit secret_name =
    try
      check_exists_or_die secret_name;
      Invariant.run_if_recipient ~op_string:"edit secret"
        ~path:Storage.Secrets.(to_path secret_name)
        ~f:(fun () ->
          Commands.Edit.edit_secret secret_name ~allow_retry:Retry.encrypt_with_retry
            ~get_updated_secret:(fun initial ->
            let initial_content =
              Option.map (fun i -> i ^ Secret.format_explainer) initial |> Option.value ~default:Secret.format_explainer
            in
            Editor.edit_with_validation ~initial:initial_content ~validate:Validation.validate_secret ()))
    with Failure s -> Shell.die "%s" s

  let edit =
    let doc = "edit the contents of the specified secret" in
    let info = Cmd.info "edit" ~doc in
    let term = Term.(const edit $ Flags.secret_name) in
    Cmd.v info term
end

module Edit_who = struct
  let edit_who_with_check secret_name =
    let secret_path = Storage.Secrets.(to_path secret_name) in
    match Path.is_directory (Path.abs secret_path), Storage.Secrets.secret_exists_at secret_path with
    | false, false -> Shell.die "E: no such secret: %s" (show_name secret_name)
    | _ ->
      let path = Storage.Secrets.(to_path secret_name) in
      (try Invariant.run_if_recipient ~op_string:"edit recipients" ~path ~f:(fun () -> edit_recipients secret_name)
       with Failure s -> Shell.die "%s" s)

  let edit_who =
    let doc =
      "edit the recipients of the specified path.  Note that recipients are not inherited from folders higher up\n\
      \  in the tree, so all recipients need to be specified at the level of the immediately containing folder."
    in
    let info = Cmd.info "edit-who" ~doc in
    let term = Term.(const edit_who_with_check $ Flags.secret_name) in
    Cmd.v info term
end

module Edit_comments = struct
  let edit_comments secret_name =
    try
      check_exists_or_die secret_name;
      let path = Storage.Secrets.(to_path secret_name) in
      Invariant.run_if_recipient ~op_string:"edit comments" ~path ~f:(fun () ->
        let parsed_secret = decrypt_and_parse secret_name in
        let new_comments = get_comments ?initial:parsed_secret.comments () in
        match parsed_secret.comments, new_comments = "" with
        | None, true -> prerr_endline "I: comments unchanged"
        | Some old, false when old = new_comments -> prerr_endline "I: comments unchanged"
        | _ ->
          let updated_secret = reconstruct_secret ~comments:new_comments parsed_secret in
          let secret_recipients = Util.Recipients.get_recipients_or_die secret_name in
          (try Retry.encrypt_with_retry ~plaintext:updated_secret ~secret_name secret_recipients
           with exn -> Shell.die ~exn "E: encrypting %s failed" (show_name secret_name)))
    with Failure s -> Shell.die "%s" s

  let edit_comments_cmd =
    let doc = "edit the comments of the specified secret" in
    let info = Cmd.info "edit-comments" ~doc in
    let term = Term.(const edit_comments $ Flags.secret_name) in
    Cmd.v info term
end

module Get = struct
  module Output = struct
    let clip_time = Option.value (Sys.getenv_opt "PASSAGE_CLIP_TIME") ~default:"45" |> int_of_string

    let print_as_qrcode ~secret_name ~secret =
      match Qrc.encode secret with
      | None -> Shell.die "Failed to encode %s as QR code. Data capacity exceeded!" (show_name secret_name)
      | Some m -> Qrc_fmt.pp_utf_8_half ~invert:true Format.std_formatter m

    let save_to_clipboard_exn ~secret =
      let x_selection = Sys.getenv_opt "PASSAGE_X_SELECTION" in
      let read_clipboard () = Shell.xclip_read_clipboard ?x_selection () in
      let copy_to_clipboard s =
        try Shell.xclip_copy_to_clipboard ?x_selection s
        with exn -> Exn.die ~exn "E: could not copy data to the clipboard"
      in
      let restore_clipboard original_content =
        let () = Unix.sleep clip_time in
        let current_content = read_clipboard () in
        (* It might be nice to programatically check to see if klipper exists,
           as well as checking for other common clipboard managers. But for now,
           this works fine -- if qdbus isn't there or if klipper isn't running,
           this essentially becomes a no-op.

           Clipboard managers frequently write their history out in plaintext,
           so we axe it here: *)
        let () =
          try Shell.clear_clipboard_managers ()
          with _ ->
            (* any exns raised are likely due to qdbus, klipper, etc., being absent.
               Thus, we swallow these exns so that it becomes a no-op *)
            ()
        in
        match current_content = secret with
        | false ->
          (* clipboard was used and overwritten, so we don't attempt to perform any restoration *)
          ()
        | true -> copy_to_clipboard original_content
      in
      let original_content = read_clipboard () in
      let () = copy_to_clipboard secret in
      (* flush before forking to avoid double-flush *)
      let () = flush_all () in
      match Unix.fork () with
      | 0 ->
        (* Child process *)
        let (_ : int) = Unix.setsid () in
        let () = restore_clipboard original_content in
        `Child
      | pid ->
        (* Parent process *)
        `Forked pid

    let save_to_clipboard ~secret_name ~secret =
      match save_to_clipboard_exn ~secret with
      | `Child -> ()
      | `Forked _ -> eprintfn "Copied %s to clipboard. Will clear in %d seconds." (show_name secret_name) clip_time
      | exception exn -> Shell.die ~exn "E: failed to save to clipboard! Check if you have an X server running."
  end

  let get_secret ?expected_kind ?line_number ~with_comments ?(trim_new_line = false) secret_name output_mode =
    let secret =
      try Commands.Get.get_secret ?expected_kind ?line_number ~with_comments ~trim_new_line secret_name
      with Failure s -> Shell.die "%s" s
    in
    match output_mode with
    | QrCode -> Output.print_as_qrcode ~secret_name ~secret
    | Clipboard -> Output.save_to_clipboard ~secret_name ~secret
    | Stdout -> print_string secret

  let singleline_only =
    let doc =
      "retrieves the secret only if it is a single-line format secret. Returns an error for multi-line secrets"
    in
    Arg.(value & vflag None & [ Some Secret.Singleline, info [ "s"; "singleline" ] ~docv:"SINGLELINE" ~doc ])

  let trim_new_line =
    let doc = "Outputs secrets without the new-line at the end of the output" in
    Arg.(value & flag & info [ "n"; "no-new-line" ] ~doc)

  let term =
    let get secret_name output_mode line_number expected_kind trim_new_line =
      get_secret ?expected_kind ~with_comments:false ?line_number ~trim_new_line secret_name output_mode
    in
    Term.(
      const get
      $ Flags.secret_name
      $ Flags.secret_output_mode
      $ Flags.secret_line_number
      $ singleline_only
      $ trim_new_line)

  let get =
    let doc = "get the text of the specified secret, excluding comments" in
    let info = Cmd.info "get" ~doc in
    Cmd.v info term

  let secret =
    let doc = "an alias for the `get` command" in
    let info = Cmd.info "secret" ~doc in
    Cmd.v info term

  let cat secret_name output_mode line_number = get_secret ~with_comments:true ?line_number secret_name output_mode
  let cat_cmd =
    let term = Term.(const cat $ Flags.secret_name $ Flags.secret_output_mode $ Flags.secret_line_number) in
    let doc = "get the whole contents of the specified secret, including comments" in
    let info = Cmd.info "cat" ~doc in
    Cmd.v info term
end

module Healthcheck = struct
  type upgrade_mode =
    | NoUpgrade
    | DryRun
    | Upgrade

  let healthcheck_with_errors = ref false

  let secrets_upgrade_mode =
    let upgrade_mode =
      [
        DryRun, Arg.info [ "dry-run-upgrade-legacy-secrets" ] ~doc:"dry run on the legacy secrets upgrade";
        Upgrade, Arg.info [ "upgrade-legacy-secrets" ] ~doc:"upgrade found legacy secrets";
      ]
    in
    Arg.(value & vflag NoUpgrade upgrade_mode)

  let print_install () =
    let () =
      prerr_endline
        {|
==========================================================================
Checking passage installation
==========================================================================|}
    in
    let id_from_env = Sys.getenv_opt "PASSAGE_IDENTITY" in
    let identity_path =
      match id_from_env with
      | Some path -> path
      | None ->
        let base_dir = Lazy.force !Config.base_dir in
        Filename.concat base_dir "identity.key"
    in
    match Sys.file_exists identity_path with
    | false ->
      prerr_endline "\n❌ ERROR: Passage is not set up";
      Shell.die "\nPassage identity file not found. Please run 'passage init' to set up passage."
    | true ->
    try
      prerr_endline "\n✅ Passage is configured";
      let own_key_str = Age.Key.project (Age.Key.from_identity_file identity_path) in
      let recipients = Storage.Secrets.recipients_of_own_id () in
      (match recipients with
      | [] -> prerr_endline "\n⚠️  WARNING: No registered recipient names found for your identity"
      | _ ->
        prerr_endline "\nRegistered recipient name(s):";
        List.iter (fun (r : Age.recipient) -> eprintfn "  - %s\n" r.name) recipients);
      (match id_from_env with
      | Some _ -> eprintfn "Identity key path: %s (from PASSAGE_IDENTITY environment variable)\n" identity_path
      | None -> eprintfn "Identity key path: %s\n" identity_path);

      eprintfn "Public key: %s" own_key_str
    with exn ->
      prerr_endline "\n❌ ERROR: Failed to read passage installation\n";
      Shell.die "Reason: %s" (Printexc.to_string exn)

  let check_folders_without_keys_file () =
    let () =
      prerr_endline
        {|
==========================================================================
Checking for folders without .keys file
==========================================================================|}
    in
    let folders_without_keys_file = Storage.Secrets.(all_paths () |> List.filter has_secret_no_keys) in
    match folders_without_keys_file with
    | [] -> prerr_endline "\nSUCCESS: secrets all have .keys in the immediate directory"
    | _ ->
      let () = print_endline "\nERROR: found paths with secrets but no .keys file:" in
      let () = List.iter (fun p -> eprintfn "- %s" (show_path p)) folders_without_keys_file in
      let () = flush stderr in
      healthcheck_with_errors := true

  let check_own_secrets_validity verbose upgrade_mode =
    let open Storage in
    let () =
      prerr_endline
        {|
==========================================================================
Checking for validity of own secrets. Use -v flag to break down per secret
==========================================================================
|}
    in
    match Secrets.recipients_of_own_id () with
    | [] -> prerr_endline "⚠️  Not a recipient of any secrets"
    | recipients_of_own_id ->
      List.iter
        (fun (recipient : Age.recipient) ->
          match Secrets.get_secrets_for_recipient recipient.name with
          | [] -> Printf.eprintf "No secrets found for %s" recipient.name
          | secrets ->
            let sorted_secrets = List.sort Secret_name.compare secrets in
            let ok, invalid, fail =
              List.fold_left
                (fun (ok, invalid, fail) secret_name ->
                  try
                    let secret_text = Secrets.decrypt_exn ~silence_stderr:true secret_name in
                    match Secret.Validation.validate secret_text with
                    | Ok kind ->
                      let () =
                        Util.verbose_eprintlf ~verbose "✅ %s [ valid %s ]" (show_name secret_name)
                          (Secret.kind_to_string kind)
                      in
                      succ ok, invalid, fail
                    | Error (e, validation_error_type) ->
                      healthcheck_with_errors := true;
                      let () = eprintfn "❌ %s [ invalid format: %s ]" (show_name secret_name) e in
                      let upgraded_secrets =
                        match upgrade_mode, validation_error_type with
                        | Upgrade, SingleLineLegacy ->
                          (try
                             let parsed_secret = Secret.Validation.parse_exn secret_text in
                             let upgraded_secret = reconstruct_secret ?comments:parsed_secret.comments parsed_secret in
                             let recipients = Util.Recipients.get_recipients_or_die secret_name in
                             Storage.Secrets.encrypt_exn ~verbose:false ~plaintext:upgraded_secret ~secret_name
                               recipients;
                             eprintfn "I: updated %s" (show_name secret_name);
                             1
                           with exn ->
                             eprintfn "E: encrypting %s failed: %s" (show_name secret_name) (Printexc.to_string exn);
                             0)
                        | DryRun, SingleLineLegacy ->
                          eprintfn "I: would update %s" (show_name secret_name);
                          1
                        | NoUpgrade, _ | Upgrade, _ | DryRun, _ -> 0
                      in
                      ok + upgraded_secrets, succ (invalid - upgraded_secrets), fail
                  with _ ->
                    let () = eprintfn "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret_name) in
                    ok, invalid, succ fail)
                (0, 0, 0) sorted_secrets
            in
            let () = eprintfn "\nI: %i valid secrets, %i invalid and %i with decryption issues" ok invalid fail in
            ())
        recipients_of_own_id

  let healthcheck verbose upgrade_mode =
    let () = prerr_endline {|
PASSAGE HEALTHCHECK. Diagnose for common problems|} in
    let () = print_install () in
    let () = check_folders_without_keys_file () in
    let () = check_own_secrets_validity verbose upgrade_mode in
    match !healthcheck_with_errors with
    | true -> exit 1
    | false -> exit 0

  let healthcheck =
    let doc = "check for issues with secrets, find directories that don't have keys, etc." in
    let info = Cmd.info "healthcheck" ~doc in
    let term = Term.(const healthcheck $ Flags.verbose $ secrets_upgrade_mode) in
    Cmd.v info term
end

module Init = struct
  let init =
    let doc = "initial setup of passage" in
    let force =
      let doc = "force creating of config directory" in
      Arg.(value & flag & info [ "f"; "force" ] ~doc)
    in
    let info = Cmd.info "init" ~doc in
    let term =
      Term.(const (fun force -> try Commands.Init.init ~force () with Failure s -> Shell.die "%s" s) $ force)
    in
    Cmd.v info term
end

module List_ = struct
  let list_secrets path =
    try Commands.List_.list_secrets path |> List.iter print_endline with Failure s -> Shell.die "%s" s

  let list =
    let doc = "recursively list all secrets" in
    let info = Cmd.info "list" ~doc in
    let term = Term.(const list_secrets $ Flags.secrets_path) in
    Cmd.v info term

  let ls =
    let doc = "an alias for the list command" in
    let info = Cmd.info "ls" ~doc in
    let term = Term.(const list_secrets $ Flags.secrets_path) in
    Cmd.v info term
end

module New = struct
  let create_new_secret secret_name =
    try
      let wiz secret_name =
        let () =
          Commands.Edit.edit_secret ~self_fallback:true secret_name ~allow_retry:Retry.encrypt_with_retry
            ~get_updated_secret:(fun initial ->
            let initial_content = Option.value ~default:Secret.format_explainer initial in
            Editor.edit_with_validation ~initial:initial_content ~validate:Validation.validate_secret ())
        in
        let original_recipients = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name) in
        Commands.Edit.show_recipients_notice_if_true (original_recipients = []);
        if yesno "Edit recipients for this secret?" then edit_recipients secret_name
      in
      Commands.Create.bare ~f:wiz secret_name
    with Failure s -> Shell.die "%s" s

  let new_ =
    let doc = "interactive creation of a new secret" in
    let info = Cmd.info "new" ~doc in
    let term = Term.(const create_new_secret $ Flags.secret_name) in
    Cmd.v info term
end

module Realpath = struct
  let realpath =
    let doc =
      "show the full filesystem path to secrets/folders.  Note it will only list existing files or directories."
    in
    let info = Cmd.info "realpath" ~doc in
    let term =
      Term.(
        const (fun paths ->
          Commands.Realpath.realpath paths
          |> List.iter (fun r ->
            match r with
            | Ok path -> print_endline path
            | Error e -> Printf.eprintf "W: %s\n" e))
        $ Flags.secrets_paths)
    in
    Cmd.v info term
end

module Refresh = struct
  let refresh =
    let doc =
      "re-encrypt secrets in the specified path(s) or for the specified recipients. Use the @prefix to indicate \
       recipients or groups of recipients."
    in
    let info = Cmd.info "refresh" ~doc in
    let term =
      Term.(
        const (fun verbose paths ->
          try Commands.Refresh.refresh_secrets ~verbose paths with Failure s -> Shell.die "%s" s)
        $ Flags.verbose
        $ Flags.secrets_paths_or_recipients)
    in
    Cmd.v info term
end

module Replace = struct
  let replace_secret secret_name =
    try
      let () = input_help_if_user_input () in
      Commands.Replace.replace_secret secret_name (In_channel.input_all stdin)
    with Failure s -> Shell.die "%s" s

  let replace =
    let doc =
      "replaces the contents of the specified secret, keeping the comments. If the secret doesn't exist, it gets \
       created as a single or multi-line secret WITHOUT any comments"
    in
    let info = Cmd.info "replace" ~doc in
    let term = Term.(const replace_secret $ Flags.secret_name) in
    Cmd.v info term
end

module Replace_comments = struct
  let replace_comment secret_name =
    try
      let get_new_comments original_comments =
        get_comments ?initial:original_comments
          ~help_message:"Please type the new comments and then do Ctrl+d twice to terminate input" ()
      in
      Commands.Replace.replace_comment secret_name get_new_comments
    with Failure s -> Shell.die "%s" s

  let replace_comments =
    let doc = "replaces the comments of the specified secret, keeping the secret." in
    let info = Cmd.info "replace-comment" ~doc in
    let term = Term.(const replace_comment $ Flags.secret_name) in
    Cmd.v info term
end

module Rm = struct
  let force =
    let doc = "Delete secrets and folders" in
    Arg.(value & flag & info [ "f"; "force" ] ~doc)

  let rm_secrets verbose paths force =
    let confirm ~path = yesno (sprintf "Are you sure you want to delete %s?" (show_path path)) in
    try Commands.Rm.rm_secrets ~verbose ~paths ~force ~confirm () with Failure s -> Shell.die "%s" s

  let rm =
    let doc = "remove a secret or a folder and its secrets" in
    let info = Cmd.info "rm" ~doc in
    let term = Term.(const rm_secrets $ Flags.verbose $ Flags.secrets_paths $ force) in
    Cmd.v info term

  let delete =
    let doc = "same as the $(i,rm) cmd. Remove a secret or a folder and its secrets" in
    let info = Cmd.info "delete" ~doc in
    let term = Term.(const rm_secrets $ Flags.verbose $ Flags.secrets_paths $ force) in
    Cmd.v info term
end

module Search = struct
  let search =
    let pattern =
      let doc = "the pattern to match against" in
      Arg.(required & pos 0 (some Converters.pattern_arg) None & info [] ~docv:"PATTERN" ~doc)
    in
    let secrets_path =
      let doc = "the relative $(docv) from the secrets directory that will be searched" in
      Arg.(value & pos 1 Converters.path_arg (Path.inject ".") & info [] ~docv:"PATH" ~doc)
    in
    let term =
      Term.(
        const (fun verbose pattern secrets_path ->
          let _, compiled_pattern = pattern in
          try Commands.Search.search_secrets ~verbose compiled_pattern secrets_path with Failure s -> Shell.die "%s" s)
        $ Flags.verbose
        $ pattern
        $ secrets_path)
    in
    let doc = "list secrets in the specified path, containing contents that match the specified pattern" in
    let info = Cmd.info "search" ~doc in
    Cmd.v info term
end

module Show = struct
  let show =
    let doc =
      "recursively list all secrets in a tree-like format. If used on a single secret, it will work the same as the \
       cat command."
    in
    let info = Cmd.info "show" ~doc in
    let term =
      Term.(
        const (fun path ->
          try Printf.printf "%s" @@ Commands.Show.list_secrets_tree path with Failure s -> Shell.die "%s" s)
        $ Flags.secrets_path)
    in
    Cmd.v info term
end

module Subst = struct
  let template =
    let doc = "a template on the commandline" in
    Arg.(required & pos 0 (some Converters.template_arg) None & info [] ~doc ~docv:"TEMPLATE_ARG")

  let substitute template =
    try
      let contents = Commands.Template.substitute ~template in
      print_string contents
    with exn -> Shell.die ~exn "E: failed to substitute"

  let subst =
    let doc = "fill in values in the provided template" in
    let info = Cmd.info "subst" ~doc in
    let term = Term.(const substitute $ template) in
    Cmd.v info term
end

module Template_cmd = struct
  let substitute_template template_file target_file =
    try
      let contents = Commands.Template.substitute_file ~template_file in
      match target_file with
      | None -> print_string contents
      | Some target_file ->
        let target_file = Path.project target_file in
        Storage.save_as ~path:target_file ~mode:0o600 (fun oc -> output_string oc contents)
    with exn -> Shell.die ~exn "E: failed to substitute file"

  let target_file =
    let doc = "the target file for templating if present, otherwise output to standard output" in
    Arg.(value & pos 1 (some Converters.file_arg) None & info [] ~doc ~docv:"TARGET_FILE")

  let template =
    let doc = "outputs target file by substituting all secrets in the template file" in
    let info = Cmd.info "template" ~doc in
    let term = Term.(const substitute_template $ Flags.template_file $ target_file) in
    Cmd.v info term
end

module Template_secrets = struct
  let template_secrets =
    let doc = "sorted unique list of secret references found in a template. Secrets are not checked for existence" in
    let info = Cmd.info "template-secrets" ~doc in
    let term =
      Term.(
        const (fun template_file ->
          try
            let ss = Commands.Template.list_template_secrets template_file in
            List.iter print_endline ss
          with Failure s -> Shell.die "%s" s)
        $ Flags.template_file)
    in
    Cmd.v info term
end

module What = struct
  let recipient_name =
    let doc = "the names of the recipients. Can be one or many" in
    Arg.(value & pos_all string [] & info [] ~docv:"PATH" ~doc)

  let what =
    let doc = "list secrets that a recipient has access to" in
    let info = Cmd.info "what" ~doc in
    let term =
      Term.(
        const (fun names verbose ->
          try Commands.Recipients.list_recipient_secrets ~verbose names with Failure s -> Shell.die "%s" s)
        $ recipient_name
        $ Flags.verbose)
    in
    Cmd.v info term
end

module My = struct
  let list_my_secrets () =
    let recipients_of_own_id = Storage.Secrets.recipients_of_own_id () in
    let recipients_names = List.map (fun r -> r.Age.name) recipients_of_own_id in
    try Commands.Recipients.list_recipient_secrets ~verbose:false recipients_names with Failure s -> Shell.die "%s" s

  let my =
    let doc = "list secrets that you have access to (alias for 'what <your.name>')" in
    let info = Cmd.info "my" ~doc in
    let term = Term.(const list_my_secrets $ const ()) in
    Cmd.v info term
end

module Who = struct
  let expand_groups =
    let doc = "Expand groups of recipients in the output." in
    Arg.(value & flag & info [ "f"; "expand-groups" ] ~doc)

  let who =
    let doc = "list all recipients of secrets in the specified path" in
    let info = Cmd.info "who" ~doc in
    let term =
      Term.(
        const (fun secrets_path expand_groups ->
          try Commands.Recipients.list_recipients secrets_path expand_groups with Failure s -> Shell.die "%s" s)
        $ Flags.secrets_path
        $ expand_groups)
    in
    Cmd.v info term
end

let () =
  let envs =
    List.map
      (fun (nm, doc) -> Cmd.Env.info ~doc nm)
      [
        "PASSAGE_DIR", "Overrides the default `passage` directory. Default: \\${HOME}/.config/passage";
        "PASSAGE_KEYS", "Overrides the default `passage` keys directory. Default: \\${PASSAGE_DIR}/keys";
        "PASSAGE_SECRETS", "Overrides the default `passage` secrets directory. Default: \\${PASSAGE_DIR}/secrets";
        ( "PASSAGE_IDENTITY",
          "Overrides the default identity `.key` file that will be used by `passage`. Default: \
           \\${PASSAGE_DIR}/identity.key" );
        ( "PASSAGE_X_SELECTION",
          "Overrides the default X selection to use when clipping to clipboard. Allowed values are `primary`, \
           `secondary`, or `clipboard` (default)." );
        "PASSAGE_CLIP_TIME", "Overrides the default clip time. Specified in seconds. Default: 45";
      ]
  in
  let help = Term.(ret (const (`Help (`Pager, None)))) in
  let doc = {|Store and manage access to shared secrets
|} in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(tname) is a tool to store and manage access to shared secrets. Secrets are injested and, based on their \
         text format, get parsed into two types of secrets: single and multi-line secrets. This is very important for \
         when retrieving the secrets. Please check the $(i,examples) section below for an explanation of the formats. ";
      `P "Secrets that don't conform to these formats will be rejected.";
      `S Manpage.s_examples;
      `P "$(b,Multiline secret with comments:)";
      `Pre
        {| <empty line>
 possibly several lines of comments
 without empty lines in the middle
 <empty line>
 secret until end of file|};
      `P "$(b,Multiline secret without comments:)";
      `Pre {| <empty line>
 <empty line>
 secret until end of file|};
      `P "$(b,Single line secret without commments:)";
      `Pre {| secret one line |};
      `P "$(b,Single line secret with commments:)";
      `Pre {| secret one line
 <empty line>
 comments until end of file|};
      `P "$(b,Single line secret without commments legacy [DEPRECATED]:)";
      `Pre {| secret one line
 comments until end of file|};
    ]
  in
  let info = Cmd.info "passage" ~version:"%%VERSION%%" ~envs ~doc ~man in
  let commands =
    [
      Add_who.add_who;
      Create.create;
      Get.cat_cmd;
      Rm.delete;
      Edit_cmd.edit;
      Edit_comments.edit_comments_cmd;
      Edit_who.edit_who;
      Get.get;
      Healthcheck.healthcheck;
      Init.init;
      List_.list;
      List_.ls;
      My.my;
      New.new_;
      Realpath.realpath;
      Refresh.refresh;
      Replace.replace;
      Replace_comments.replace_comments;
      Rm.rm;
      Rm_who.rm_who;
      Search.search;
      Get.secret;
      Show.show;
      Subst.subst;
      Template_cmd.template;
      Template_secrets.template_secrets;
      What.what;
      Who.who;
    ]
  in
  let group = Cmd.group info ~default:help commands in
  exit @@ Cmd.eval ~catch:true group
