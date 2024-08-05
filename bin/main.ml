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
let eprintlf = Devkit.eprintfn

let verbose_eprintlf fmt =
  ksprintf
    (fun msg ->
      match !verbosity with
      | Verbose -> prerr_endline msg
      | Normal -> ())
    fmt

let show_path p = Path.project p
let show_name name = Storage.Secret_name.project name
let path_of_secret_name name = show_name name |> Path.inject
let secret_name_of_path path = show_path path |> Storage.Secrets.build_secret_name

module Prompt = struct
  type prompt_reply =
    | NoTTY
    | TTY of bool

  let is_TTY = Unix.isatty Unix.stdin

  let yesno prompt =
    printf "%s [y/N] " prompt;
    let ans = read_line () in
    match ans with
    | "Y" | "y" -> true
    | _ -> false

  let yesno_tty_check prompt =
    match is_TTY with
    | false -> NoTTY
    | true ->
      printf "%s [y/N] " prompt;
      let ans = read_line () in
      (match ans with
      | "Y" | "y" -> TTY true
      | _ -> TTY false)

  let input_help_if_user_input () =
    match is_TTY with
    | true -> print_endline "I: reading from stdin. Please type the secret and then do Ctrl+d twice to terminate input"
    | false -> ()

  let read_input_from_stdin () = In_channel.input_all stdin

  let rec input_and_validate_loop ?(transform = fun x -> x) get_secret_input =
    let input = get_secret_input () in
    let secret = transform input in
    match Secret.Validation.validate secret with
    | Error (e, _typ) ->
      if is_TTY = false then Shell.die "This secret is in an invalid format: %s" e
      else (
        printf "\nThis secret is in an invalid format: %s" e;
        if yesno "Edit again?" then input_and_validate_loop get_secret_input else Error e)
    | _ -> Ok secret

  (** Gets and validates user input reading from stdin. If the input has the wrong format, the user
      is prompted to reinput the secret with the correct format. Allows passing in a function for input
      transformation. Throws an error if the transformed input doesn't comply with the format and the
      user doesn't want to fix the input format. *)
  let get_valid_input_from_stdin_exn ?transform () =
    match input_and_validate_loop ?transform read_input_from_stdin with
    | Error e -> Shell.die "This secret is in an invalid format: %s" e
    | Ok secret -> secret
end

module Encrypt = struct
  let encrypt_exn ~plaintext ~secret_name recipients =
    verbose_eprintlf "I: encrypting %s for %s" (show_name secret_name)
      (List.map (fun r -> Age.(r.name)) recipients |> String.concat ", ");
    Storage.Secrets.encrypt_exn ~plaintext ~secret_name recipients
end

module Edit = struct
  let add_recipients_if_none_exists recipients secret_path =
    match Storage.Secrets.no_keys_file (Path.dirname secret_path) with
    | false -> ()
    | true ->
      (* also adds root group by default for all new secrets *)
      let root_recipients_names = Storage.Secrets.recipients_of_group_name ~map_fn:(fun x -> x) "@root" in
      (* just a separator line before printing the added recipients *)
      prerr_endline "";
      eprintlf "I: using recipient group @root for secret %s" (show_path secret_path);
      (* avoid repeating names if the user creating the secret is already in the root group *)
      let recipients_names =
        List.filter_map
          (fun r ->
            match List.mem r.Age.name root_recipients_names with
            | true -> None
            | false ->
              Devkit.eprintfn "I: using recipient %s for secret %s\n" r.name (show_path secret_path);
              Some r.name)
          recipients
      in
      let recipients_names_with_root_group = "@root" :: (recipients_names |> List.sort String.compare) in
      let recipients_file_path = Storage.Secrets.get_recipients_file_path secret_path in
      let (_ : Path.t) = Path.ensure_parent recipients_file_path in
      (* TODO check if this is correct *)
      let contents = String.concat "\n" recipients_names_with_root_group in
      Devkit.Files.save_as (show_path recipients_file_path) ~mode:0o600 (fun oc ->
          Out_channel.output_string oc contents)

  let encrypt_with_retry ~plaintext ~secret_name recipients =
    let rec loop () =
      try Encrypt.encrypt_exn ~plaintext ~secret_name recipients
      with exn ->
        eprintlf "Encryption failed: %s" (Exn.to_string exn);
        (match Prompt.yesno "Would you like to try again?" with
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
    let original_secret =
      match Storage.Secrets.secret_exists secret_name with
      | false -> None
      | true ->
      try Storage.Secrets.decrypt_exn secret_name |> Devkit.some
      with exn -> Shell.die ~exn "E: failed to decrypt %s" raw_secret_name
    in
    try
      let updated_secret = get_updated_secret original_secret in
      match updated_secret = Option.value original_secret ~default:"" || updated_secret = "" with
      | true -> Exn.fail "I: secret unchanged"
      | false ->
        let secret_path = path_of_secret_name secret_name in
        let secret_recipients' = Storage.Secrets.get_recipients_from_path_exn secret_path in
        let secret_recipients =
          if secret_recipients' = [] && self_fallback then (
            let own_recipients = Storage.Secrets.recipients_of_own_id () in
            let () = add_recipients_if_none_exists own_recipients secret_path in
            Storage.Secrets.get_recipients_from_path_exn secret_path)
          else secret_recipients'
        in
        if secret_recipients = [] then Exn.fail "E: no recipients specified for this secret"
        else (
          let is_first_secret_in_new_folder = Option.is_none original_secret && secret_recipients' = [] in
          match allow_retry with
          | true ->
            show_recipients_notice_if_true is_first_secret_in_new_folder;
            encrypt_with_retry ~plaintext:updated_secret ~secret_name secret_recipients
          | false ->
          try
            show_recipients_notice_if_true is_first_secret_in_new_folder;
            Encrypt.encrypt_exn ~plaintext:updated_secret ~secret_name secret_recipients
          with exn -> Exn.fail ~exn "E: encrypting %s failed" raw_secret_name)
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
       let parent =
         match Path.is_directory shm_dir && has_sufficient_perms with
         | true -> Some shm_dir
         | false ->
         match
           Prompt.yesno
             {|Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?|}
         with
         | false -> exit 1
         | true -> None
       in
       parent)

  let _with_secure_tmpfile suffix f =
    let program = Filename.basename Sys.executable_name in
    let parent = Lazy.force shm_check in
    Lwt_io.with_temp_dir ~perm:0o700 ?parent:(Option.map show_path parent) ~prefix:(sprintf "%s." program)
      (fun secure_tmpdir ->
        let suffix = sprintf "-%s.txt" (Devkit.Stre.replace_all ~str:suffix ~sub:"/" ~by:"-") in
        Lwt_io.with_temp_file ~temp_dir:secure_tmpdir ~suffix ~perm:0o600 f)

  let with_secure_tmpfile_gpt suffix f =
    let program = Filename.basename Sys.executable_name in
    let parent = Lazy.force shm_check in
    let tmpdir =
      match parent with
      | Some dir -> dir |> show_path
      | None -> Filename.get_temp_dir_name ()
    in
    (* Create a secure temporary directory *)
    let secure_tmpdir = Filename.concat tmpdir (Filename.temp_file (sprintf "%s." program) "") in
    Unix.mkdir secure_tmpdir 0o700;
    (* Replace all occurrences of '/' with '-' in the suffix *)
    let suffix = sprintf "-%s.txt" (Devkit.Stre.replace_all ~str:suffix ~sub:"/" ~by:"-") in
    (* Create a temporary file within the secure directory *)
    let tmpfile, oc = Filename.open_temp_file ~temp_dir:secure_tmpdir "" suffix in
    try
      (* Execute the function with the temporary file *)
      let result = f (tmpfile, oc) in
      (* Close the output channel *)
      close_out oc;
      (* Remove the temporary file *)
      Sys.remove tmpfile;
      (* Recursively delete the temporary directory *)
      (* let rec delete_recursively dir =
           let entries = Sys.readdir dir in
           Array.iter
             (fun entry ->
               let path = Filename.concat dir entry in
               if Sys.is_directory path then delete_recursively path else Sys.remove path)
             entries;
           Unix.rmdir dir
         in
         delete_recursively secure_tmpdir; *)
      Unix.rmdir secure_tmpdir;
      result
    with exn ->
      close_out_noerr oc;
      Sys.remove tmpfile;
      (* let rec delete_recursively dir =
           let entries = Sys.readdir dir in
           Array.iter
             (fun entry ->
               let path = Filename.concat dir entry in
               if Sys.is_directory path then delete_recursively path else Sys.remove path)
             entries;
           Unix.rmdir dir
         in
         delete_recursively secure_tmpdir; *)
      Unix.rmdir secure_tmpdir;
      raise exn

  (* with exn -> *)
  (* let rec delete_recursively dir =
       let entries = Sys.readdir dir in
       Array.iter
         (fun entry ->
           let path = Filename.concat dir entry in
           if Sys.is_directory path then delete_recursively path else Sys.remove path)
         entries;
       Unix.rmdir dir
     in
     delete_recursively secure_tmpdir; *)
  (* raise exn *)

  (* make sure they really meant to exit without saving. But this is going to mess
   * up if an editor never cleanly exits. *)
  let rec edit_loop tmpfile =
    let had_exception =
      try
        Shell.editor tmpfile;
        false
      with _ -> true
    in
    if had_exception then (
      match Prompt.yesno "Editor was exited without saving successfully, try again?" with
      | true -> edit_loop tmpfile
      | false -> false)
    else true

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
    with_secure_tmpfile_gpt (show_name secret_name) (fun (tmpfile, tmpfile_oc) ->
        (* write and then close to make it available to the editor *)
        let () = List.iter (Out_channel.output_string tmpfile_oc) recipient_lines in
        if edit_loop tmpfile then (
          let keys_list = Storage.Keys.get_keys (Path.inject tmpfile) |> List.sort Age.Key.compare in
          let (_ : Path.t) = Path.ensure_parent secret_recipients_file in
          let () =
            (* TODO is this correct? *)
            Devkit.Files.save_as (show_path secret_recipients_file) ~mode:0o666 (fun oc ->
                let contents = keys_list |> Age.Key.project_list |> String.concat "\n" in
                Out_channel.output_string oc contents)
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
            else ())
          else prerr_endline "I: no changes made to the recipients")
        else verbose_eprintlf "E: no recipients provided")

  let with_file filename f =
    let fd = Unix.openfile filename [ Unix.O_RDONLY; Unix.O_NONBLOCK ] 0 in
    let ic = Unix.in_channel_of_descr fd in
    try
      let result = f ic in
      close_in ic;
      result
    with exn ->
      close_in_noerr ic;
      raise exn

  let new_text_from_editor ?(initial = "") ?(name = "new") () =
    with_secure_tmpfile_gpt name (fun (tmpfile, tmpfile_oc) ->
        if initial <> "" then Out_channel.output_string tmpfile_oc initial;
        let () = Shell.editor tmpfile in
        with_file tmpfile In_channel.input_all)
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
      let () = Invariant.die_if_invariant_fails ~op_string:"create" (path_of_secret_name secret_name) in
      create_new_secret secret_name)

  let create_new_secret_from_stdin secret_name =
    let create_new_secret secret_name =
      Edit.edit_secret secret_name ~self_fallback:true ~allow_retry:false ~get_updated_secret:(fun _ ->
          let open Prompt in
          let () = input_help_if_user_input () in
          get_valid_input_from_stdin_exn ())
    in
    invariant_create ~create_new_secret secret_name

  let create =
    let doc =
      {| creates a new secret from stdin. If the folder doesn't have recipients specified already,
      tries to set them to the ones associated with \${PASSAGE_IDENTITY} |}
    in
    let info = Cmd.info "create" ~doc in
    let term = Term.(const create_new_secret_from_stdin $ Flags.secret_name) in
    Cmd.v info term
