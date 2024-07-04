module Key = struct
  include Devkit.Fresh (String) ()

  let from_identity_file f =
    let%lwt key = Shell.age_get_recipient_key_from_identity_file f in
    Lwt.return @@ inject key
end

type recipient = {
  name : string;
  keys : Key.t list;
}

let ext = "age"

let recipient_compare a b = String.compare a.name b.name

let is_group_recipient r = String.starts_with ~prefix:"@" r

let get_recipients_keys recipients = List.concat_map (fun r -> r.keys) recipients

let encrypt_from_stdin_to_stdout ~recipients ~stdin ~stdout =
  let recipient_keys = get_recipients_keys recipients |> Key.project_list in
  Shell.age_encrypt ~stdin ~stdout recipient_keys

let encrypt_to_stdout ~recipients ~plaintext ~stdout =
  let fd_r, fd_w = Unix.pipe () in
  let bytes = Bytes.of_string plaintext in
  let (_ : int) = Unix.write fd_w bytes 0 (Bytes.length bytes) in
  Unix.close fd_w;
  encrypt_from_stdin_to_stdout ~recipients ~stdin:(`FD_move fd_r) ~stdout

let decrypt_from_stdin_to_stdout ~silence_stderr ~identity_file ~stdin ~stdout =
  let stderr =
    match silence_stderr with
    | true -> Some `Dev_null
    | false -> None
  in
  Shell.age_decrypt ~stdin ~stdout ?stderr identity_file

let decrypt_from_stdin ~silence_stderr ~identity_file ~stdin =
  let fd_r, fd_w = Unix.pipe () in
  let%lwt () = decrypt_from_stdin_to_stdout ~silence_stderr ~identity_file ~stdin ~stdout:(`FD_move fd_w) in
  let%lwt plaintext = Lwt_io.(read (of_unix_fd ~mode:Input fd_r)) in
  Unix.close fd_r;
  Lwt.return plaintext
