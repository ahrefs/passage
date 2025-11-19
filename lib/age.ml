module Key = struct
  include Devkit.Fresh (String) ()

  let from_identity_file f = inject @@ Shell.age_get_recipient_key_from_identity_file f
end

type recipient = {
  name : string;
  keys : Key.t list;
}

let ext = "age"

let recipient_compare a b = String.compare a.name b.name

let is_group_recipient r = String.starts_with ~prefix:"@" r

let get_recipients_keys recipients = List.concat_map (fun r -> r.keys) recipients

let decrypt_string ~identity_file ~silence_stderr ciphertext =
  let stdin = Bos.OS.Cmd.in_string ciphertext in
  let stdout = Bos.OS.Cmd.out_string ~trim:false in
  let raw_command = Printf.sprintf "age --decrypt --identity %s" (Filename.quote identity_file) in
  Shell.run_cmd ~stdin ~stdout ~silence_stderr raw_command

let encrypt_string ~recipients plaintext =
  let stdin = Bos.OS.Cmd.in_string plaintext in
  let stdout = Bos.OS.Cmd.out_string in
  let recipient_keys = get_recipients_keys recipients |> Key.project_list in
  let recipients_arg =
    List.map (fun key -> Printf.sprintf "--recipient %s" (Filename.quote key)) recipient_keys |> String.concat " "
  in
  let raw_command = Printf.sprintf "age --encrypt --armor %s" recipients_arg in
  Shell.run_cmd ~stdin ~stdout raw_command