end

module Edit_cmd = struct
  let edit secret_name =
    match Storage.Secrets.secret_exists secret_name with
    | false -> Shell.die "E: no such secret: %s.  Use \"new\" or \"create\" for new secrets." (show_name secret_name)
    | true ->
      Invariant.run_if_recipient ~op_string:"edit secret" ~path:(path_of_secret_name secret_name) ~f:(fun () ->
          Edit.edit_secret secret_name ~allow_retry:true ~get_updated_secret:(fun initial ->
              let secret =
                Prompt.input_and_validate_loop (Edit.new_text_from_editor ?initial ~name:(show_name secret_name))
              in
              Result.value ~default:"" secret))

  let edit =
    let doc = "edit the contents of the specified secret" in
    let info = Cmd.info "edit" ~doc in
    let term = Term.(const edit $ Flags.secret_name) in
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
    let term = Term.(const edit_who_with_check $ Flags.secret_name) in
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
        try Shell.xclip_copy_to_clipboard s ~x_selection:Config.x_selection
        with exn -> Exn.fail ~exn "E: could not copy data to the clipboard"
      in
      let restore_clipboard original_content =
        let () = Unix.sleep Config.clip_time in
        let current_content = read_clipboard () in
        (* It might be nice to programatically check to see if klipper exists,
           as well as checking for other common clipboard managers. But for now,
           this works fine -- if qdbus isn't there or if klipper isn't running,
           this essentially becomes a no-op.

           Clipboard managers frequently write their history out in plaintext,
           so we axe it here: *)
        let () =
          try
            Shell.clear_clipboard_managers ()
            (* any exns raised are likely due to qdbus, klipper, etc., being absent.
               Thus, we swallow these exns so that it becomes a no-op *)
          with _ -> ()
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
      match Devkit.Nix.fork () with
      | `Child ->
        let (_ : int) = Unix.setsid () in
        restore_clipboard original_content;
        `Child
      | `Forked _ as forked -> forked
    let save_to_clipboard ~secret_name ~secret =
      try
        match save_to_clipboard_exn ~secret with
        | `Child -> ()
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
      let plaintext =
        try Storage.Secrets.decrypt_exn secret_name
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
      | QrCode -> Output.print_as_qrcode ~secret_name ~secret
      | Clipboard -> Output.save_to_clipboard ~secret_name ~secret
      | Stdout -> print_endline secret)

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

  let check_folders_without_keys_file () =
    prerr_endline
      {|
PASSAGE HEALTHCHECK. Diagnose for common problems

==========================================================================
Checking for folders without .keys file
==========================================================================|};
    let folders_without_keys_file = Storage.Secrets.(all_paths () |> List.filter has_secret_no_keys) in
    match folders_without_keys_file with
    | [] -> prerr_endline "\nSUCCESS: secrets all have .keys in the immediate directory"
    | _ ->
      print_endline "\nERROR: found paths with secrets but no .keys file:";
      List.iter (fun p -> printf "- %s" (show_path p)) folders_without_keys_file;
      healthcheck_with_errors := true

  let check_own_secrets_validity upgrade_mode =
    let open Storage in
    prerr_endline
      {|
==========================================================================
Checking for validity of own secrets. Use -v flag to break down per secret
==========================================================================
|};
    let recipients_of_own_id = Secrets.recipients_of_own_id () in
    List.iter
      (fun (recipient : Age.recipient) ->
        match Secrets.get_secrets_for_recipient recipient.name with
        | [] -> Devkit.eprintfn "No secrets found for %s" recipient.name
        | secrets ->
          let sorted_secrets = List.sort Secret_name.compare secrets in
          let ok, invalid, fail =
            List.fold_left
              (fun (ok, invalid, fail) secret_name ->
                try
                  let secret_text = Secrets.decrypt_exn ~silence_stderr:true secret_name in
                  match Secret.Validation.validate secret_text with
                  | Ok kind ->
                    verbose_eprintlf "✅ %s [ valid %s ]" (show_name secret_name) (Secret.kind_to_string kind);
                    succ ok, invalid, fail
                  | Error (e, validation_error_type) ->
                    healthcheck_with_errors := true;
                    printf "❌ %s [ invalid format: %s ]" (show_name secret_name) e;
                    let upgraded_secrets =
                      match upgrade_mode, validation_error_type with
                      | Upgrade, SingleLineLegacy ->
                        (try
                           let { Secret.text; comments; _ } = Secret.Validation.parse_exn secret_text in
                           let upgraded_secret =
                             Secret.singleline_from_text_description text (Option.value ~default:"" comments)
                           in
                           let recipients =
                             Storage.Secrets.get_recipients_from_path_exn (path_of_secret_name secret_name)
                           in
                           let () = Encrypt.encrypt_exn ~plaintext:upgraded_secret ~secret_name recipients in
                           eprintlf "I: updated %s" (show_name secret_name);
                           1
                         with exn ->
                           Devkit.eprintfn "E: encrypting %s failed: %s" (show_name secret_name)
                             (Printexc.to_string exn);
                           0)
                      | DryRun, SingleLineLegacy ->
                        eprintlf "I: would update %s" (show_name secret_name);
                        1
                      | NoUpgrade, _ | Upgrade, _ | DryRun, _ -> 0
                    in
                    ok + upgraded_secrets, succ (invalid - upgraded_secrets), fail
                with _ ->
                  printf "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret_name);
                  ok, invalid, succ fail)
              (0, 0, 0) sorted_secrets
          in
          Devkit.eprintfn "\nI: %i valid secrets, %i invalid and %i with decryption issues" ok invalid fail)
      recipients_of_own_id

  let healthcheck upgrade_mode =
    let () = check_folders_without_keys_file () in
    let () = check_own_secrets_validity upgrade_mode in
    match !healthcheck_with_errors with
    | true -> exit 1
    | false -> exit 0

  let healthcheck =
    let doc = "check for issues with secrets, find directories that don't have keys, etc." in
    let info = Cmd.info "healthcheck" ~doc in
    let term = Term.(const (fun () -> healthcheck) $ Flags.set_verbosity $ secrets_upgrade_mode) in
    Cmd.v info term
