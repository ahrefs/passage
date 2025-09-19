module Key = struct
  include Devkit.Fresh (String) ()

  let from_identity_file f =
    let key = Shell.age_get_recipient_key_from_identity_file f in
    inject key
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
  try
    let bytes = Bytes.of_string plaintext in
    let (_ : int) = Unix.write fd_w bytes 0 (Bytes.length bytes) in
    Unix.close fd_w;
    let stdin_channel = Unix.in_channel_of_descr fd_r in
    try
      encrypt_from_stdin_to_stdout ~recipients ~stdin:stdin_channel ~stdout;
      close_in stdin_channel
    with exn ->
      close_in_noerr stdin_channel;
      raise exn
  with exn ->
    Unix.close fd_w;
    Unix.close fd_r;
    raise exn

let decrypt_from_stdin_to_stdout ~silence_stderr ~identity_file ~stdin ~stdout =
  let stderr =
    match silence_stderr with
    | true -> Some (open_out "/dev/null")
    | false -> None
  in
  Shell.age_decrypt ~stdin ~stdout ?stderr identity_file;
  Option.iter close_out stderr

let decrypt_from_stdin ~silence_stderr ~identity_file ~stdin =
  let fd_r, fd_w = Unix.pipe () in
  try
    let stdout_channel = Unix.out_channel_of_descr fd_w in
    try
      let () = decrypt_from_stdin_to_stdout ~silence_stderr ~identity_file ~stdin ~stdout:stdout_channel in
      close_out stdout_channel;
      let stdin_channel = Unix.in_channel_of_descr fd_r in
      try
        let buf = Buffer.create 4096 in
        let chunk = Bytes.create 4096 in
        let rec loop () =
          try
            let n = input stdin_channel chunk 0 4096 in
            if n = 0 then Buffer.contents buf
            else (
              Buffer.add_subbytes buf chunk 0 n;
              loop ())
          with End_of_file -> Buffer.contents buf
        in
        let plaintext = loop () in
        close_in stdin_channel;
        plaintext
      with exn ->
        close_in_noerr stdin_channel;
        raise exn
    with exn ->
      close_out_noerr stdout_channel;
      Unix.close fd_r;
      raise exn
  with exn ->
    Unix.close fd_w;
    Unix.close fd_r;
    raise exn
