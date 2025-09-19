open Printf

let age = "age"

let quote = Filename.quote

let check_process_status raw_cmd status =
  let fail reason signum = failwith (Printf.sprintf "%s by signal %d: %s" reason signum raw_cmd) in
  match status with
  | Unix.WEXITED 0 -> ()
  | WEXITED code -> failwith (Printf.sprintf "%s : exit code %d" raw_cmd code)
  | WSIGNALED signum -> fail "killed" signum
  | WSTOPPED signum -> fail "stopped" signum

let exec ?stdin ?stdout ?stderr raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      match stdin, stdout, stderr with
      | None, None, None ->
        let cmd = Bos.Cmd.(v "/bin/sh" % "-c" % raw_cmd) in
        (match Bos.OS.Cmd.run cmd with
        | Ok () -> ()
        | Error (`Msg _) ->
          (* Fall back to original Unix implementation for consistent error messages *)
          let status = Unix.system ("/bin/sh -c " ^ quote raw_cmd) in
          check_process_status raw_cmd status)
      | _ ->
        let status =
          let stdin_fd =
            match stdin with
            | None -> Unix.stdin
            | Some ic -> Unix.descr_of_in_channel ic
          in
          let stdout_fd =
            match stdout with
            | None -> Unix.stdout
            | Some oc -> Unix.descr_of_out_channel oc
          in
          let stderr_fd =
            match stderr with
            | None -> Unix.stderr
            | Some oc -> Unix.descr_of_out_channel oc
          in
          let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-c"; raw_cmd |] stdin_fd stdout_fd stderr_fd in
          (* Wait for process with proper error handling *)
          let rec wait_for_process () =
            try Unix.waitpid [] pid with Unix.Unix_error (Unix.EINTR, _, _) -> wait_for_process ()
          in
          let _, status = wait_for_process () in
          (* Ensure channels are flushed for proper synchronization *)
          (match stdout with
          | Some oc -> flush oc
          | None -> ());
          (match stderr with
          | Some oc -> flush oc
          | None -> ());
          status
        in
        check_process_status raw_cmd status)
    raw_cmd_fmt

let pread_sh_cmd raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      (* Use Bos for robust command execution with proper error handling *)
      let cmd = Bos.Cmd.(v "/bin/sh" % "-c" % raw_cmd) in
      match Bos.OS.Cmd.(run_out cmd |> to_string) with
      | Ok output -> output
      | Error (`Msg err) -> failwith err)
    raw_cmd_fmt
let pread_line_sh_cmd raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      let cmd = Bos.Cmd.(v "/bin/sh" % "-c" % raw_cmd) in
      match Bos.OS.Cmd.(run_out cmd |> to_lines) with
      | Ok [] -> ""
      | Ok (line :: _) -> line
      | Error (`Msg err) -> failwith err)
    raw_cmd_fmt

let editor filename =
  let editor = Option.value (Sys.getenv_opt "EDITOR") ~default:"editor" in
  exec "%s %s" (quote editor) (quote filename)

let xclip_read_clipboard x_selection = pread_sh_cmd "xclip -o -selection %s 2>/dev/null" (quote x_selection)

let xclip_copy_to_clipboard s ~x_selection =
  exec {|printf "%%s" %s | xclip -selection %s|} (quote s) (quote x_selection)

let clear_clipboard_managers () =
  exec "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null"

(* return success even if no processes were killed *)
let kill_processes proc_name = exec "pkill -f %s 2>/dev/null || true" (quote @@ "^" ^ proc_name)

let die ?exn fmt =
  kfprintf
    (fun out ->
      (match exn with
      | None -> fprintf out "\n"
      | Some exn -> fprintf out " : %s\n" (Devkit.Exn.to_string exn));
      exit 1)
    stderr fmt

let age_generate_identity_key_root_group_exn id_name =
  (* create dirs *)
  let keys_dir = Filename.concat Config.base_dir "keys" in
  let secrets_dir = Filename.concat Config.base_dir "secrets" in
  FileUtil.mkdir ~parent:true Config.base_dir;
  FileUtil.mkdir ~parent:true keys_dir;
  FileUtil.mkdir ~parent:true secrets_dir;
  (* create empty root group file *)
  let root_group_file = Filename.concat keys_dir "root.group" in
  FileUtil.touch root_group_file;
  (* create identity file and pub key *)
  let identity_file = Filename.concat Config.base_dir "identity.key" in
  let () = exec "age-keygen -o %s" identity_file in
  exec "age-keygen -y %s >> %s/%s.%s" identity_file keys_dir id_name "pub"

let age_get_recipient_key_from_identity_file identity_file = pread_line_sh_cmd "age-keygen -y %s" (quote identity_file)

let age_encrypt ~stdin ~stdout recipient_keys =
  let recipients_arg = List.map (fun key -> sprintf "--recipient %s" (quote key)) recipient_keys |> String.concat " " in
  exec ~stdin ~stdout "%s --encrypt --armor %s" age recipients_arg

let age_decrypt ~stdin ~stdout ?stderr identity_file =
  exec ~stdin ~stdout ?stderr "%s --decrypt --identity %s" age identity_file