end

module Init = struct
  let init () =
    try
      (* create private and pub key, ask for user's name *)
      print_endline
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

What should be the name used for your recipient identity?|};
      let user_name = Prompt.read_input_from_stdin () in
      let user_name =
        String.trim user_name
        |> ExtString.String.replace_chars (fun c ->
               match c with
               | ' ' -> "_"
               | '\n' -> ""
               | c -> Char.escaped c)
      in
      let () = Shell.age_generate_identity_key_root_group_exn user_name in
      printf "\nPassage setup completed. "
    with exn ->
      (* Error out and delete everything, so we can start fresh next time *)
      FileUtil.rm ~recurse:true [ Config.base_dir ];
      printf "E: Passage init failed. Please try again. Error:\n\n%s" (Printexc.to_string exn)

  let init =
    let doc = "initial setup of passage" in
    let info = Cmd.info "init" ~doc in
    let term = Term.(const init $ const ()) in
    Cmd.v info term
end
module List_ = struct
  let list_secrets path =
    let raw_path = show_path path in
    match Storage.Secrets.secret_exists_at path with
    | true -> print_endline Storage.Secrets.(name_of_file (Path.abs path) |> show_name)
    | false ->
    match Path.is_directory (Path.abs path) with
    | true ->
      Storage.(Secrets.get_secrets_tree path |> List.sort Secret_name.compare)
      |> List.iter (fun s -> show_name s |> print_endline)
    | false -> Shell.die "No secrets at %s" raw_path

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
  let singleline prompt =
    printf "%s: \n" prompt;
    read_line ()

  let multiline prompt =
    printf "%s (hit enter twice to end):\n" prompt;
    let rec loop lines =
      let line = read_line () in
      if line = "" then String.concat "\n" (List.rev @@ lines) else loop (line :: lines)
    in
    loop []

  let notice note =
    print_endline note;
    let (_ : string) = read_line () in
    ()

  let create_new_secret secret_name =
    let description =
      multiline
        {|
Every secret should include where it comes from (how to rotate) and where it goes (how it is used).

Enter a complete description|}
    in
    let secret =
      singleline "Single-line secret (you'll be given a chance to edit the result or add more recipients next)"
    in
    let secret_and_description =
      match secret <> "", description = "" with
      | false, _ -> Shell.die "E: no secret provided. Quitting"
      | true, false ->
        (* single-line secrets with comments, use the correct format *)
        Secret.singleline_from_text_description secret description
      | true, true ->
        let () =
          notice "No description provided, creating single-line secret without description. Hit enter to continue."
        in
        secret
    in
    let secret_and_description =
      let rec loop ?(is_invalid = false) tmp_file =
        let new_text =
          let review_secret = Prompt.yesno "review/edit the resulting file?" in
          match is_invalid, review_secret with
          | true, false -> Shell.die "E: can't create the secret. Invalid format"
          | false, false -> tmp_file
          | _, true ->
          try Edit.new_text_from_editor ~initial:tmp_file () with exn -> Shell.die ~exn "Failed editing text"
        in
        match Secret.Validation.validate new_text with
        | Error (e, _t) ->
          printf "This secret is in an invalid format: %s\n" e;
          loop ~is_invalid:true new_text
        | Ok _ -> new_text
      in
      loop secret_and_description
    in
    try
      let secret_path = path_of_secret_name secret_name in
      let original_recipients = Storage.Secrets.get_recipients_from_path_exn secret_path in
      let () =
        Edit.show_recipients_notice_if_true (original_recipients = []);
        if Prompt.yesno "Edit recipients for this secret?" then Edit.edit_recipients secret_name else ()
      in
      (* if the new secret has no recipients, add ourselves to it *)
      let own_recipients = Storage.Secrets.recipients_of_own_id () in
      let () = Edit.add_recipients_if_none_exists own_recipients secret_path in
      let recipients = Storage.Secrets.get_recipients_from_path_exn secret_path in
      Encrypt.encrypt_exn ~plaintext:secret_and_description ~secret_name recipients
    with exn -> Shell.die ~exn "E: encrypting %s failed" (show_name secret_name)

  let create_new_secret' secret_name = Create.invariant_create ~create_new_secret secret_name

  let new_ =
    let doc = "interactive creation of a new single-line secret" in
    let info = Cmd.info "new" ~doc in
    let term = Term.(const create_new_secret' $ Flags.secret_name) in
    Cmd.v info term
end

module Realpath = struct
  let realpath paths =
    paths
    |> List.iter (fun path ->
           let abs_path = Path.abs path in
           if Storage.Secrets.secret_exists_at path then (
             let secret_name = secret_name_of_path path in
             print_endline (show_path (Path.abs (Storage.Secrets.agefile_of_name secret_name))))
           else if Path.is_directory abs_path then (
             let str = show_path abs_path in
             if Path.is_dot (Path.build_rel_path (show_path path)) then
               print_endline (Lazy.force Storage.Secrets.base_dir ^ "/")
             else print_endline (str ^ if String.ends_with ~suffix:"/" str then "" else "/"))
           else Devkit.eprintfn "W: real path of secret/folder %S not found\n" (show_path path))

  let realpath =
    let doc =
      "show the full filesystem path to secrets/folders.  Note it will only list existing files or directories."
    in
    let info = Cmd.info "realpath" ~doc in
    let term = Term.(const (fun () -> realpath) $ Flags.set_verbosity $ Flags.secrets_paths) in
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
    let term = Term.(const (fun () -> refresh_secrets) $ Flags.set_verbosity $ Flags.secrets_paths) in
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
          let () = Prompt.input_help_if_user_input () in
          (* We don't need to run validation for the input here since we will be replacing only the secret
              and not the whole file *)
          let new_secret_plaintext = Prompt.read_input_from_stdin () in
          if new_secret_plaintext = "" then Shell.die "E: invalid input, empty secrets are not allowed.";
          let is_singleline_secret =
            (* New secret is single line if doesn't have a newline character or if it has only one,
                at the end of the first line. This input isn't supposed to follow the storage format,
               it only contains a secret and no comments *)
            match String.split_on_char '\n' new_secret_plaintext with
            | [ _ ] | [ _; "" ] -> true
            | _ -> false
          in
          let updated_secret =
            match Storage.Secrets.secret_exists secret_name with
            | false ->
              (* if the secret doesn't exist yet, create a new secret with the right format *)
              (match is_singleline_secret with
              | true -> new_secret_plaintext
              | false -> "\n\n" ^ new_secret_plaintext)
            | true ->
              (* if there is already a secret, recreate or replace it *)
              let original_secret' =
                (* Get the original secret if we are in the recipient list, otherwise fully replace it *)
                try Storage.Secrets.decrypt_exn ~silence_stderr:true secret_name with _ -> ""
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
              (match is_singleline_secret with
              | true ->
                new_secret_plaintext ^ extract_comments ~f:(fun comments -> "\n" ^ comments) ~default:"" original_secret
              | false ->
                (* add an empty line before comments and before the secret,
                   or just an empty line if there are no comments *)
                extract_comments ~f:(fun comments -> "\n" ^ comments ^ "\n") ~default:"\n" original_secret
                ^ "\n"
                ^ new_secret_plaintext)
          in
          try Encrypt.encrypt_exn ~plaintext:updated_secret ~secret_name recipients
          with exn -> Shell.die ~exn "E: encrypting %s failed" (show_name secret_name))

  let replace =
    let doc =
      "replaces the contents of the specified secret, keeping the comments. If the secret doesn't exist, it gets \
       created as a single or multi-line secret WITHOUT any comments"
    in
    let info = Cmd.info "replace" ~doc in
    let term = Term.(const replace_secret $ Flags.secret_name) in
    Cmd.v info term
end

module Rm = struct
  let force =
    let doc = "Delete secrets and folders without asking for confirmation" in
    Arg.(value & flag & info [ "f"; "force" ] ~doc)

  let rm_secrets paths force =
    List.iter
      (fun path ->
        let is_directory = Path.is_directory (Path.abs path) in
        match Storage.Secrets.secret_exists_at path, is_directory with
        | false, false -> Shell.die "E: no secrets exist at %s" (show_path path)
        | _ ->
          let string_path = show_path path in
          let rm_result =
            if force then Storage.Secrets.rm ~is_directory path
            else (
              match Prompt.yesno_tty_check (sprintf "Are you sure you want to delete %s?" string_path) with
              | NoTTY | TTY true -> Storage.Secrets.rm ~is_directory path
              | TTY false -> Storage.Secrets.Skipped)
          in
          (match rm_result with
          | Storage.Secrets.Succeeded () -> verbose_eprintlf "I: removed %s" string_path
          | Skipped -> eprintlf "I: skipped deleting %s" string_path
          | Failed exn -> Shell.die "E: failed to delete %s : %s" string_path (Exn.to_string exn)))
      paths

  let rm =
    let doc = "remove a secret or a folder and its secrets" in
    let info = Cmd.info "rm" ~doc in
    let term = Term.(const (fun () -> rm_secrets) $ Flags.set_verbosity $ Flags.secrets_paths $ force) in
    Cmd.v info term

  let delete =
    let doc = "same as the $(i,rm) cmd. Remove a secret or a folder and its secrets" in
    let info = Cmd.info "delete" ~doc in
    let term = Term.(const (fun () -> rm_secrets) $ Flags.set_verbosity $ Flags.secrets_paths $ force) in
    Cmd.v info term
end

module Search = struct
  let search_secrets pattern path =
    let secrets = Storage.Secrets.get_secrets_tree path |> List.sort Storage.Secret_name.compare in
    let n_skipped, n_failed, n_matched, matched_secrets =
      List.fold_left
        (fun (n_skipped, n_failed, n_matched, matched_secrets) secret ->
          match Storage.Secrets.search secret pattern with
          | Succeeded true -> n_skipped, n_failed, n_matched + 1, secret :: matched_secrets
          | Succeeded false -> n_skipped, n_failed, n_matched, matched_secrets
          | Skipped ->
            verbose_eprintlf "I: skipped %s" (show_name secret);
            n_skipped + 1, n_failed, n_matched, matched_secrets
          | Failed exn ->
            eprintlf "W: failed to search %s : %s" (show_name secret) (Exn.to_string exn);
            n_skipped, n_failed + 1, n_matched, matched_secrets)
        (0, 0, 0, []) secrets
    in
    let () =
      printf "I: skipped %d secrets, failed to search %d secrets and matched %d secrets" n_skipped n_failed n_matched
    in
    List.rev matched_secrets |> List.iter (fun s -> print_endline (show_name s))

  let search =
    let pattern =
      let doc = "the pattern to match against" in
      Arg.(required & pos 0 (some Converters.pattern_arg) None & info [] ~docv:"PATTERN" ~doc)
    in
    let secrets_path =
      let doc = "the relative $(docv) from the secrets directory that will be searched" in
      Arg.(value & pos 1 Converters.path_arg (Path.inject ".") & info [] ~docv:"PATH" ~doc)
    in
    let term = Term.(const (fun () -> search_secrets) $ Flags.set_verbosity $ pattern $ secrets_path) in
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
      let tree = Dirtree.of_path (Path.to_fpath full_path) in
      Dirtree.pp tree

  let show =
    let doc =
      "recursively list all secrets in a tree-like format. If used on a single secret, it will work the same as the \
       cat command."
    in
    let info = Cmd.info "show" ~doc in
    let term = Term.(const list_secrets_tree $ Flags.secrets_path) in
    Cmd.v info term
end

module Subst = struct
  let template =
    let doc = "a template on the commandline" in
    Arg.(required & pos 0 (some Converters.template_arg) None & info [] ~doc ~docv:"TEMPLATE_ARG")

  let substitute template = try Template.substitute ~template () with exn -> Shell.die ~exn "E: failed to substitute"

  let subst =
    let doc = "fill in values in the provided template" in
    let info = Cmd.info "subst" ~doc in
    let term = Term.(const substitute $ template) in
    Cmd.v info term
end

module Template_cmd = struct
  let substitute_template template_file target_file =
    try Template.substitute_file ~template_file ~target_file with exn -> Shell.die ~exn "E: failed to substitute file"

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
    List.iter
      (fun recipient_name ->
        let open Storage in
        match List.mem recipient_name all_recipient_names, Age.is_group_recipient recipient_name with
        | false, false -> eprintlf "E: no such recipient %s" recipient_name
        | _ ->
        match Secrets.get_secrets_for_recipient recipient_name with
        | [] -> eprintlf "\nNo secrets found for %s" recipient_name
        | secrets ->
          if number_of_recipients > 1 then eprintlf "\nSecrets which %s is a recipient of:" recipient_name else ();
          let sorted = List.sort Secret_name.compare secrets in
          let print_secret secret =
            match !verbosity with
            | Normal -> print_endline (show_name secret)
            | Verbose ->
            try
              let plaintext = Storage.Secrets.decrypt_exn ~silence_stderr:true secret in
              print_endline @@ Secret.Validation.validity_to_string (show_name secret) plaintext
            with _ -> print_endline @@ sprintf "🚨 %s [ WARNING: failed to decrypt ]" (show_name secret)
          in
          List.iter print_secret sorted)
      recipients_names

  let what =
    let doc = "list secrets that a recipient has access to" in
    let info = Cmd.info "what" ~doc in
    let term = Term.(const (fun () -> list_recipient_secrets) $ Flags.set_verbosity $ recipient_name) in
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
