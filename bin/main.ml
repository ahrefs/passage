open Passage
open Printf
open Cmdliner

module Exn = Devkit.Exn

type output_mode =
  | Clipboard
  | QrCode
  | Stdout

type verbosity =
  | Normal
  | Verbose

let verbosity = ref Normal
let eprintl = Lwt_io.eprintl
let eprintlf = Lwt_io.eprintlf

let verbose_eprintlf fmt =
  ksprintf
    (fun msg ->
      match !verbosity with
      | Verbose -> eprintl msg
      | Normal -> Lwt.return_unit)
    fmt

let show_path p = Path.project p
let show_name name = Storage.Secret_name.project name
let path_of_secret_name name = show_name name |> Path.inject
let secret_name_of_path path = show_path path |> Storage.Secrets.build_secret_name

let main_run term = Term.(const Lwt_main.run $ term)

module Prompt = struct
  type prompt_reply =
    | NoTTY
    | TTY of bool

  let is_TTY = Unix.isatty Unix.stdin

  let yesno prompt =
    let%lwt () = Lwt_io.printf "%s [y/N] " prompt in
    let%lwt ans = Lwt_io.(read_line stdin) in
    match ans with
    | "Y" | "y" -> Lwt.return true
    | _ -> Lwt.return false

  let yesno_tty_check prompt =
    match is_TTY with
    | false -> Lwt.return NoTTY
    | true ->
      let%lwt () = Lwt_io.printf "%s [y/N] " prompt in
      let%lwt ans = Lwt_io.(read_line stdin) in
      (match ans with
      | "Y" | "y" -> Lwt.return (TTY true)
      | _ -> Lwt.return (TTY false))

  let input_help_if_user_input () =
    match is_TTY with
    | true -> Lwt_io.printl "I: reading from stdin. Please type the secret and then do Ctrl+d twice to terminate input"
    | false -> Lwt.return_unit

  let read_input_from_stdin ?initial:_ () = Lwt_io.(read stdin)

  let rec input_and_validate_loop ?(transform = fun x -> x) ?initial get_secret_input =
    let remove_trailing_newlines s =
      (* reverse the string and count leading newlines instead of traversing the string
         multiple times to remove trailing newlines *)
      let rev_s =
        let chars = List.of_seq (String.to_seq s) in
        String.of_seq (List.to_seq (List.rev chars))
      in
      let rec count_leading_newlines ?(acc = 0) ?(i = 0) s =
        try
          match s.[i] = '\n' with
          | true -> count_leading_newlines ~acc:(acc + 1) ~i:(i + 1) s
          | false -> i
        with _ -> (* out of bounds edge case *) i - 1
      in
      let trailing_newlines = count_leading_newlines rev_s in
      String.sub s 0 (String.length s - trailing_newlines)
    in
    let%lwt input = get_secret_input ?initial () in
    let input = transform input in
    (* Remove bash commented lines from the secret and any trailing newlines *)
    let secret =
      String.split_on_char '\n' input
      |> List.filter (fun line -> not (String.starts_with ~prefix:"#" line))
      |> String.concat "\n"
      |> remove_trailing_newlines
    in
    match Secret.Validation.validate secret with
    | Error (e, _typ) ->
      if is_TTY = false then Shell.die "This secret is in an invalid format: %s" e
      else (
        let%lwt () = Lwt_io.printlf "\nThis secret is in an invalid format: %s" e in
        if%lwt yesno "Edit again?" then input_and_validate_loop ~initial:input get_secret_input else Lwt.return_error e)
    | _ -> Lwt.return_ok secret

  (** Gets and validates user input reading from stdin. If the input has the wrong format, the user
      is prompted to reinput the secret with the correct format. Allows passing in a function for input
      transformation. Throws an error if the transformed input doesn't comply with the format and the
      user doesn't want to fix the input format. *)
  let get_valid_input_from_stdin_exn ?transform () =
    match%lwt input_and_validate_loop ?transform read_input_from_stdin with
    | Error e -> Shell.die "This secret is in an invalid format: %s" e
    | Ok secret -> Lwt.return_ok secret
end

module Encrypt = struct
  let encrypt_exn ~plaintext ~secret_name recipients =
    let%lwt () =
      verbose_eprintlf "I: encrypting %s for %s" (show_name secret_name)
        (List.map (fun r -> Age.(r.name)) recipients |> String.concat ", ")
    in
    Storage.Secrets.encrypt_exn ~plaintext ~secret_name recipients
end

module Edit = struct
  let add_recipients_if_none_exists recipients secret_path =
    match Storage.Secrets.no_keys_file (Path.dirname secret_path) with
    | false -> Lwt.return_unit
    | true ->
      (* also adds root group by default for all new secrets *)
      let root_recipients_names = Storage.Secrets.recipients_of_group_name ~map_fn:(fun x -> x) "@root" in
      (* just a separator line before printing the added recipients *)
      let%lwt () = eprintl "" in
      let%lwt () = eprintlf "I: using recipient group @root for secret %s" (show_path secret_path) in
      (* avoid repeating names if the user creating the secret is already in the root group *)
      let%lwt recipients_names =
        Lwt_list.filter_map_s
          (fun r ->
            match List.mem r.Age.name root_recipients_names with
            | true -> Lwt.return_none
            | false ->
              let%lwt () = Lwt_io.eprintf "I: using recipient %s for secret %s\n" r.name (show_path secret_path) in
              Lwt.return_some r.name)
          recipients
      in
      let%lwt () = Lwt_io.(flush stderr) in
      let recipients_names_with_root_group = "@root" :: (recipients_names |> List.sort String.compare) in
      let recipients_file_path = Storage.Secrets.get_recipients_file_path secret_path in
      let (_ : Path.t) = Path.ensure_parent recipients_file_path in
      Lwt_io.lines_to_file (show_path recipients_file_path) (recipients_names_with_root_group |> Lwt_stream.of_list)

  let encrypt_with_retry ~plaintext ~secret_name recipients =
    let rec loop () =
      try%lwt Encrypt.encrypt_exn ~plaintext ~secret_name recipients
      with exn ->
        let%lwt () = eprintlf "Encryption failed: %s" (Exn.to_string exn) in
        let%lwt () = Lwt_io.(flush stderr) in
        (match%lwt Prompt.yesno "Would you like to try again?" with
        | false -> Shell.die "E: retry cancelled"
        | true -> loop ())
    in
    loop ()

  let new_secret_recipients_notice =
    {|
If you are adding a new secret in a new folder, please keep recipients to a minimum and include the following:
- @root
- yourself
- people who help manage the secret, or people who would have access to it anyway
- people who need access to do their job
- servers/clusters that will consume the secret

If the secret is a staging secret, its only recipient should be @everyone.
|}

  let show_recipients_notice_if_true cond = if cond then prerr_endline new_secret_recipients_notice

  let edit_secret ?(self_fallback = false) secret_name ~allow_retry ~get_updated_secret =
    let raw_secret_name = show_name secret_name in
    let%lwt original_secret =
      match Storage.Secrets.secret_exists secret_name with
      | false -> Lwt.return None
      | true ->
        (try%lwt Lwt.map Devkit.some @@ Storage.Secrets.decrypt_exn secret_name
         with exn -> Shell.die ~exn "E: failed to decrypt %s" raw_secret_name)
    in
    try%lwt
      let%lwt updated_secret = get_updated_secret original_secret in
      match updated_secret, original_secret with
      | Ok updated_secret, Some original_secret when updated_secret = original_secret -> Exn.fail "I: secret unchanged"
      | Error e, _ -> Shell.die "E: %s" e
      | Ok updated_secret, _ ->
        let secret_path = path_of_secret_name secret_name in
        let secret_recipients' = Storage.Secrets.get_recipients_from_path_exn secret_path in
        let%lwt secret_recipients =
          if secret_recipients' = [] && self_fallback then (
            let%lwt own_recipients = Storage.Secrets.recipients_of_own_id () in
            let%lwt () = add_recipients_if_none_exists own_recipients secret_path in
            Lwt.return @@ Storage.Secrets.get_recipients_from_path_exn secret_path)
          else Lwt.return secret_recipients'
        in
        if secret_recipients = [] then Exn.fail "E: no recipients specified for this secret"
        else (
          let is_first_secret_in_new_folder = Option.is_none original_secret && secret_recipients' = [] in
          match allow_retry with
          | true ->
            show_recipients_notice_if_true is_first_secret_in_new_folder;
            encrypt_with_retry ~plaintext:updated_secret ~secret_name secret_recipients
          | false ->
            (try%lwt
               show_recipients_notice_if_true is_first_secret_in_new_folder;
               Encrypt.encrypt_exn ~plaintext:updated_secret ~secret_name secret_recipients
             with exn -> Exn.fail ~exn "E: encrypting %s failed" raw_secret_name))
    with Failure s -> Shell.die "%s" s

  (** takes two sorted lists and returns three lists:
      first is items unique to l1, second is items unique to l2, third is items in both l1 and l2.

      Preserves the order in the outputs *)
  let diff_intersect_lists l1 r1 =
    let rec diff accl accr accb left right =
      match left, right with
      | [], [] -> List.rev accl, List.rev accr, List.rev accb
      | [], rh :: rt -> diff accl (rh :: accr) accb [] rt
      | lh :: lt, [] -> diff (lh :: accl) accr accb lt []
      | lh :: lt, rh :: rt ->
        let comp = compare lh rh in
        if comp < 0 then diff (lh :: accl) accr accb lt right
        else if comp > 0 then diff accl (rh :: accr) accb left rt
        else diff accl accr (lh :: accb) lt rt
    in
    diff [] [] [] l1 r1

  let shm_check =
    lazy
      (let shm_dir = Path.inject "/dev/shm" in
       let has_sufficient_perms =
         try
           Path.access shm_dir [ F_OK; W_OK; X_OK ];
           true
         with Unix.Unix_error _ -> false
       in
       let%lwt parent =
         match Path.is_directory shm_dir && has_sufficient_perms with
         | true -> Lwt.return_some shm_dir
         | false ->
           (match%lwt
              Prompt.yesno
                {|Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?|}
            with
           | false -> exit 1
           | true -> Lwt.return_none)
       in
       Lwt.return parent)

  let with_secure_tmpfile suffix f =
    let program = Filename.basename Sys.executable_name in
    let%lwt parent = Lazy.force shm_check in
    Lwt_io.with_temp_dir ~perm:0o700 ?parent:(Option.map show_path parent) ~prefix:(sprintf "%s." program)
      (fun secure_tmpdir ->
        let suffix = sprintf "-%s.txt" (Devkit.Stre.replace_all ~str:suffix ~sub:"/" ~by:"-") in
        Lwt_io.with_temp_file ~temp_dir:secure_tmpdir ~suffix ~perm:0o600 f)

  (* make sure they really meant to exit without saving. But this is going to mess
   * up if an editor never cleanly exits. *)
  let rec edit_loop tmpfile =
    let%lwt had_exception = try%lwt Lwt.map (fun () -> false) (Shell.editor tmpfile) with _ -> Lwt.return true in
    if had_exception then (
      match%lwt Prompt.yesno "Editor was exited without saving successfully, try again?" with
      | true -> edit_loop tmpfile
      | false -> Lwt.return false)
    else Lwt.return true

  let edit_recipients secret_name =
    let path_to_secret = path_of_secret_name secret_name in
    let secret_recipients_file = Storage.Secrets.get_recipients_file_path path_to_secret in
    let sorted_base_recipients =
      try Storage.Secrets.get_recipients_names path_to_secret with exn -> Shell.die ~exn "E: failed to get recipients"
    in
    let recipients_groups, current_recipients_names = sorted_base_recipients |> List.partition Age.is_group_recipient in
    let left, right, common = diff_intersect_lists current_recipients_names (Storage.Keys.all_recipient_names ()) in
    let recipient_lines =
      (if recipients_groups = [] then [] else ("# Groups " :: recipients_groups) @ [ "" ])
      @ ("# Recipients " :: common)
      @ [ "" ]
      @ (if left = [] then [] else "#" :: "# Warning, unknown recipients below this line " :: "#" :: left)
      @ "#"
        :: "# Uncomment recipients below to add them. You can also add valid groups names if you want."
        :: "#"
        :: List.map (fun r -> "# " ^ r) right
    in
    with_secure_tmpfile (show_name secret_name) (fun (tmpfile, tmpfile_oc) ->
        (* write and then close to make it available to the editor *)
        let%lwt () = Lwt_list.iter_s (Lwt_io.write_line tmpfile_oc) recipient_lines in
        let%lwt () = Lwt_io.close tmpfile_oc in
        if%lwt edit_loop tmpfile then (
          let keys_list = Storage.Keys.get_keys (Path.inject tmpfile) |> List.sort Age.Key.compare in
          let (_ : Path.t) = Path.ensure_parent secret_recipients_file in
          let%lwt () =
            Lwt_io.lines_to_file (show_path secret_recipients_file)
              (Lwt_stream.of_list keys_list |> Lwt_stream.map Age.Key.project)
          in
          let sorted_updated_recipients_names = Storage.Secrets.get_recipients_names path_to_secret in
          if sorted_base_recipients <> sorted_updated_recipients_names then (
            let secrets_affected =
              Storage.Secrets.get_secrets_in_folder (path_of_secret_name secret_name |> Path.folder_of_path)
            in
            (* it might be that we are creating a secret in a new folder and adding new recipients,
               so we have no extra affected secrets. Only refresh if there are affected secrets *)
            if secrets_affected <> [] then
              Storage.Secrets.refresh ~force:true ~verbose:(!verbosity = Verbose) secrets_affected
            else Lwt.return_unit)
          else eprintl "I: no changes made to the recipients")
        else verbose_eprintlf "E: no recipients provided")

  let new_text_from_editor ?(initial = "") ?(name = "new") () =
    with_secure_tmpfile name (fun (tmpfile, tmpfile_oc) ->
        let%lwt () =
          if initial <> "" then (
            let%lwt () = Lwt_io.write tmpfile_oc initial in
            Lwt_io.close tmpfile_oc)
          else Lwt.return_unit
        in
        let%lwt () = Shell.editor tmpfile in
        Lwt_io.(with_file ~mode:Input tmpfile read))
