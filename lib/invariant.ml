let die ~op_string = Shell.die "E: refusing to %s: violates invariant" op_string

let user_is_listed_as_recipient path =
  let open Storage.Secrets in
  let folder_recipients = get_recipients_from_path_exn path in
  let own_recipients = recipients_of_own_id () in
  List.exists (fun (own_recipient : Age.recipient) -> List.mem own_recipient folder_recipients) own_recipients

let run_if_recipient ~op_string ~path ~f =
  match user_is_listed_as_recipient path with
  | false ->
    let show_path p = Path.project p in
    let base_folder = Path.folder_of_path path in
    Devkit.eprintfn "E: user is not a recipient of %s. Please ask someone to add you as a recipient."
      (show_path base_folder);
    die ~op_string
  | true -> f ()

let die_if_invariant_fails ~op_string path =
  let open Storage.Secrets in
  (* If the secret's folder doesn't exist yet or is empty, there's no invariant to check, allow the operation *)
  let full_path = path |> Path.folder_of_path |> Path.abs in
  if (not (Path.is_directory full_path)) || FileUtil.ls (Path.project full_path) = [] then ()
  else (
    (* check if i am listed on the .keys file, return early *)
    let show_path p = Path.project p in
    let show_name name = Storage.Secret_name.project name in
    let base_folder = Path.folder_of_path path in
    match user_is_listed_as_recipient path with
    | false ->
      Devkit.eprintfn "E: user is not a recipient of %s. Please ask someone to add you as a recipient."
        (show_path base_folder);
      die ~op_string
    | true ->
      (* if i am listed on the .keys file, check if i can decrypt all the secrets in the folder *)
      let fails_invariant =
        List.exists
          (fun s ->
            try
              let (_decrypted : string) = decrypt_exn ~silence_stderr:true s in
              false
            with _e ->
              Devkit.eprintfn
                "E: user is recipient of %s, but failed to decrypt %s. Please ask some user to refresh the whole \
                 folder."
                (show_path base_folder) (show_name s);
              true)
          (get_secrets_in_folder base_folder)
      in
      if fails_invariant then die ~op_string else ())
