module With_config (Config : Types.Config) = struct
  module Path = Path.With_config (Config)
  module Storage = Storage.With_config (Config)

  (** Display and conversion functions for paths and secret names *)
  module Show = struct
    let show_path p = Path.project p

    let show_name name = Storage.Secret_name.project name

    let path_of_secret_name name = show_name name |> Path.inject

    let secret_name_of_path path = show_path path |> Storage.Secrets.build_secret_name
  end

  open Show

  module Editor = struct
    let shm_check =
      lazy
        (let shm_dir = Path.inject "/dev/shm" in
         let has_sufficient_perms =
           try
             Path.access shm_dir [ F_OK; W_OK ];
             true
           with Unix.Unix_error _ -> false
         in
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
         | true -> None)

    let with_secure_tmpfile f =
      let temp_dir =
        match Lazy.force shm_check with
        | Some p -> show_path p
        | None -> Filename.get_temp_dir_name ()
      in
      Devkit.Control.with_open_out_temp_file ~temp_dir ~mode:[ Open_wronly; Open_creat; Open_excl ] f

    let rec edit_loop tmpfile =
      try
        Shell.editor tmpfile;
        true
      with
      | _ when Prompt.yesno "Editor was exited without saving successfully, try again?" -> edit_loop tmpfile
      | _ -> false

    (* Unified editor abstraction with validation and retry *)
    let edit_with_validation ?(initial = "") ~validate () =
      with_secure_tmpfile (fun (tmpfile, tmpfile_oc) ->
          (* Write initial content and close to make available to editor *)
          if initial <> "" then output_string tmpfile_oc initial;
          close_out tmpfile_oc;

          match edit_loop tmpfile with
          | false -> Error "Editor cancelled"
          | true ->
            let rec validate_and_edit () =
              match validate @@ Prompt.preprocess_content @@ Std.input_file tmpfile with
              | Ok r -> r
              | Error e ->
              match Prompt.is_TTY with
              | false -> Shell.die "%s" e
              | true ->
                let () = Printf.printf "\n%s\n" e in
                (match Prompt.yesno "Edit again?" with
                | false -> Shell.die "%s" e
                | true ->
                  let _ = edit_loop tmpfile in
                  validate_and_edit ())
            in
            Ok (validate_and_edit ()))
  end

  (** Recipients helper utilities for common patterns *)
  module Recipients = struct
    (** Get recipients from secret name and handle "no recipients found" error *)
    let get_recipients_or_die secret_name =
      let recipients = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name) in
      match recipients with
      | [] ->
        Shell.die
          {|E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)|}
          (show_name secret_name)
      | _ -> recipients
  end

  (** Secret helper utilities for common patterns *)
  module Secret = struct
    (** Decrypt and parse a secret in one operation *)
    let decrypt_and_parse ?(silence_stderr = false) secret_name =
      let plaintext = Storage.Secrets.decrypt_exn ~silence_stderr secret_name in
      Secret.Validation.parse_exn plaintext

    (** Reconstruct a secret from parsed secret and new comments *)
    let reconstruct_secret ~comments { Secret.kind; text; _ } =
      match kind with
      | Secret.Singleline -> Secret.singleline_from_text_description text (Option.value ~default:"" comments)
      | Secret.Multiline -> Secret.multiline_from_text_description text (Option.value ~default:"" comments)

    (** Check if a secret exists, die with standard error if not *)
    let check_exists secret_name =
      match Storage.Secrets.secret_exists secret_name with
      | false -> Shell.die "E: no such secret: %s" (show_name secret_name)
      | true -> ()

    (** Check if a secret exists, die with hint about create/new if not *)
    let check_exists_or_die secret_name =
      match Storage.Secrets.secret_exists secret_name with
      | false -> Shell.die "E: no such secret: %s.  Use \"new\" or \"create\" for new secrets." (show_name secret_name)
      | true -> ()

    (** Check if a secret exists at path, die with standard error if not *)
    let check_path_exists_or_die secret_name path =
      match Storage.Secrets.secret_exists_at path with
      | false -> Shell.die "E: no such secret: %s" (show_name secret_name)
      | true -> ()

    (** Decrypt secret with silent stderr - common pattern *)
    let decrypt_silently secret_name = Storage.Secrets.decrypt_exn ~silence_stderr:true secret_name

    (** Common recipient error messages *)
    let die_no_recipients_found path = Shell.die "E: no recipients found for %s" (show_path path)

    let die_failed_get_recipients ?exn msg =
      match exn with
      | Some e -> Shell.die ~exn:e "E: failed to get recipients"
      | None -> Shell.die "E: failed to get recipients: %s" msg

    (** Create a secret with new text but keeping existing secret's comments *)
    let reconstruct_with_new_text ~is_singleline ~new_text ~existing_comments =
      let comments = Option.value ~default:"" existing_comments in
      match is_singleline with
      | true -> Secret.singleline_from_text_description new_text comments
      | false -> Secret.multiline_from_text_description new_text comments
  end
end

include With_config (Default_config)
