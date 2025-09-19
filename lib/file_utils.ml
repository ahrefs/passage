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

let new_text_from_editor ?(initial = "") ?(name = "new") () =
  with_secure_tmpfile name (fun (tmpfile, tmpfile_oc) ->
      (* Write initial content if provided, but DON'T close the channel here.
         The with_secure_tmpfile function will close it properly. *)
      if initial <> "" then output_string tmpfile_oc initial;
      flush tmpfile_oc;
      (* Ensure data is written before editor opens *)
      (* Don't close tmpfile_oc here - let with_secure_tmpfile handle it *)
      let () = Shell.editor tmpfile in
      let ic = open_in tmpfile in
      let content = In_channel.input_all ic in
      close_in ic;
      content)
