module Key = struct
  type t = string

  let inject x = x
  let project x = x
  let inject_list = List.map inject
  let project_list = List.map project

  let from_identity_file ?use_sudo f = inject @@ Shell.age_get_recipient_key_from_identity_file ?use_sudo f
end

type recipient = {
  name : string;
  keys : Key.t list;
}

let ext = "age"

let recipient_compare a b = String.compare a.name b.name

let is_group_recipient r = String.starts_with ~prefix:"@" r

let get_recipients_keys recipients = List.concat_map (fun r -> r.keys) recipients

let decrypt_string ?use_sudo ~identity_file ~silence_stderr ciphertext =
  let stdin = Bos.OS.Cmd.in_string ciphertext in
  let stdout = Bos.OS.Cmd.out_string ~trim:false in
  let raw_command = Printf.sprintf "age --decrypt --identity %s" (Filename.quote identity_file) in
  Shell.run_cmd ~stdin ~silence_stderr ~stdout ?use_sudo raw_command

let encrypt_string ?use_sudo ~recipients plaintext =
  let stdin = Bos.OS.Cmd.in_string plaintext in
  let stdout = Bos.OS.Cmd.out_string in
  let recipient_keys = get_recipients_keys recipients |> Key.project_list in
  let recipients_arg =
    List.map (fun key -> Printf.sprintf "--recipient %s" (Filename.quote key)) recipient_keys |> String.concat " "
  in
  let raw_command = Printf.sprintf "age --encrypt --armor %s" recipients_arg in
  Shell.run_cmd ~stdin ~stdout ?use_sudo raw_command
