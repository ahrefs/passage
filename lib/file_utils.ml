(** Secure file operations and temporary file utilities *)

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

let with_secure_tmpfile _suffix f =
  let parent = Lazy.force shm_check in
  let temp_dir =
    match parent with
    | Some p -> Display.show_path p
    | None -> Filename.get_temp_dir_name ()
  in
  Devkit.Control.with_open_out_temp_file ~temp_dir ~mode:[ Open_wronly; Open_creat; Open_excl ]
    (fun (tmpfile_path, tmpfile_oc) -> f (tmpfile_path, tmpfile_oc))

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

(* Unified editor abstraction with validation and retry *)
let edit_with_validation ?(initial = "") ~name ~validate () =
  with_secure_tmpfile name (fun (tmpfile, tmpfile_oc) ->
      (* Write initial content and close to make available to editor *)
      if initial <> "" then output_string tmpfile_oc initial;
      close_out tmpfile_oc;

      match edit_loop tmpfile with
      | false -> Error "Editor cancelled"
      | true ->
        let rec validate_and_edit () =
          let raw_content = Devkit.Control.with_input_txt tmpfile IO.read_all in
          let processed_content = Prompt.preprocess_content raw_content in
          match validate processed_content with
          | Ok result -> result
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
