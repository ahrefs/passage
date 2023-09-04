open Devkit
open Printf

let age = "age"

let quote = Filename.quote

let check_process_status raw_cmd status =
  let fail reason signum = Exn_lwt.fail "%s by signal %d: %s" reason signum raw_cmd in
  match status with
  | Unix.WEXITED 0 -> Lwt.return_unit
  | WEXITED code -> Exn_lwt.fail "%s : exit code %d" raw_cmd code
  | WSIGNALED signum -> fail "killed" signum
  | WSTOPPED signum -> fail "stopped" signum

let exec ?stdin ?stdout ?stderr raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      let cmd = Lwt_process.shell raw_cmd in
      let%lwt status = Lwt_process.exec ?stdin ?stdout ?stderr cmd in
      check_process_status raw_cmd status)
    raw_cmd_fmt

(* Reimplementation of Lwt_process.pread and Lwt_process.pread_line that throws exn when command fails to
   execute properly (https://github.com/ocsigen/lwt/issues/216)
*)
let read_sh_cmd_wrapper raw_cmd_fmt read =
  ksprintf
    (fun raw_cmd ->
      let cmd = Lwt_process.shell raw_cmd in
      Lwt_process.with_process_in cmd (fun p ->
        let%lwt status = p#status in
        let%lwt () = check_process_status raw_cmd status in
        read p#stdout))
    raw_cmd_fmt
let pread_sh_cmd raw_cmd_fmt = read_sh_cmd_wrapper raw_cmd_fmt Lwt_io.read
let pread_line_sh_cmd raw_cmd_fmt = read_sh_cmd_wrapper raw_cmd_fmt Lwt_io.read_line

let editor filename =
  let editor = Option.value (Sys.getenv_opt "EDITOR") ~default:"editor" in
  exec "%s %s" (quote editor) (quote filename)

let list_files_with_ext_and_strip_ext_tree ~path ~ext =
  (* remove ext at end of line, but keep colors *)
  let sed_arg = quote (sprintf {|s/\.%s(\x1B\[[0-9]+m)?( ->|$)/\1\2/g|} ext) in
  let file_pattern = sprintf "*%s" ext in
  exec "tree -a -P %s -C -l --noreport %s | sed -E %s" (quote file_pattern) (quote path) sed_arg

let xclip_read_clipboard x_selection = pread_sh_cmd "xclip -o -selection %s 2>/dev/null" (quote x_selection)

let xclip_copy_to_clipboard s ~x_selection =
  exec {|printf "%%s" %s | xclip -selection %s|} (quote s) (quote x_selection)

let clear_clipboard_managers () =
  exec "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null"

let sleep sleep_proc_name duration_s =
  exec {|( exec -a %s bash <<<"trap 'kill %%1' TERM; sleep '%d' & wait" )|} (quote sleep_proc_name) duration_s

(* return success even if no processes were killed *)
let kill_processes proc_name = exec "pkill -f %s 2>/dev/null || true" (quote @@ "^" ^ proc_name)

let age_get_recipient_key_from_identity_file identity_file = pread_line_sh_cmd "age-keygen -y %s" (quote identity_file)

let age_encrypt ~stdin ~stdout recipient_keys =
  let recipients_arg = List.map (fun key -> sprintf "--recipient %s" (quote key)) recipient_keys |> String.concat " " in
  exec ~stdin ~stdout "%s --encrypt --armor %s" age recipients_arg

let age_decrypt ~stdin ~stdout ?stderr identity_file =
  exec ~stdin ~stdout ?stderr "%s --decrypt --identity %s" age identity_file
