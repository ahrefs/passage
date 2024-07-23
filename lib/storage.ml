open Printf

module Action = Devkit.Action
module Stre = Devkit.Stre

let ( !! ) = Lazy.force

module Secret_name = struct
  include Devkit.Fresh (String) ()
  let norm_secret secret = project secret |> Path.build_rel_path |> Path.project |> inject
end

module Keys = struct
  let base_dir = Config.keys_dir
  let ext = "pub"

  (** Takes the recipient name and returns the full path to the public key of the recipient *)
  let key_file_of_recipient_name recipient_name =
    let base_key_file_name = FilePath.add_extension recipient_name ext in
    Filename.concat !!base_dir base_key_file_name |> Path.inject

  let get_keys key_file =
    match Path.file_exists key_file with
    | false -> []
    | true -> Action.config_lines (Path.project key_file) |> Age.Key.inject_list

  let keys_of_recipient (name : string) = get_keys @@ key_file_of_recipient_name name

  let all_recipient_names () =
    FileUtil.find ~follow:Follow (Has_extension ext) !!base_dir
      (fun acc f ->
        let name = FilePath.make_relative !!base_dir f in
        let name = Stre.drop_suffix name ("." ^ ext) in
        name :: acc)
      []
    |> List.sort String.compare
end

module Secrets = struct
  type 'a outcome =
    | Succeeded of 'a
    | Failed of exn
    | Skipped

  let base_dir = Config.secrets_dir
  let ext = Age.ext
  let groups_ext = "group"

  let keys_ext = ".keys"

  let to_path secret = secret |> Secret_name.norm_secret |> Secret_name.project |> Path.inject

  let agefile_of_name name = Path.inject (FilePath.add_extension (Secret_name.project name) ext)

  let name_of_file file =
    let fname = Path.project file in
    Stre.after fname (!!base_dir ^ Filename.dir_sep) |> FilePath.chop_extension |> Secret_name.inject

  let secret_exists secret_name = Path.abs (agefile_of_name secret_name) |> Path.file_exists

  let secret_exists_at path =
    try FilePath.add_extension Path.(project @@ abs path) ext |> Sys.file_exists with FilePath.NoExtension _ -> false

  let build_secret_name name =
    try
      let name = Secret_name.inject name in
      (* We have this check here to avoid uncaught exns in other spots later *)
      let (_ : Path.t) = agefile_of_name name in
      name |> Secret_name.norm_secret
    with FilePath.NoExtension filename -> Devkit.Exn.fail "%s is not a valid secret" filename

  let get_secrets_tree path =
    let full_path = Path.(project @@ abs path) in
    FileUtil.find ~follow:Follow (Has_extension ext) full_path (fun accum f -> f :: accum) []
    |> Path.inject_list
    |> List.map name_of_file

  let get_secrets_in_folder path =
    let full_path = Path.(project @@ abs path) in
    FileUtil.(ls full_path |> filter (Has_extension ext)) |> Path.inject_list |> List.map name_of_file

  let all_paths () =
    FileUtil.find FileUtil.Is_dir !!base_dir
      (fun accum f -> Option.map Path.of_fpath (Fpath.relativize ~root:(Fpath.v !!base_dir) (Fpath.v f)) :: accum)
      []
    |> List.filter_map Fun.id

  let has_secret_no_keys path =
    let path_str = Path.(concat (inject !!base_dir) path |> project) in
    let has_secret = FileUtil.(ls path_str |> filter (Has_extension ext)) <> [] in
    has_secret && (not @@ Sys.file_exists (Filename.concat path_str keys_ext))

  let no_keys_file path =
    let path_str = Path.concat (Path.inject !!base_dir) path |> Path.project in
    not @@ Sys.file_exists (Filename.concat path_str keys_ext)

  let all_groups_names () =
    FileUtil.(ls !!Config.keys_dir |> filter (Has_extension groups_ext))
    |> List.map (fun group -> FilePath.chop_extension @@ Filename.basename group)
    |> List.sort String.compare

  let recipient_of_name name = { Age.name; keys = Keys.keys_of_recipient name }

  let recipients_of_group_name ~map_fn group_name' =
    let recipients_names =
      match group_name' with
      | "@everyone" -> Keys.all_recipient_names ()
      | _ ->
        (* get the name of the group without the '@' at the beginnning *)
        let group_name = String.sub group_name' 1 (String.length group_name' - 1) in
        let existing_groups = all_groups_names () in
        (match List.mem group_name existing_groups with
        (* We don't want to allow referencing non existent groups *)
        | false -> Shell.die "E: group %S doesn't exist" group_name'
        | true ->
          let group_file = FilePath.concat !!Config.keys_dir (FilePath.add_extension group_name groups_ext) in
          Action.config_lines group_file)
    in
    List.map map_fn recipients_names

  let get_secrets_for_recipient recipient_name =
    let rec get_secrets curr_dir accum =
      let dir_contents = Sys.readdir curr_dir |> Array.to_list |> List.map (Filename.concat curr_dir) in
      let keys_file = Filename.concat curr_dir keys_ext in
      let secret_names, subdirs =
        List.fold_left
          (fun (secret_names, subdirs) filename ->
            match FileUtil.(test (Has_extension ext) filename) with
            | true -> name_of_file (Path.inject filename) :: secret_names, subdirs
            | false ->
            match Sys.is_directory filename with
            | true -> secret_names, filename :: subdirs
            | false -> secret_names, subdirs)
          ([], []) dir_contents
      in
      let recipients_and_groups = Action.config_lines keys_file in
      let groups_names, _recipients = List.partition Age.is_group_recipient @@ recipients_and_groups in
      let is_recipient_from_groups =
        List.fold_left
          (fun is_recipient group ->
            match
              ( is_recipient,
                List.mem recipient_name (recipients_of_group_name ~map_fn:(fun x -> x) group),
                group = "@everyone" )
            with
            | true, _, _ | false, false, false -> is_recipient
            | _ -> true)
          false groups_names
      in
      let accum' =
        (* We need to check if the recipient is member of recipients_and_groups too
           because we can use this for groups too, so recipient_name can be a group name *)
        match List.mem recipient_name recipients_and_groups, is_recipient_from_groups with
        | false, false -> accum
        | _ -> List.rev_append accum secret_names
      in
      List.fold_left (fun accum subdir -> get_secrets subdir accum) accum' subdirs
    in
    get_secrets !!base_dir []

  (** Returns the path to the .keys file for a secret *)
  let get_recipients_file_path path_to_secret =
    let open Path in
    let path_to_secret = if is_directory @@ abs path_to_secret then path_to_secret else dirname path_to_secret in
    concat (concat (inject !!base_dir) path_to_secret) (inject keys_ext)

  let get_recipients_names path =
    Action.config_lines (Path.project (get_recipients_file_path path)) |> List.sort String.compare

  let get_recipients_from_path_exn path =
    let recipients' = get_recipients_names path in
    let groups_names, recipients_names = List.partition Age.is_group_recipient recipients' in
    let groups_recipients =
      List.map (recipients_of_group_name ~map_fn:recipient_of_name) groups_names |> List.flatten
    in
    let recipients = List.map recipient_of_name recipients_names in
    recipients @ groups_recipients
    |> List.sort Age.recipient_compare
    |> List.fold_right
         (fun (recipient : Age.recipient) (acc : Age.recipient list) ->
           match acc with
           | r' :: _ when r'.name = recipient.name -> acc
           | _ -> recipient :: acc)
         []

  let get_expanded_recipient_names secret_name =
    let full_path = Path.concat (Path.inject !!base_dir) (to_path secret_name) in
    let recipients' = Action.config_lines @@ Filename.concat (Path.project full_path) keys_ext in
    let groups, recipients = List.partition Age.is_group_recipient recipients' in
    let group_recipients =
      List.map
        (fun group ->
          let recipients = recipients_of_group_name ~map_fn:recipient_of_name group in
          List.map (fun (r : Age.recipient) -> r.name) recipients)
        groups
      |> List.flatten
    in
    recipients @ group_recipients
    |> List.sort String.compare
    |> List.fold_right
         (fun recipient acc ->
           match acc with
           | r' :: _ when r' = recipient -> acc
           | _ -> recipient :: acc)
         []

  let is_recipient_of_secret key secret_name =
    let recipients = get_recipients_from_path_exn (to_path secret_name) in
    let recipients_keys = Age.get_recipients_keys recipients in
    List.mem key recipients_keys

  (* Outputs encrypted text to a tmpfile first, before replacing the secret (if it already exists)
     with the tmpfile. This is to handle exceptional situations where the encryption is interrupted halfway.
  *)
  let encrypt_using_tmpfile ~secret_name ~encrypt_to_stdout =
    let secret_file = Path.abs @@ agefile_of_name secret_name in
    let temp_dir = secret_file |> Path.ensure_parent |> Path.project in
    let tmpfile_suffix = sprintf ".%s.tmp" Path.(basename secret_file |> project) in
    let tmpfile, tmpfile_oc =
      Filename.open_temp_file ~mode:[ Open_creat; Open_wronly; Open_trunc ] ~perms:0o644 ~temp_dir "" tmpfile_suffix
    in
    let tmpfile_fd = Unix.descr_of_out_channel tmpfile_oc in
    let%lwt () = encrypt_to_stdout ~stdout:(`FD_move tmpfile_fd) in
    FileUtil.mv tmpfile (Path.project secret_file);
    Lwt.return_unit

  let encrypt_exn ~plaintext ~secret_name recipients =
    let%lwt () = encrypt_using_tmpfile ~secret_name ~encrypt_to_stdout:(Age.encrypt_to_stdout ~recipients ~plaintext) in
    Lwt.return_unit

  let decrypt_exn ?(silence_stderr = false) secret_name =
    let secret_file = Path.(project @@ abs @@ agefile_of_name secret_name) in
    let fd = Unix.openfile secret_file [ O_RDONLY ] 0o400 in
    Age.decrypt_from_stdin ~identity_file:!!Config.identity_file ~stdin:(`FD_move fd) ~silence_stderr

  let refresh' ?(force = false) secret_name self_key =
    match force || is_recipient_of_secret self_key secret_name with
    | false -> Lwt.return Skipped
    | true ->
      (try%lwt
         let fd_r, fd_w = Unix.pipe () in
         let%lwt () =
           let secret_file = Path.abs @@ agefile_of_name secret_name in
           let secret_fd = Unix.openfile (Path.project secret_file) [ O_RDONLY ] 0o400 in
           Age.decrypt_from_stdin_to_stdout ~identity_file:!!Config.identity_file ~stdin:(`FD_move secret_fd)
             ~silence_stderr:false ~stdout:(`FD_move fd_w)
         in
         let%lwt () =
           let recipients = get_recipients_from_path_exn (to_path secret_name) in
           encrypt_using_tmpfile ~secret_name
             ~encrypt_to_stdout:(Age.encrypt_from_stdin_to_stdout ~recipients ~stdin:(`FD_move fd_r))
         in
         Lwt.return (Succeeded ())
       with exn -> Lwt.return @@ Failed exn)

  let refresh ~verbose ?force secrets =
    let verbose_print fmt =
      ksprintf
        (fun msg ->
          match verbose with
          | true -> Lwt_io.eprintl msg
          | false -> Lwt.return_unit)
        fmt
    in
    let%lwt self_key = Age.Key.from_identity_file !!Config.identity_file in
    let%lwt skipped, refreshed, failed =
      Lwt_list.fold_left_s
        (fun (skipped, refreshed, failed) secret ->
          let raw_secret_name = Secret_name.project secret in
          match%lwt refresh' ?force secret self_key with
          | Succeeded () ->
            let%lwt () = verbose_print "I: refreshed %s" raw_secret_name in
            Lwt.return (skipped, refreshed + 1, failed)
          | Skipped ->
            let%lwt () = verbose_print "I: skipped %s" raw_secret_name in
            Lwt.return (skipped + 1, refreshed, failed)
          | Failed exn ->
            let%lwt () = verbose_print "W: failed to refresh %s : %s" raw_secret_name (Devkit.Exn.to_string exn) in
            Lwt.return (skipped, refreshed, failed + 1))
        (0, 0, 0) secrets
    in
    Lwt_io.eprintlf "I: refreshed %d secrets, skipped %d, failed %d" refreshed skipped failed

  let rm ~is_directory path =
    try
      let absolute_path = Path.abs path in
      let recurse, path_to_delete =
        match is_directory with
        | true -> true, Path.project absolute_path
        | false ->
          let dirname_folder = Path.dirname path in
          (* if there is only one secret in the folder, delete the whole folder,
             otherwise delete only the secret's .age file *)
          (match get_secrets_tree dirname_folder with
          | [] -> failwith "unreachable"
          | [ _ ] -> true, Path.(project @@ abs dirname_folder)
          | _ :: _ -> false, FilePath.add_extension (Path.project absolute_path) ext)
      in
      FileUtil.rm ~recurse [ path_to_delete ];
      Lwt.return (Succeeded ())
    with exn -> Lwt.return (Failed exn)

  let search secret_name pattern =
    let%lwt self_key = Age.Key.from_identity_file !!Config.identity_file in
    match is_recipient_of_secret self_key secret_name with
    | false -> Lwt.return Skipped
    | true ->
      (match%lwt decrypt_exn ~silence_stderr:true secret_name with
      | exception exn -> Lwt.return (Failed exn)
      | content ->
        let matched = Re2.matches pattern content in
        Lwt.return (Succeeded matched))

  (** Returns a list with the keys that are recipients for the default identity file *)
  let recipients_of_own_id () =
    let%lwt own_key = Age.Key.from_identity_file !!Config.identity_file in
    Lwt.return
      (Keys.all_recipient_names ()
      |> List.filter_map (fun name ->
             let keys = Keys.keys_of_recipient name in
             match List.mem own_key keys with
             | true -> Some { Age.name; keys }
             | false -> None))
end
