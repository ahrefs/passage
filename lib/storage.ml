open Printf

(** Read lines from a config file, filtering out comments and empty lines *)
let config_lines filename =
  if not (Sys.file_exists filename) then []
  else
    In_channel.with_open_text filename (fun ic ->
      let rec read_lines acc =
        match In_channel.input_line ic with
        | None -> List.rev acc
        | Some line -> read_lines (line :: acc)
      in
      read_lines []
      |> List.filter_map (fun line ->
        let trimmed = String.trim line in
        if trimmed = "" || String.starts_with ~prefix:"#" trimmed then None else Some trimmed))

module Secret_name = struct
  include Types.Fresh (String)
  let norm_secret secret = project secret |> Path.build_rel_path |> Path.project |> inject
end

module Keys = struct
  let get_keys_dir () = Lazy.force !Config.keys_dir
  let ext = "pub"

  (** Takes the recipient name and returns the full path to the public key of the recipient *)
  let key_file_of_recipient_name recipient_name =
    let base_key_file_name = FilePath.add_extension recipient_name ext in
    Filename.concat (get_keys_dir ()) base_key_file_name |> Path.inject

  let get_keys key_file =
    match Path.file_exists key_file with
    | false -> []
    | true -> config_lines (Path.project key_file) |> Age.Key.inject_list

  let keys_of_recipient (name : string) = get_keys @@ key_file_of_recipient_name name

  let all_recipient_names () =
    FileUtil.find ~follow:Follow (Has_extension ext) (get_keys_dir ())
      (fun acc f ->
        let name = FilePath.make_relative (get_keys_dir ()) f in
        let name = FilePath.chop_extension name in
        name :: acc)
      []
    |> List.sort String.compare
end

