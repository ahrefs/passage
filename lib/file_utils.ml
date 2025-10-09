(** Secure file operations and temporary file utilities *)

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
    | Some p -> Display.show_path p
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
