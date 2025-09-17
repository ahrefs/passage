(** Secure file operations and temporary file utilities *)

open Printf

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
  Lwt_io.with_temp_dir ~perm:0o700 ?parent:(Option.map Display.show_path parent) ~prefix:(sprintf "%s." program)
    (fun secure_tmpdir ->
      let suffix = sprintf "-%s.txt" (Devkit.Stre.replace_all ~str:suffix ~sub:"/" ~by:"-") in
      Lwt_io.with_temp_file ~temp_dir:secure_tmpdir ~suffix ~perm:0o600 f)