module Secrets = struct
  type 'a outcome =
    | Succeeded of 'a
    | Failed of exn
    | Skipped

  let get_secrets_dir () = Lazy.force !Config.secrets_dir
  let ext = Age.ext
  let groups_ext = "group"

  let keys_ext = ".keys"

  let verbose_eprintlf ?(verbose = false) fmt =
    if verbose then Printf.ksprintf (fun s -> Printf.eprintf "%s\n" s) fmt else Printf.ksprintf (fun _ -> ()) fmt

  let to_path secret = secret |> Secret_name.norm_secret |> Secret_name.project |> Path.inject

  let agefile_of_name name = Path.inject (FilePath.add_extension (Secret_name.project name) ext)

  let name_of_file file =
    let fname = Path.project file in
    let prefix = get_secrets_dir () ^ Filename.dir_sep in
    let prefix_len = String.length prefix in
    String.sub fname prefix_len (String.length fname - prefix_len) |> FilePath.chop_extension |> Secret_name.inject

  let secret_exists secret_name = Path.abs (agefile_of_name secret_name) |> Path.file_exists

  let secret_exists_at path =
    try FilePath.add_extension Path.(project @@ abs path) ext |> Sys.file_exists with FilePath.NoExtension _ -> false

  let build_secret_name name =
    try
      let name = Secret_name.inject name in
      (* We have this check here to avoid uncaught exns in other spots later *)
      let (_ : Path.t) = agefile_of_name name in
      name |> Secret_name.norm_secret
    with FilePath.NoExtension filename -> Exn.die "%s is not a valid secret" filename

  let get_secrets_tree path =
    let full_path = Path.(project @@ abs path) in
    FileUtil.find ~follow:Follow (Has_extension ext) full_path (fun accum f -> f :: accum) []
    |> Path.inject_list
    |> List.map name_of_file

  let get_secrets_in_folder path =
    let full_path = Path.(project @@ abs path) in
    FileUtil.(ls full_path |> filter (Has_extension ext)) |> Path.inject_list |> List.map name_of_file

  let all_paths () =
    FileUtil.find FileUtil.Is_dir (get_secrets_dir ())
      (fun accum f ->
        Option.map Path.of_fpath (Fpath.relativize ~root:(Fpath.v (get_secrets_dir ())) (Fpath.v f)) :: accum)
      []
    |> List.filter_map Fun.id

  let has_secret_no_keys path =
    let path_str = Path.(concat (inject (get_secrets_dir ())) path |> project) in
    let has_secret = FileUtil.(ls path_str |> filter (Has_extension ext)) <> [] in
    has_secret && (not @@ Sys.file_exists (Filename.concat path_str keys_ext))

  let no_keys_file path =
    let path_str = Path.concat (Path.inject (get_secrets_dir ())) path |> Path.project in
    not @@ Sys.file_exists (Filename.concat path_str keys_ext)

  let all_groups_names () =
    FileUtil.(ls (Keys.get_keys_dir ()) |> filter (Has_extension groups_ext))
    |> List.map (fun group -> FilePath.chop_extension @@ Filename.basename group)
    |> List.sort String.compare

  let recipient_of_name name = { Age.name; keys = Keys.keys_of_recipient name }

  let recipients_of_group_name_exn ~map_fn group_name' =
    let recipients_names =
      match group_name' with
      | "@everyone" -> Keys.all_recipient_names ()
      | _ ->
        (* get the name of the group without the '@' at the beginnning *)
        let group_name = String.sub group_name' 1 (String.length group_name' - 1) in
        let existing_groups = all_groups_names () in
        (match List.mem group_name existing_groups with
        (* We don't want to allow referencing non existent groups *)
        | false -> Exn.die "E: group %S doesn't exist" group_name'
        | true ->
          let group_file = FilePath.concat (Keys.get_keys_dir ()) (FilePath.add_extension group_name groups_ext) in
          config_lines group_file)
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
      let recipients_and_groups = config_lines keys_file in
      let groups_names, _recipients = List.partition Age.is_group_recipient @@ recipients_and_groups in
      let is_recipient_from_groups =
        List.fold_left
          (fun is_recipient group ->
            match
              ( is_recipient,
                (try List.mem recipient_name (recipients_of_group_name_exn ~map_fn:Fun.id group) with _ -> false),
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
    get_secrets (get_secrets_dir ()) []

  (** Returns the path to the .keys file for a secret *)
  let get_recipients_file_path path_to_secret =
    let open Path in
    let path_to_secret = if is_directory @@ abs path_to_secret then path_to_secret else dirname path_to_secret in
    concat (concat (inject (get_secrets_dir ())) path_to_secret) (inject keys_ext)

  let get_recipients_names path =
    config_lines (Path.project (get_recipients_file_path path)) |> List.sort String.compare

  let get_recipients_from_path_exn path =
    let recipients' = get_recipients_names path in
    let groups_names, recipients_names = List.partition Age.is_group_recipient recipients' in
    let groups_recipients =
      List.map (fun g -> try recipients_of_group_name_exn ~map_fn:recipient_of_name g with _ -> []) groups_names
      |> List.flatten
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

  let is_recipient_of_secret key secret_name =
    let recipients = get_recipients_from_path_exn (to_path secret_name) in
    let recipients_keys = Age.get_recipients_keys recipients in
    List.mem key recipients_keys

  (* Outputs encrypted text to a tmpfile first, before replacing the secret (if it already exists)
     with the tmpfile. This is to handle exceptional situations where the encryption is interrupted halfway.
  *)
  let encrypt_using_tmpfile ~secret_name ~plaintext ?use_sudo recipients =
    let secret_file = Path.abs @@ agefile_of_name secret_name in
    let encrypted_content = Age.encrypt_string ?use_sudo ~recipients plaintext in
    let temp_dir = secret_file |> Path.ensure_parent |> Path.project in
    let tmpfile_suffix = sprintf ".%s.tmp" Path.(basename secret_file |> project) in
    let tmpfile, tmpfile_oc =
      Filename.open_temp_file ~mode:[ Open_creat; Open_wronly; Open_trunc ] ~perms:0o644 ~temp_dir "" tmpfile_suffix
    in
    let () = output_string tmpfile_oc encrypted_content in
    close_out tmpfile_oc;
    FileUtil.mv tmpfile (Path.project secret_file)

  let encrypt_exn ?use_sudo ?(verbose = false) ~plaintext ~secret_name recipients =
    verbose_eprintlf ~verbose "I: encrypting %s for %s" (Secret_name.project secret_name)
      (List.map (fun r -> Age.(r.name)) recipients |> String.concat ", ");
    encrypt_using_tmpfile ~secret_name ~plaintext recipients ?use_sudo

  let decrypt_exn ?use_sudo ?(silence_stderr = false) secret_name =
    let secret_file = Path.(project @@ abs @@ agefile_of_name secret_name) in
    let ciphertext = In_channel.with_open_text secret_file In_channel.input_all in
    Age.decrypt_string ?use_sudo ~identity_file:(Lazy.force !Config.identity_file) ~silence_stderr ciphertext

  let refresh' ?use_sudo ?(force = false) secret_name self_key =
    match force || is_recipient_of_secret self_key secret_name with
    | false -> Skipped
    | true ->
    try
      (* Simple decrypt -> re-encrypt flow *)
      let plaintext = decrypt_exn ?use_sudo ~silence_stderr:false secret_name in
      let recipients = get_recipients_from_path_exn (to_path secret_name) in
      encrypt_using_tmpfile ~secret_name ~plaintext recipients ?use_sudo;
      Succeeded ()
    with exn -> Failed exn

  let get_own_key ?use_sudo () = Age.Key.from_identity_file ?use_sudo (Lazy.force !Config.identity_file)

  let refresh ?use_sudo ~verbose ?force secrets =
    let own_key = get_own_key ?use_sudo () in
    let skipped, refreshed, failed =
      List.fold_left
        (fun (skipped, refreshed, failed) secret ->
          let raw_secret_name = Secret_name.project secret in
          match refresh' ?use_sudo ?force secret own_key with
          | Succeeded () ->
            let () = verbose_eprintlf ~verbose "I: refreshed %s" raw_secret_name in
            skipped, refreshed + 1, failed
          | Skipped ->
            let () = verbose_eprintlf ~verbose "I: skipped %s" raw_secret_name in
            skipped + 1, refreshed, failed
          | Failed exn ->
            let () =
              verbose_eprintlf ~verbose "W: failed to refresh %s : %s" raw_secret_name (Printexc.to_string exn)
            in
            skipped, refreshed, failed + 1)
        (0, 0, 0) secrets
    in
    ksprintf prerr_endline "I: refreshed %d secrets, skipped %d, failed %d" refreshed skipped failed

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
      Succeeded ()
    with exn -> Failed exn

  let search ?use_sudo secret_name pattern =
    match is_recipient_of_secret (get_own_key ?use_sudo ()) secret_name with
    | false -> Skipped
    | true ->
    match decrypt_exn ~silence_stderr:true secret_name with
    | exception exn -> Failed exn
    | content ->
      let matched = Re.execp pattern content in
      Succeeded matched

  (** Returns a list with the keys that are recipients for the default identity file *)
  let recipients_of_own_id ?use_sudo () =
    Keys.all_recipient_names ()
    |> List.filter_map (fun name ->
      let keys = Keys.keys_of_recipient name in
      match List.mem (get_own_key ?use_sudo ()) keys with
      | true -> Some { Age.name; keys }
      | false -> None)
end
