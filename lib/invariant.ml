let die ~op_string = Shell.die "E: refusing to %s: violates invariant" op_string

let get_expanded_recipient_names_from_folder path =
  try
    let recipients = Storage.Secrets.get_recipients_from_path_exn path in
    List.map (fun r -> r.Age.name) recipients |> List.sort_uniq String.compare
  with _ -> []

let error_not_recipient ~op_string path =
  let base_folder = Path.folder_of_path path in
  let%lwt () =
    Lwt_io.eprintlf "E: user is not a recipient of %s. Please ask one of the following to add you as a recipient:"
      (Display.show_path base_folder)
  in
  let expanded_recipients = get_expanded_recipient_names_from_folder base_folder in
  let%lwt () = Lwt_list.iter_s (Lwt_io.eprintlf "  %s") expanded_recipients in
  die ~op_string

let user_is_listed_as_recipient path =
  let open Storage.Secrets in
  let folder_recipients = get_recipients_from_path_exn path in
  let%lwt own_recipients = recipients_of_own_id () in
  Lwt_list.exists_p
    (fun (own_recipient : Age.recipient) -> Lwt.return @@ List.mem own_recipient folder_recipients)
    own_recipients

let run_if_recipient ~op_string ~path ~f =
  match%lwt user_is_listed_as_recipient path with
  | false -> error_not_recipient ~op_string path
  | true -> f ()

let die_if_invariant_fails ~op_string path =
  let open Storage.Secrets in
  (* If the secret's folder doesn't exist yet or is empty, there's no invariant to check, allow the operation *)
  let full_path = path |> Path.folder_of_path |> Path.abs in
  if (not (Path.is_directory full_path)) || FileUtil.ls (Path.project full_path) = [] then Lwt.return_unit
  else (
    (* check if i am listed on the .keys file, return early *)
    let base_folder = Path.folder_of_path path in
    match%lwt user_is_listed_as_recipient path with
    | false -> error_not_recipient ~op_string path
    | true ->
      (* if i am listed on the .keys file, check if i can decrypt all the secrets in the folder *)
      let%lwt fails_invariant =
        Lwt_list.exists_s
          (fun s ->
            try%lwt
              let%lwt (_decrypted : string) = decrypt_exn ~silence_stderr:true s in
              Lwt.return false
            with _e ->
              let%lwt () =
                Lwt_io.eprintlf
                  "E: user is recipient of %s, but failed to decrypt %s. Please ask some user to refresh the whole \
                   folder."
                  (Display.show_path base_folder) (Display.show_name s)
              in
              Lwt.return true)
          (get_secrets_in_folder base_folder)
      in
      if fails_invariant then die ~op_string else Lwt.return_unit)
