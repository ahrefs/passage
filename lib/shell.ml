open Printf

let age = "age"

let quote = Filename.quote

let shell cmd = if Sys.win32 then [| "cmd.exe"; "/c"; "\000" ^ cmd |] else [| "/bin/sh"; "-c"; cmd |]

let check_process_status_sync raw_cmd status =
  let fail reason signum = Devkit.Exn.fail "%s by signal %d: %s" reason signum raw_cmd in
  match status with
  | Unix.WEXITED 0 -> ()
  | WEXITED code -> Devkit.Exn.fail "%s : exit code %d" raw_cmd code
  | WSIGNALED signum -> fail "killed" signum
  | WSTOPPED signum -> fail "stopped" signum

let exec_sync ?stdin ?stdout ?stderr raw_cmd_fmt =
  Printf.ksprintf
    (fun raw_cmd ->
      let in_fd = Option.value ~default:Unix.stdin stdin in
      let out_fd = Option.value ~default:Unix.stdout stdout in
      let err_fd = Option.value ~default:Unix.stderr stderr in
      let prog = shell raw_cmd in
      let pid = Unix.create_process "sh" prog in_fd out_fd err_fd in
      List.iter (fun fd -> Option.iter (fun fd -> Unix.close fd) fd) [ stdin; stdout; stderr ];
      let _, status = Unix.waitpid [] pid in
      check_process_status_sync raw_cmd status)
    raw_cmd_fmt

let check_process_status raw_cmd status =
  let fail reason signum = Devkit.Exn_lwt.fail "%s by signal %d: %s" reason signum raw_cmd in
  match status with
  | Unix.WEXITED 0 -> Lwt.return_unit
  | WEXITED code -> Devkit.Exn_lwt.fail "%s : exit code %d" raw_cmd code
  | WSIGNALED signum -> fail "killed" signum
  | WSTOPPED signum -> fail "stopped" signum

let exec ?stdin ?stdout ?stderr raw_cmd_fmt =
  ksprintf
    (fun raw_cmd ->
      let cmd = Lwt_process.shell raw_cmd in
      let%lwt status = Lwt_process.exec ?stdin ?stdout ?stderr cmd in
      check_process_status raw_cmd status)
    raw_cmd_fmt

let read_sh_cmd_wrapper_sync raw_cmd_fmt read =
  Printf.ksprintf
    (fun raw_cmd ->
      let in_read, in_write = Unix.pipe () in
      let prog = shell raw_cmd in
      let pid = Unix.(create_process "sh" prog stdin in_write stderr) in
      Unix.close in_write;
      let ic = Unix.in_channel_of_descr in_read in
      let result = read ic in
      close_in ic;
      let _, status = Unix.waitpid [] pid in
      check_process_status_sync raw_cmd status;
      result)
    raw_cmd_fmt

let pread_sh_cmd_sync raw_cmd_fmt = read_sh_cmd_wrapper_sync raw_cmd_fmt In_channel.input_all

(* let pread_sh_cmd_sync raw_cmd_fmt =
   read_sh_cmd_wrapper_sync raw_cmd_fmt (fun in_read ->
       let buf = Buffer.create 1024 in
       let rec read_all () =
         let bytes = Bytes.create 1024 in
         let n = Unix.read in_read bytes 0 1024 in
         if n > 0 then (
           Buffer.add_subbytes buf bytes 0 n;
           read_all ())
       in
       read_all ();
       Buffer.contents buf) *)

let pread_line_sh_cmd_sync raw_cmd_fmt = read_sh_cmd_wrapper_sync raw_cmd_fmt input_line

(* let pread_line_sh_cmd_sync raw_cmd_fmt =
   read_sh_cmd_wrapper_sync raw_cmd_fmt (fun in_read ->
       let buf = Buffer.create 1024 in
       let rec read_line () =
         let bytes = Bytes.create 1 in
         let n = Unix.read in_read bytes 0 1 in
         if n > 0 && Bytes.get bytes 0 <> '\n' then (
           Buffer.add_subbytes buf bytes 0 n;
           read_line ())
       in
       read_line ();
       Buffer.contents buf) *)

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
  exec_sync "%s %s" (quote editor) (quote filename)

let xclip_read_clipboard x_selection = pread_sh_cmd "xclip -o -selection %s 2>/dev/null" (quote x_selection)

let xclip_copy_to_clipboard s ~x_selection =
  exec_sync {|printf "%%s" %s | xclip -selection %s|} (quote s) (quote x_selection)

let clear_clipboard_managers () =
  exec_sync "qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null"

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
  let%lwt () = exec "age-keygen -o %s" identity_file in
  exec "age-keygen -y %s >> %s/%s.%s" identity_file keys_dir id_name "pub"

let age_get_recipient_key_from_identity_file identity_file = pread_line_sh_cmd "age-keygen -y %s" (quote identity_file)

let age_encrypt ~stdin ~stdout recipient_keys =
  let recipients_arg = List.map (fun key -> sprintf "--recipient %s" (quote key)) recipient_keys |> String.concat " " in
  exec ~stdin ~stdout "%s --encrypt --armor %s" age recipients_arg

let age_decrypt ~stdin ~stdout ?stderr identity_file =
  exec ~stdin ~stdout ?stderr "%s --decrypt --identity %s" age identity_file
