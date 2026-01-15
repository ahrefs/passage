open Printf

let quote = Filename.quote

let run_cmd ?(stdin = Bos.OS.Cmd.in_stdin) ?(silence_stderr = false) ?(use_sudo = false) ~stdout raw_command =
  let stderr = if silence_stderr then Bos.OS.Cmd.err_null else Bos.OS.Cmd.err_stderr in
  let cmd = Bos.Cmd.(v "/bin/sh" % "-c" % raw_command) in
  let cmd = if use_sudo then Bos.Cmd.(v "sudo" %% cmd) else cmd in
  match stdin |> Bos.OS.Cmd.run_io ~err:stderr cmd |> stdout with
  | Ok (result, s) ->
    (match s with
    | _i, `Exited 0 -> result
    | _i, `Exited n -> Base.die "%s : exit code %d" raw_command n
    | _, `Signaled n -> Base.die "%s : stopped %d" raw_command n)
  | Error (`Msg m) -> Base.die "%s: %s" raw_command m

let run_cmd_stdout ?(silence_stderr = false) ?use_sudo raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      let stdout s = Bos.OS.Cmd.out_stdout s in
      run_cmd ~stdout ~silence_stderr ?use_sudo raw_cmd)
    raw_cmd_fmt

let run_cmd_string ?(silence_stderr = false) ?use_sudo raw_cmd_fmt =
  ksprintf (fun raw_cmd -> run_cmd ~stdout:Bos.OS.Cmd.out_string ~silence_stderr ?use_sudo raw_cmd) raw_cmd_fmt

let run_cmd_first_line ?(silence_stderr = false) ?use_sudo raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      let stdout s =
        match Bos.OS.Cmd.out_lines s with
        | Ok ([], status) -> Ok ("", status)
        | Ok (line :: _, status) -> Ok (line, status)
        | Error _ as e -> e
      in
      run_cmd ~stdout ~silence_stderr ?use_sudo raw_cmd)
    raw_cmd_fmt

let xclip_read_clipboard ?(x_selection = "clipboard") () =
  run_cmd_string ~silence_stderr:true "xclip -o -selection %s" (quote x_selection)

let xclip_copy_to_clipboard ?(x_selection = "clipboard") s =
  run_cmd_stdout {|printf "%%s" %s | xclip -selection %s|} (quote s) (quote x_selection)

let clear_clipboard_managers () =
  run_cmd_stdout ~silence_stderr:true "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory"

(* return success even if no processes were killed *)
let kill_processes proc_name = run_cmd_stdout ~silence_stderr:true "pkill -f %s || true" (quote @@ "^" ^ proc_name)

let die ?exn fmt =
  kfprintf
    (fun out ->
      (match exn with
      | None -> fprintf out "\n"
      | Some exn -> fprintf out " : %s\n" (Printexc.to_string exn));
      exit 1)
    stderr fmt

let age_generate_identity_key_root_group_exn ?use_sudo id_name =
  (* create dirs *)
  let base_dir = Lazy.force !Config.base_dir in
  let keys_dir = Filename.concat base_dir "keys" in
  let secrets_dir = Filename.concat base_dir "secrets" in
  FileUtil.mkdir ~parent:true base_dir;
  FileUtil.mkdir ~parent:true keys_dir;
  FileUtil.mkdir ~parent:true secrets_dir;
  (* create empty root group file *)
  let root_group_file = Filename.concat keys_dir "root.group" in
  FileUtil.touch root_group_file;
  (* create identity file and pub key *)
  let identity_file = quote @@ Filename.concat base_dir "identity.key" in
  let () = run_cmd_stdout ?use_sudo "age-keygen -o %s" identity_file in
  run_cmd_stdout ?use_sudo "age-keygen -y %s >> %s/%s.%s" identity_file (quote keys_dir) (quote id_name) "pub"

let age_get_recipient_key_from_identity_file ?use_sudo identity_file =
  run_cmd_first_line ?use_sudo "age-keygen -y %s" (quote identity_file)
