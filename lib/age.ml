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

let encrypt_string ~recipients plaintext =
  let recipient_keys = get_recipients_keys recipients |> Key.project_list in
  Devkit.Control.with_open_out_temp_file ~temp_dir:(Filename.get_temp_dir_name ())
    ~mode:[ Open_wronly; Open_creat; Open_excl ] (fun (tmpfile, tmpfile_oc) ->
      output_string tmpfile_oc plaintext;
      close_out tmpfile_oc;
      Devkit.Control.with_open_out_temp_file ~temp_dir:(Filename.get_temp_dir_name ())
        ~mode:[ Open_wronly; Open_creat; Open_excl ] (fun (out_tmpfile, out_tmpfile_oc) ->
          close_out out_tmpfile_oc;
          let stdin = open_in tmpfile in
          let stdout = open_out out_tmpfile in
          Shell.age_encrypt ~stdin ~stdout recipient_keys;
          close_in stdin;
          close_out stdout;
          Devkit.Control.with_input_txt out_tmpfile IO.read_all))

let decrypt_string ~identity_file ~silence_stderr ciphertext =
  Devkit.Control.with_open_out_temp_file ~temp_dir:(Filename.get_temp_dir_name ())
    ~mode:[ Open_wronly; Open_creat; Open_excl ] (fun (tmpfile, tmpfile_oc) ->
      output_string tmpfile_oc ciphertext;
      close_out tmpfile_oc;
      Devkit.Control.with_open_out_temp_file ~temp_dir:(Filename.get_temp_dir_name ())
        ~mode:[ Open_wronly; Open_creat; Open_excl ] (fun (out_tmpfile, out_tmpfile_oc) ->
          close_out out_tmpfile_oc;
          let stdin = open_in tmpfile in
          let stdout = open_out out_tmpfile in
          let stderr = if silence_stderr then Some (open_out "/dev/null") else None in
          Shell.age_decrypt ~stdin ~stdout ?stderr identity_file;
          close_in stdin;
          close_out stdout;
          (match stderr with
          | Some oc -> close_out oc
          | None -> ());
          Devkit.Control.with_input_txt out_tmpfile IO.read_all))

let encrypt_from_stdin_to_stdout ~recipients ~stdin ~stdout =
  let recipient_keys = get_recipients_keys recipients |> Key.project_list in
  Shell.age_encrypt ~stdin ~stdout recipient_keys

let decrypt_from_stdin_to_stdout ~silence_stderr ~identity_file ~stdin ~stdout =
  match silence_stderr with
  | true ->
    Devkit.Control.with_open_out_bin "/dev/null" (fun stderr -> Shell.age_decrypt ~stdin ~stdout ~stderr identity_file)
  | false -> Shell.age_decrypt ~stdin ~stdout identity_file