end

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
      try Ok (Re2.create_exn pattern) with Re2.Exceptions.Regex_compile_failed s -> Error (`Msg s)
    in
    let print ppf pattern = Format.fprintf ppf "%s" (Re2.to_string pattern) in
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

  let set_verbosity =
    let doc = "print verbose output during execution" in
    let verbose = Verbose, Arg.info [ "v"; "verbose" ] ~doc in
    let verbosity_term = Arg.(value & vflag Normal [ verbose ]) in
    Term.(const (fun v -> verbosity := v) $ verbosity_term)

  let template_file =
    let doc = "the path of the template file" in
    Arg.(required & pos 0 (some Converters.file_arg) None & info [] ~doc ~docv:"TEMPLATE_FILE")
end

module Create = struct
  let invariant_create ~create_new_secret secret_name =
    if Storage.Secrets.secret_exists secret_name then
      Shell.die "E: refusing to create: a secret by that name already exists"
    else (
      let%lwt () = Invariant.die_if_invariant_fails ~op_string:"create" (path_of_secret_name secret_name) in
      create_new_secret secret_name)

  let create_new_secret_from_stdin secret_name =
    let create_new_secret secret_name =
      Edit.edit_secret secret_name ~self_fallback:true ~allow_retry:false ~get_updated_secret:(fun _ ->
          let open Prompt in
          let%lwt () = input_help_if_user_input () in
          get_valid_input_from_stdin_exn ())
    in
    invariant_create ~create_new_secret secret_name

  let create =
    let doc =
      {| creates a new secret from stdin. If the folder doesn't have recipients specified already,
      tries to set them to the ones associated with \${PASSAGE_IDENTITY} |}
    in
    let info = Cmd.info "create" ~doc in
    let term = main_run Term.(const create_new_secret_from_stdin $ Flags.secret_name) in
    Cmd.v info term
end

module Edit_cmd = struct
  let edit secret_name =
    match Storage.Secrets.secret_exists secret_name with
    | false -> Shell.die "E: no such secret: %s.  Use \"new\" or \"create\" for new secrets." (show_name secret_name)
    | true ->
      Invariant.run_if_recipient ~op_string:"edit secret" ~path:(path_of_secret_name secret_name) ~f:(fun () ->
          Edit.edit_secret secret_name ~allow_retry:true ~get_updated_secret:(fun initial ->
              Prompt.input_and_validate_loop
              (* when we are editing a secret, we know `initial` is Some and we add the format explainer to it *)
                ?initial:(Option.map (fun i -> i ^ Secret.format_explainer) initial)
                (Edit.new_text_from_editor ~name:(show_name secret_name))))

  let edit =
    let doc = "edit the contents of the specified secret" in
    let info = Cmd.info "edit" ~doc in
    let term = main_run Term.(const edit $ Flags.secret_name) in
    Cmd.v info term
end

module Edit_who = struct
  let edit_who_with_check secret_name =
    let secret_path = path_of_secret_name secret_name in
    match Path.is_directory (Path.abs secret_path), Storage.Secrets.secret_exists_at secret_path with
    | false, false -> Shell.die "E: no such secret: %s" (show_name secret_name)
    | _, true | true, _ ->
      Invariant.run_if_recipient ~op_string:"edit recipients" ~path:(path_of_secret_name secret_name) ~f:(fun () ->
          Edit.edit_recipients secret_name)

  let edit_who =
    let doc =
      "edit the recipients of the specified path.  Note that recipients are not inherited from folders higher up\n\
      \  in the tree, so all recipients need to be specified at the level of the immediately containing folder."
    in
    let info = Cmd.info "edit-who" ~doc in
    let term = main_run Term.(const edit_who_with_check $ Flags.secret_name) in
    Cmd.v info term
end

module Get = struct
  module Output = struct
    let print_as_qrcode ~secret_name ~secret =
      match Qrc.encode secret with
      | None -> Shell.die "Failed to encode %s as QR code. Data capacity exceeded!" (show_name secret_name)
      | Some m -> Qrc_fmt.pp_utf_8_half ~invert:true Format.std_formatter m

    let save_to_clipboard_exn ~secret =
      let read_clipboard () = Shell.xclip_read_clipboard Config.x_selection in
      let copy_to_clipboard s =
        try%lwt Shell.xclip_copy_to_clipboard s ~x_selection:Config.x_selection
        with exn -> Exn.fail ~exn "E: could not copy data to the clipboard"
      in
      let restore_clipboard original_content =
        let%lwt () = Lwt_unix.sleep (float_of_int Config.clip_time) in
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
      let%lwt original_content = read_clipboard () in
      let%lwt () = copy_to_clipboard secret in
      (* flush before forking to avoid double-flush *)
      let%lwt () = Lwt_io.flush_all () in
      match Devkit.Nix.fork () with
      | `Child ->
        let (_ : int) = Unix.setsid () in
        let%lwt () = restore_clipboard original_content in
        Lwt.return `Child
      | `Forked _ as forked -> Lwt.return forked
    let save_to_clipboard ~secret_name ~secret =
      try%lwt
        match%lwt save_to_clipboard_exn ~secret with
        | `Child -> Lwt.return_unit
        | `Forked _ ->
          eprintlf "Copied %s to clipboard. Will clear in %d seconds." (show_name secret_name) Config.clip_time
      with exn -> Shell.die ~exn "E: failed to save to clipboard! Check if you have an X server running."
  end

  let get_secret ?expected_kind ?line_number ~with_comments ?(trim_new_line = false) secret_name output_mode =
    match Storage.Secrets.secret_exists secret_name with
    | false ->
      if Path.is_directory Storage.Secrets.(to_path secret_name |> Path.abs) then
        Shell.die "E: %s is a directory" (show_name secret_name)
      else Shell.die "E: no such secret: %s" (show_name secret_name)
    | true ->
      let get_line_exn secret line_number =
        if line_number < 1 then Shell.die "Line number should be greater than 0";
        let lines = String.split_on_char '\n' secret in
        (* user specified line number is 1-indexed *)
        match List.nth_opt lines (line_number - 1) with
        | None -> Shell.die "There is no secret at line %d" line_number
        | Some l -> l
      in
      let%lwt plaintext =
        try%lwt Storage.Secrets.decrypt_exn secret_name
        with exn -> Shell.die ~exn "E: failed to decrypt %s" (show_name secret_name)
      in
      let secret =
        match with_comments, line_number with
        | true, None -> plaintext
        | true, Some ln -> get_line_exn plaintext ln
        | false, _ ->
          let secret =
            try Secret.Validation.parse_exn plaintext
            with exn -> Shell.die ~exn "E: failed to parse %s" (show_name secret_name)
          in
          let kind = secret.kind in
          (* we can have this validation only here because we don't have expected kinds when using the cat command
              (the with_comments = true branch) *)
          (match Option.is_some expected_kind && Option.get expected_kind <> kind with
          | true ->
            Shell.die "E: %s is expected to be a %s secret but it is a %s secret" (show_name secret_name)
              (Secret.kind_to_string @@ Option.get expected_kind)
              (Secret.kind_to_string kind)
          | false -> ());
          (match line_number with
          | None -> secret.text
          | Some ln -> get_line_exn secret.text ln)
      in
      let secret =
        match trim_new_line, String.ends_with ~suffix:"\n" secret with
        (* some of the older secrets were not trimmed before storing, so they have trailing new lines *)
        | true, true -> String.sub secret 0 (String.length secret - 1)
        | false, false -> sprintf "%s\n" secret
        | true, false | false, true -> secret
      in
      (match output_mode with
      | QrCode ->
        Output.print_as_qrcode ~secret_name ~secret;
        Lwt.return_unit
      | Clipboard -> Output.save_to_clipboard ~secret_name ~secret
      | Stdout -> Lwt_io.print secret)

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
    main_run
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
    let term = main_run Term.(const cat $ Flags.secret_name $ Flags.secret_output_mode $ Flags.secret_line_number) in
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

  let check_folders_without_keys_file () =
    let%lwt () =
      eprintl
        {|
PASSAGE HEALTHCHECK. Diagnose for common problems

==========================================================================
Checking for folders without .keys file
==========================================================================|}
    in
    let folders_without_keys_file = Storage.Secrets.(all_paths () |> List.filter has_secret_no_keys) in
    match folders_without_keys_file with
    | [] -> eprintl "\nSUCCESS: secrets all have .keys in the immediate directory"
    | _ ->
      let%lwt () = Lwt_io.printl "\nERROR: found paths with secrets but no .keys file:" in
      let%lwt () = Lwt_list.iter_s (fun p -> Lwt_io.printlf "- %s" (show_path p)) folders_without_keys_file in
      let%lwt () = Lwt_io.(flush stderr) in
      healthcheck_with_errors := true;
      Lwt.return_unit

  let check_own_secrets_validity upgrade_mode =
    let open Storage in
    let%lwt () =
      eprintl
        {|
==========================================================================
Checking for validity of own secrets. Use -v flag to break down per secret
==========================================================================
|}
    in
    let%lwt recipients_of_own_id = Secrets.recipients_of_own_id () in
    Lwt_list.iter_s
      (fun (recipient : Age.recipient) ->
        match Secrets.get_secrets_for_recipient recipient.name with
        | [] -> Lwt_io.eprintlf "No secrets found for %s" recipient.name
        | secrets ->
          let sorted_secrets = List.sort Secret_name.compare secrets in
          let%lwt ok, invalid, fail =
            Lwt_list.fold_left_s
              (fun (ok, invalid, fail) secret_name ->
                try%lwt
                  let%lwt secret_text = Secrets.decrypt_exn ~silence_stderr:true secret_name in
                  match Secret.Validation.validate secret_text with
                  | Ok kind ->
                    let%lwt () =
                      verbose_eprintlf "✅ %s [ valid %s ]" (show_name secret_name) (Secret.kind_to_string kind)
                    in
                    Lwt.return (succ ok, invalid, fail)
                  | Error (e, validation_error_type) ->
                    healthcheck_with_errors := true;
                    let%lwt () = Lwt_io.printlf "❌ %s [ invalid format: %s ]" (show_name secret_name) e in
                    let%lwt upgraded_secrets =
                      match upgrade_mode, validation_error_type with
                      | Upgrade, SingleLineLegacy ->
                        (try%lwt
                           let { Secret.text; comments; _ } = Secret.Validation.parse_exn secret_text in
                           let upgraded_secret =
                             Secret.singleline_from_text_description text (Option.value ~default:"" comments)
                           in
                           let recipients =
                             Storage.Secrets.get_recipients_from_path_exn (path_of_secret_name secret_name)
                           in
                           let%lwt () = Encrypt.encrypt_exn ~plaintext:upgraded_secret ~secret_name recipients in
                           let%lwt () = eprintlf "I: updated %s" (show_name secret_name) in
                           Lwt.return 1
                         with exn ->
                           let%lwt () =
                             Lwt_io.eprintlf "E: encrypting %s failed: %s" (show_name secret_name)
                               (Printexc.to_string exn)
                           in
                           Lwt.return 0)
                      | DryRun, SingleLineLegacy ->
                        let%lwt () = eprintlf "I: would update %s" (show_name secret_name) in
                        Lwt.return 1
                      | NoUpgrade, _ | Upgrade, _ | DryRun, _ -> Lwt.return 0
                    in
                    Lwt.return (ok + upgraded_secrets, succ (invalid - upgraded_secrets), fail)
                with _ ->
                  let%lwt () = Lwt_io.printlf "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret_name) in
                  Lwt.return (ok, invalid, succ fail))
              (0, 0, 0) sorted_secrets
          in
          let%lwt () =
            Lwt_io.eprintlf "\nI: %i valid secrets, %i invalid and %i with decryption issues" ok invalid fail
          in
          Lwt.return_unit)
      recipients_of_own_id

  let healthcheck upgrade_mode =
    let%lwt () = check_folders_without_keys_file () in
    let%lwt () = check_own_secrets_validity upgrade_mode in
    match !healthcheck_with_errors with
    | true -> exit 1
    | false -> exit 0

  let healthcheck =
    let doc = "check for issues with secrets, find directories that don't have keys, etc." in
    let info = Cmd.info "healthcheck" ~doc in
    let term = main_run Term.(const (fun () -> healthcheck) $ Flags.set_verbosity $ secrets_upgrade_mode) in
    Cmd.v info term
end

module Init = struct
  let init () =
    try%lwt
      (* create private and pub key, ask for user's name *)
      let%lwt () =
        Lwt_io.printl
          {|
Welcome to passage initial setup.

Passage will now create the default dirs for secrets and recipients keys.
A recipient identity will also be added, as well as an empty group file for root users.

The layout will be:
~/.config/passage
├── identity.key
├── keys
│   └── root.group
│   └── <user_name>.pub
└── secrets

The location of these can be overriden using environment variables. Please check `passage --help` for details.

What should be the name used for your recipient identity?|}
      in
      let%lwt user_name = Prompt.read_input_from_stdin () in
      let user_name =
        String.trim user_name
        |> ExtString.String.replace_chars (fun c ->
               match c with
               | ' ' -> "_"
               | '\n' -> ""
               | c -> Char.escaped c)
      in
      let%lwt () = Shell.age_generate_identity_key_root_group_exn user_name in
      Lwt_io.printlf "\nPassage setup completed. "
    with exn ->
      (* Error out and delete everything, so we can start fresh next time *)
      FileUtil.rm ~recurse:true [ Config.base_dir ];
      Lwt_io.printlf "E: Passage init failed. Please try again. Error:\n\n%s" (Printexc.to_string exn)

  let init =
    let doc = "initial setup of passage" in
    let info = Cmd.info "init" ~doc in
    let term = main_run Term.(const init $ const ()) in
    Cmd.v info term
end
module List_ = struct
  let list_secrets path =
    let raw_path = show_path path in
    match Storage.Secrets.secret_exists_at path with
    | true -> Lwt_io.printl Storage.Secrets.(name_of_file (Path.abs path) |> show_name)
    | false ->
    match Path.is_directory (Path.abs path) with
    | true ->
      Storage.(Secrets.get_secrets_tree path |> List.sort Secret_name.compare)
      |> Lwt_list.iter_s (fun s -> Lwt_io.printl @@ show_name s)
    | false -> Shell.die "No secrets at %s" raw_path

  let list =
    let doc = "recursively list all secrets" in
    let info = Cmd.info "list" ~doc in
    let term = main_run Term.(const list_secrets $ Flags.secrets_path) in
    Cmd.v info term

  let ls =
    let doc = "an alias for the list command" in
    let info = Cmd.info "ls" ~doc in
    let term = main_run Term.(const list_secrets $ Flags.secrets_path) in
    Cmd.v info term
end

module New = struct
  let create_new_secret secret_name =
    let%lwt () =
      Edit.edit_secret ~self_fallback:true secret_name ~allow_retry:true ~get_updated_secret:(fun initial ->
          Prompt.input_and_validate_loop
            ~initial:(Option.value ~default:Secret.format_explainer initial)
            (Edit.new_text_from_editor ~name:(show_name secret_name)))
    in
    let secret_path = path_of_secret_name secret_name in
    let original_recipients = Storage.Secrets.get_recipients_from_path_exn secret_path in
    Edit.show_recipients_notice_if_true (original_recipients = []);
    if%lwt Prompt.yesno "Edit recipients for this secret?" then Edit.edit_recipients secret_name

  let create_new_secret' secret_name = Create.invariant_create ~create_new_secret secret_name

  let new_ =
    let doc = "interactive creation of a new single-line secret" in
    let info = Cmd.info "new" ~doc in
    let term = main_run Term.(const create_new_secret' $ Flags.secret_name) in
    Cmd.v info term
end

module Realpath = struct
  let realpath paths =
    paths
    |> Lwt_list.iter_s (fun path ->
           let abs_path = Path.abs path in
           if Storage.Secrets.secret_exists_at path then (
             let secret_name = secret_name_of_path path in
             Lwt_io.printl (show_path (Path.abs (Storage.Secrets.agefile_of_name secret_name))))
           else if Path.is_directory abs_path then (
             let str = show_path abs_path in
             if Path.is_dot (Path.build_rel_path (show_path path)) then
               Lwt_io.printl (Lazy.force Storage.Secrets.base_dir ^ "/")
             else Lwt_io.printl (str ^ if String.ends_with ~suffix:"/" str then "" else "/"))
           else Lwt_io.eprintf "W: real path of secret/folder %S not found\n" (show_path path))

  let realpath =
    let doc =
      "show the full filesystem path to secrets/folders.  Note it will only list existing files or directories."
    in
    let info = Cmd.info "realpath" ~doc in
    let term = main_run Term.(const (fun () -> realpath) $ Flags.set_verbosity $ Flags.secrets_paths) in
    Cmd.v info term
end

module Refresh = struct
  let refresh_secrets paths =
    let secrets =
      List.fold_left
        (fun acc path ->
          (match Storage.Secrets.get_secrets_tree path with
          | _ :: _ as secrets -> secrets
          | [] ->
          match Storage.Secrets.secret_exists_at path with
          | true -> [ secret_name_of_path path ]
          | false -> Shell.die "E: no secrets at %s" (show_path path))
          @ acc)
        [] paths
    in
    let secrets = List.sort_uniq Storage.Secret_name.compare secrets in
    Storage.Secrets.refresh ~verbose:(!verbosity = Verbose) secrets

  let refresh =
    let doc = "re-encrypt secrets in the specified path(s)" in
    let info = Cmd.info "refresh" ~doc in
    let term = main_run Term.(const (fun () -> refresh_secrets) $ Flags.set_verbosity $ Flags.secrets_paths) in
    Cmd.v info term
end

module Replace = struct
  let replace_secret secret_name =
    let recipients = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name) in
    match recipients with
    | [] ->
      Shell.die
        {|E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)|}
        (show_name secret_name)
    | _ ->
      Invariant.run_if_recipient ~op_string:"replace secret" ~path:(path_of_secret_name secret_name) ~f:(fun () ->
          let%lwt () = Prompt.input_help_if_user_input () in
          (* We don't need to run validation for the input here since we will be replacing only the secret
              and not the whole file *)
          let%lwt new_secret_plaintext = Prompt.read_input_from_stdin () in
          if new_secret_plaintext = "" then Shell.die "E: invalid input, empty secrets are not allowed.";
          let is_singleline_secret =
            (* New secret is single line if doesn't have a newline character or if it has only one,
                at the end of the first line. This input isn't supposed to follow the storage format,
               it only contains a secret and no comments *)
            match String.split_on_char '\n' new_secret_plaintext with
            | [ _ ] | [ _; "" ] -> true
            | _ -> false
          in
          let%lwt updated_secret =
            match Storage.Secrets.secret_exists secret_name with
            | false ->
              (* if the secret doesn't exist yet, create a new secret with the right format *)
              Lwt.return
                (match is_singleline_secret with
                | true -> new_secret_plaintext
                | false -> "\n\n" ^ new_secret_plaintext)
            | true ->
              (* if there is already a secret, recreate or replace it *)
              let%lwt original_secret' =
                (* Get the original secret if we are in the recipient list, otherwise fully replace it *)
                try%lwt Storage.Secrets.decrypt_exn ~silence_stderr:true secret_name with _ -> Lwt.return ""
              in
              let original_secret =
                try Ok (Secret.Validation.parse_exn original_secret')
                with _e -> Error "failed to parse original secret"
              in
              let extract_comments ~f ~default secret =
                Result.map (fun ({ comments; _ } : Secret.t) -> Option.map f comments |> Option.value ~default) secret
                |> Result.value ~default
              in
              (* if the input doesn't have a newline char at the end we need to add one *)
              let new_secret_plaintext =
                match String.ends_with ~suffix:"\n" new_secret_plaintext with
                | true -> new_secret_plaintext
                | false -> new_secret_plaintext ^ "\n"
              in
              Lwt.return
                (match is_singleline_secret with
                | true ->
                  new_secret_plaintext
                  ^ extract_comments ~f:(fun comments -> "\n" ^ comments) ~default:"" original_secret
                | false ->
                  (* add an empty line before comments and before the secret,
                     or just an empty line if there are no comments *)
                  extract_comments ~f:(fun comments -> "\n" ^ comments ^ "\n") ~default:"\n" original_secret
                  ^ "\n"
                  ^ new_secret_plaintext)
          in
          try%lwt Encrypt.encrypt_exn ~plaintext:updated_secret ~secret_name recipients
          with exn -> Shell.die ~exn "E: encrypting %s failed" (show_name secret_name))

  let replace =
    let doc =
      "replaces the contents of the specified secret, keeping the comments. If the secret doesn't exist, it gets \
       created as a single or multi-line secret WITHOUT any comments"
    in
    let info = Cmd.info "replace" ~doc in
    let term = main_run Term.(const replace_secret $ Flags.secret_name) in
    Cmd.v info term
end

module Rm = struct
  let force =
    let doc = "Delete secrets and folders without asking for confirmation" in
    Arg.(value & flag & info [ "f"; "force" ] ~doc)

  let rm_secrets paths force =
    Lwt_list.iter_s
      (fun path ->
        let is_directory = Path.is_directory (Path.abs path) in
        match Storage.Secrets.secret_exists_at path, is_directory with
        | false, false -> Shell.die "E: no secrets exist at %s" (show_path path)
        | _ ->
          let string_path = show_path path in
          let%lwt rm_result =
            if force then Storage.Secrets.rm ~is_directory path
            else (
              match%lwt Prompt.yesno_tty_check (sprintf "Are you sure you want to delete %s?" string_path) with
              | NoTTY | TTY true -> Storage.Secrets.rm ~is_directory path
              | TTY false -> Lwt.return Storage.Secrets.Skipped)
          in
          (match rm_result with
          | Storage.Secrets.Succeeded () -> verbose_eprintlf "I: removed %s" string_path
          | Skipped -> eprintlf "I: skipped deleting %s" string_path
          | Failed exn -> Shell.die "E: failed to delete %s : %s" string_path (Exn.to_string exn)))
      paths

  let rm =
    let doc = "remove a secret or a folder and its secrets" in
    let info = Cmd.info "rm" ~doc in
    let term = main_run Term.(const (fun () -> rm_secrets) $ Flags.set_verbosity $ Flags.secrets_paths $ force) in
    Cmd.v info term

  let delete =
    let doc = "same as the $(i,rm) cmd. Remove a secret or a folder and its secrets" in
    let info = Cmd.info "delete" ~doc in
    let term = main_run Term.(const (fun () -> rm_secrets) $ Flags.set_verbosity $ Flags.secrets_paths $ force) in
    Cmd.v info term
end

module Search = struct
  let search_secrets pattern path =
    let secrets = Storage.Secrets.get_secrets_tree path |> List.sort Storage.Secret_name.compare in
    let%lwt n_skipped, n_failed, n_matched, matched_secrets =
      Lwt_list.fold_left_s
        (fun (n_skipped, n_failed, n_matched, matched_secrets) secret ->
          match%lwt Storage.Secrets.search secret pattern with
          | Succeeded true -> Lwt.return (n_skipped, n_failed, n_matched + 1, secret :: matched_secrets)
          | Succeeded false -> Lwt.return (n_skipped, n_failed, n_matched, matched_secrets)
          | Skipped ->
            let%lwt () = verbose_eprintlf "I: skipped %s" (show_name secret) in
            Lwt.return (n_skipped + 1, n_failed, n_matched, matched_secrets)
          | Failed exn ->
            let%lwt () = eprintlf "W: failed to search %s : %s" (show_name secret) (Exn.to_string exn) in
            Lwt.return (n_skipped, n_failed + 1, n_matched, matched_secrets))
        (0, 0, 0, []) secrets
    in
    let%lwt () =
      Lwt_io.printlf "I: skipped %d secrets, failed to search %d secrets and matched %d secrets" n_skipped n_failed
        n_matched
    in
    List.rev matched_secrets |> Lwt_list.iter_s (fun s -> Lwt_io.printl (show_name s))

  let search =
    let pattern =
      let doc = "the pattern to match against" in
      Arg.(required & pos 0 (some Converters.pattern_arg) None & info [] ~docv:"PATTERN" ~doc)
    in
    let secrets_path =
      let doc = "the relative $(docv) from the secrets directory that will be searched" in
      Arg.(value & pos 1 Converters.path_arg (Path.inject ".") & info [] ~docv:"PATH" ~doc)
    in
    let term = main_run Term.(const (fun () -> search_secrets) $ Flags.set_verbosity $ pattern $ secrets_path) in
    let doc = "list secrets in the specified path, containing contents that match the specified pattern" in
    let info = Cmd.info "search" ~doc in
    Cmd.v info term
end

module Show = struct
  let list_secrets_tree path =
    let full_path = Path.abs path in
    match Path.is_directory full_path, Storage.Secrets.secret_exists_at path with
    | false, true -> Get.cat (secret_name_of_path path) Stdout None
    | false, false -> Shell.die "No secrets at this path : %s" (show_path full_path)
    | true, _ ->
      let%lwt tree = Dirtree.of_path (Path.to_fpath full_path) in
      Dirtree.pp tree

  let show =
    let doc =
      "recursively list all secrets in a tree-like format. If used on a single secret, it will work the same as the \
       cat command."
    in
    let info = Cmd.info "show" ~doc in
    let term = main_run Term.(const list_secrets_tree $ Flags.secrets_path) in
    Cmd.v info term
end

module Subst = struct
  let template =
    let doc = "a template on the commandline" in
    Arg.(required & pos 0 (some Converters.template_arg) None & info [] ~doc ~docv:"TEMPLATE_ARG")

  let substitute template =
    try%lwt Template.substitute ~template () with exn -> Shell.die ~exn "E: failed to substitute"

  let subst =
    let doc = "fill in values in the provided template" in
    let info = Cmd.info "subst" ~doc in
    let term = main_run Term.(const substitute $ template) in
    Cmd.v info term
end

module Template_cmd = struct
  let substitute_template template_file target_file =
    try%lwt Template.substitute_file ~template_file ~target_file
    with exn -> Shell.die ~exn "E: failed to substitute file"

  let target_file =
    let doc = "the target file for templating if present, otherwise output to standard output" in
    Arg.(value & pos 1 (some Converters.file_arg) None & info [] ~doc ~docv:"TARGET_FILE")

  let template =
    let doc = "outputs target file by substituting all secrets in the template file" in
    let info = Cmd.info "template" ~doc in
    let term = main_run Term.(const substitute_template $ Flags.template_file $ target_file) in
    Cmd.v info term
end

module Template_secrets = struct
  let list_template_secrets template_file =
    let tree = try Template.parse_file template_file with exn -> Shell.die ~exn "Failed to parse the file" in
    let idens =
      List.filter_map
        (fun node ->
          match node with
          | Template_ast.Text _ -> None
          | Template_ast.Iden secret_name -> Some secret_name)
        tree
      |> List.sort_uniq String.compare
    in
    List.iter print_endline idens

  let template_secrets =
    let doc = "sorted unique list of secret references found in a template. Secrets are not checked for existence" in
    let info = Cmd.info "template-secrets" ~doc in
    let term = Term.(const list_template_secrets $ Flags.template_file) in
    Cmd.v info term
end

module What = struct
  let recipient_name =
    let doc = "the names of the recipients. Can be one or many" in
    Arg.(value & pos_all string [] & info [] ~docv:"PATH" ~doc)

  let list_recipient_secrets recipients_names =
    if recipients_names = [] then Shell.die "E: Must specify at least one recipient name";
    let number_of_recipients = List.length recipients_names in
    let all_recipient_names = Storage.Keys.all_recipient_names () in
    Lwt_list.iter_s
      (fun recipient_name ->
        let open Storage in
        match List.mem recipient_name all_recipient_names, Age.is_group_recipient recipient_name with
        | false, false -> eprintlf "E: no such recipient %s" recipient_name
        | _ ->
        match Secrets.get_secrets_for_recipient recipient_name with
        | [] -> eprintlf "\nNo secrets found for %s" recipient_name
        | secrets ->
          let%lwt () =
            if number_of_recipients > 1 then eprintlf "\nSecrets which %s is a recipient of:" recipient_name
            else Lwt.return_unit
          in
          let sorted = List.sort Secret_name.compare secrets in
          let print_secret secret =
            match !verbosity with
            | Normal -> Lwt_io.printl (show_name secret)
            | Verbose ->
              (try%lwt
                 let%lwt plaintext = Storage.Secrets.decrypt_exn ~silence_stderr:true secret in
                 Lwt_io.printl @@ Secret.Validation.validity_to_string (show_name secret) plaintext
               with _ -> Lwt_io.printlf "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret))
          in
          let%lwt () = Lwt_list.iter_s print_secret sorted in
          Lwt_io.(flush stderr))
      recipients_names

  let what =
    let doc = "list secrets that a recipient has access to" in
    let info = Cmd.info "what" ~doc in
    let term = main_run Term.(const (fun () -> list_recipient_secrets) $ Flags.set_verbosity $ recipient_name) in
    Cmd.v info term
end

module Who = struct
  let expand_groups =
    let doc = "Expand groups of recipients in the output." in
    Arg.(value & flag & info [ "f"; "expand-groups" ] ~doc)

  let list_recipients path expand_groups =
    let string_path = show_path path in
    let print_from_recipient_list recipients =
      List.iter
        (fun (r : Age.recipient) ->
          (match r.keys with
          | [] -> Devkit.eprintfn "W: no keys found for %s" r.name
          | _ -> ());
          print_endline r.name)
        recipients
    in
    match Age.is_group_recipient string_path with
    | true ->
      Storage.Secrets.recipients_of_group_name ~map_fn:Storage.Secrets.recipient_of_name string_path
      |> print_from_recipient_list
    | false ->
    match Storage.Secrets.secret_exists_at path || Storage.Secrets.get_secrets_tree path <> [] with
    | false -> Shell.die "E: no such secret %s" (show_path path)
    | true ->
    match expand_groups with
    | true ->
      (match Storage.Secrets.get_recipients_from_path_exn path with
      | exception exn -> Shell.die ~exn "E: failed to get recipients"
      | [] -> Shell.die "E: no recipients found for %s" (show_path path)
      | recipients -> print_from_recipient_list recipients)
    | false ->
    match Storage.Secrets.get_recipients_names path with
    | [] -> Shell.die "E: no recipients found for %s" (show_path path)
    | recipients_names ->
      List.iter
        (fun recipient_name ->
          let recipient_keys =
            match Age.is_group_recipient recipient_name with
            | false -> Storage.Keys.keys_of_recipient recipient_name
            | true ->
            try
              (* we don't need the group recipients, just to know that there are some *)
              let (_ : Age.recipient list) =
                Storage.Secrets.recipients_of_group_name ~map_fn:Storage.Secrets.recipient_of_name recipient_name
              in
              [ Age.Key.inject "" ]
            with exn ->
              Devkit.printfn "E: couldn't retrieve recipients for group %s. Reason: %s" recipient_name
                (Printexc.to_string exn);
              []
          in
          (match recipient_keys with
          | [] -> Devkit.eprintfn "W: no keys found for %s" recipient_name
          | _ -> ());
          print_endline recipient_name)
        recipients_names

  let who =
    let doc = "list all recipients of secrets in the specified path" in
    let info = Cmd.info "who" ~doc in
    let term = Term.(const list_recipients $ Flags.secrets_path $ expand_groups) in
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
  let info = Cmd.info "passage" ~envs ~doc ~man in
  let commands =
    [
      Create.create;
      Get.cat_cmd;
      Rm.delete;
      Edit_cmd.edit;
      Edit_who.edit_who;
      Get.get;
      Healthcheck.healthcheck;
      Init.init;
      List_.list;
      List_.ls;
      New.new_;
      Realpath.realpath;
      Refresh.refresh;
      Replace.replace;
      Rm.rm;
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
