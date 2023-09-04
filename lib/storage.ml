open Devkit
open Printf

module SecretName = Devkit.Fresh (String) ()

module Keys = struct
  let base_dir = Config.keys_dir
  let ext = "pub"

  let key_file_of_recipient_name recipient_name =
    let base_key_file_name = FilePath.add_extension recipient_name ext in
    Filename.concat !!base_dir base_key_file_name |> Path.inject

  let get_keys key_file =
    match Path.file_exists key_file with
    | false -> []
    | true -> Action.config_lines (Path.project key_file) |> Age.Key.inject_list
end

module Secrets = struct
  type 'a outcome =
    | Succeeded of 'a
    | Failed of exn
    | Skipped

  let base_dir = Config.secrets_dir
  let ext = Age.ext
  let keys_filename = ".keys"

  let build_path rel_path =
    let realpath file = try ExtUnix.All.realpath file with Unix.Unix_error (Unix.ENOENT, _, _) -> file in
    let path = realpath (Filename.concat !!base_dir rel_path) in
    if not (String.starts_with path ~prefix:!!base_dir) then Exn.fail "the path is out of the secrets dir - %s" path;
    if not (FilePath.is_valid path) then Exn.fail "path is invalid - %s" path;
    Path.inject path

  let file_of_name name = build_path (FilePath.add_extension (SecretName.project name) ext)
  let name_of_file file =
    let fname = Path.project file in
    Stre.after fname (!!base_dir ^ Filename.dir_sep) |> FilePath.chop_extension |> SecretName.inject
  let secret_exist secret_name = file_of_name secret_name |> Path.file_exists
  let secret_exist_at path = FilePath.add_extension (Path.project path) ext |> Sys.file_exists

  let build_secret_name name =
    try
      let name = SecretName.inject name in
      let (_ : Path.t) = file_of_name name in
      name
    with FilePath.NoExtension filename -> Exn.fail "%s is not a valid secret" filename

  let get_secrets path =
    let path = Path.project path in
    FileUtil.find ~follow:Follow (Has_extension ext) path (fun accum f -> f :: accum) []
    |> Path.inject_list
    |> List.map name_of_file

  let get_secrets_for_recipient recipient_name =
    let rec get_secrets curr_dir prev_recipients accum =
      let dir_contents = Sys.readdir curr_dir |> Array.to_list |> List.map (Filename.concat curr_dir) in
      let keys_file = Filename.concat curr_dir keys_filename in
      let has_keys_file, secret_names, subdirs =
        List.fold_left
          (fun (has_keys_file, secret_names, subdirs) filename ->
            let has_keys_file' = has_keys_file || keys_file = filename in
            let secret_names', subdirs' =
              match FileUtil.(test (Has_extension ext) filename) with
              | true -> name_of_file (Path.inject filename) :: secret_names, subdirs
              | false ->
              match Sys.is_directory filename with
              | true -> secret_names, filename :: subdirs
              | false -> secret_names, subdirs
            in
            has_keys_file', secret_names', subdirs')
          (false, [], []) dir_contents
      in
      let recipients = if has_keys_file then Action.config_lines keys_file else prev_recipients in
      let accum' =
        match List.mem recipient_name recipients with
        | false -> accum
        | true -> List.rev_append accum secret_names
      in
      List.fold_left (fun accum subdir -> get_secrets subdir recipients accum) accum' subdirs
    in
    get_secrets !!base_dir [] []

  let get_recipients_from_path_exn path =
    let rec find_recipients_file curr_path =
      let recipients_file = Filename.concat curr_path keys_filename in
      match Sys.file_exists recipients_file with
      | true -> recipients_file
      | false ->
      match curr_path = !!base_dir with
      | true -> Exn.fail "%s doesn't exist, i.e. no keys specified for %s" curr_path curr_path
      | false -> find_recipients_file (Filename.dirname curr_path)
    in
    let read_recipients_file recipients_file =
      Action.config_lines recipients_file
      |> List.map (fun name ->
           let key_file = Keys.key_file_of_recipient_name name in
           let keys = Keys.get_keys key_file in
           Age.{ name; keys })
    in
    let recipients_file = find_recipients_file (Path.project path) in
    read_recipients_file recipients_file

  let get_recipients_from_name_exn secret_name =
    let secret_file = file_of_name secret_name in
    get_recipients_from_path_exn secret_file

  let is_recipient_of_secret key secret_name =
    let recipients = get_recipients_from_name_exn secret_name in
    let recipient_keys = Age.get_recipient_keys recipients in
    List.mem key recipient_keys

  (* Outputs encrypted text to a tmpfile first, before replacing the secret (if it already exists)
     with the tmpfile. This is to handle exceptional situations where the encryption is interrupted halfway.
  *)
  let encrypt_using_tmpfile ~secret_name ~encrypt_to_stdout =
    let secret_file = file_of_name secret_name in
    let temp_dir = Path.(dirname secret_file |> project) in
    let tmpfile_suffix = sprintf ".%s.tmp" (Path.basename secret_file) in
    let tmpfile, tmpfile_oc =
      Filename.open_temp_file ~mode:[ Open_creat; Open_wronly; Open_trunc ] ~perms:0o644 ~temp_dir "" tmpfile_suffix
    in
    let tmpfile_fd = Unix.descr_of_out_channel tmpfile_oc in
    let%lwt () = encrypt_to_stdout ~stdout:(`FD_move tmpfile_fd) in
    FileUtil.mv tmpfile (Path.project secret_file);
    Lwt.return_unit

  let encrypt_exn ~plaintext ~secret_name recipients =
    let secret_file = Path.project @@ file_of_name secret_name in
    let dir = Filename.dirname secret_file in
    FileUtil.mkdir ~parent:true dir;
    let%lwt () = encrypt_using_tmpfile ~secret_name ~encrypt_to_stdout:(Age.encrypt_to_stdout ~recipients ~plaintext) in
    Lwt.return_unit

  let decrypt_exn ?(silence_stderr = false) secret_name =
    let secret_file = Path.project @@ file_of_name secret_name in
    let fd = Unix.openfile secret_file [ O_RDONLY ] 0o400 in
    Age.decrypt_from_stdin ~identity_file:!!Config.identity_file ~stdin:(`FD_move fd) ~silence_stderr

  let refresh_exn secret_name self_key =
    match is_recipient_of_secret self_key secret_name with
    | false -> Lwt.return Skipped
    | true ->
      (try%lwt
         let fd_r, fd_w = Unix.pipe () in
         let%lwt () =
           let secret_file = file_of_name secret_name in
           let secret_fd = Unix.openfile (Path.project secret_file) [ O_RDONLY ] 0o400 in
           Age.decrypt_from_stdin_to_stdout ~identity_file:!!Config.identity_file ~stdin:(`FD_move secret_fd)
             ~silence_stderr:false ~stdout:(`FD_move fd_w)
         in
         let%lwt () =
           let recipients = get_recipients_from_name_exn secret_name in
           encrypt_using_tmpfile ~secret_name
             ~encrypt_to_stdout:(Age.encrypt_from_stdin_to_stdout ~recipients ~stdin:(`FD_move fd_r))
         in
         Lwt.return (Succeeded ())
       with exn -> Lwt.return @@ Failed exn)

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

  let with_secure_tmpfile ?parent ~prefix secret_name f =
    Lwt_io.with_temp_dir ~perm:0o700 ?parent:(Option.map Path.project parent) ~prefix:(sprintf "%s." prefix)
      (fun secure_tmpdir ->
      let suffix = sprintf "-%s.txt" (Stre.replace_all ~str:(SecretName.project secret_name) ~sub:"/" ~by:"-") in
      Lwt_io.with_temp_file ~temp_dir:secure_tmpdir ~suffix ~perm:0o600 f)
end
