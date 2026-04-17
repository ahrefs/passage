module Key = struct
  include Types.Fresh (String)
  let from_identity_file ?use_sudo f = inject (Shell.age_get_recipient_key_from_identity_file ?use_sudo f)
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

let encrypt_string_to_file ?(use_sudo = false) ~recipients ~path plaintext =
  let path = Fpath.v path in
  let stdin = Bos.OS.Cmd.in_string plaintext in
  let stdout = Bos.OS.Cmd.out_string in
  let recipient_keys = get_recipients_keys recipients |> Key.project_list |> List.sort_uniq String.compare in
  let cmd =
    Bos.Cmd.(v "age" % "--encrypt" % "--armor" % "--output" % p path %% of_list ~slip:"--recipient" recipient_keys)
  in
  let cmd = if use_sudo then Bos.Cmd.(v "sudo" %% cmd) else cmd in
  match stdin |> Bos.OS.Cmd.run_io cmd |> stdout with
  | Ok (_result, s) ->
    (match s with
    | _i, `Exited 0 -> ()
    | _i, `Exited n -> Exn.die "%s : exit code %d" (Bos.Cmd.to_string cmd) n
    | _, `Signaled n -> Exn.die "%s : stopped %d" (Bos.Cmd.to_string cmd) n)
  | Error (`Msg m) -> Exn.die "%s: %s" (Bos.Cmd.to_string cmd) m
