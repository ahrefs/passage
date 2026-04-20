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

let cmd_to_string cmd = Bos.Cmd.to_list cmd |> String.concat " "

let handle_run cmd = function
  | Ok (result, s) ->
    (match s with
    | _i, `Exited 0 -> result
    | _i, `Exited n -> Exn.die "%s : exit code %d" (cmd_to_string cmd) n
    | _, `Signaled n -> Exn.die "%s : stopped %d" (cmd_to_string cmd) n)
  | Error (`Msg m) -> Exn.die "%s: %s" (cmd_to_string cmd) m

let decrypt_string ?(use_sudo = false) ~identity_file ~silence_stderr ciphertext =
  let identity_file = Fpath.v identity_file in
  let stdin = Bos.OS.Cmd.in_string ciphertext in
  let stdout = Bos.OS.Cmd.out_string ~trim:false in
  let cmd = Bos.Cmd.(v "age" % "--decrypt" % "--identity" % p identity_file) in
  let cmd = if use_sudo then Bos.Cmd.(v "sudo" %% cmd) else cmd in
  let stderr = if silence_stderr then Bos.OS.Cmd.err_null else Bos.OS.Cmd.err_stderr in
  stdin |> Bos.OS.Cmd.run_io ~err:stderr cmd |> stdout |> handle_run cmd

let encrypt_string_to_file ?(use_sudo = false) ~recipients ~path plaintext =
  let path = Fpath.v path in
  let stdin = Bos.OS.Cmd.in_string plaintext in
  let stdout = Bos.OS.Cmd.out_null in
  let recipient_keys = get_recipients_keys recipients |> Key.project_list |> List.sort_uniq String.compare in
  let cmd =
    Bos.Cmd.(v "age" % "--encrypt" % "--armor" % "--output" % p path %% of_list ~slip:"--recipient" recipient_keys)
  in
  let cmd = if use_sudo then Bos.Cmd.(v "sudo" %% cmd) else cmd in
  stdin |> Bos.OS.Cmd.run_io cmd |> stdout |> handle_run cmd
