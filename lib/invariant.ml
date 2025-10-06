let die ~op_string = Shell.die "E: refusing to %s: violates invariant" op_string

let get_expanded_recipient_names_from_folder path =
  try
    let recipients = Storage.Secrets.get_recipients_from_path_exn path in
    List.map (fun r -> r.Age.name) recipients |> List.sort_uniq String.compare
  with _ -> []

let error_not_recipient ~op_string path =
  let base_folder = Path.folder_of_path path in
  let () =
    Printf.eprintf "E: user is not a recipient of %s. Please ask one of the following to add you as a recipient:\n"
      (Display.show_path base_folder)
  in
  let expanded_recipients = get_expanded_recipient_names_from_folder base_folder in
  let () = List.iter (Printf.eprintf "  %s\n") expanded_recipients in
  die ~op_string

let user_is_listed_as_recipient path =
  let open Storage.Secrets in
  let folder_recipients = get_recipients_from_path_exn path in
  let own_recipients = recipients_of_own_id () in
  List.exists (fun (own_recipient : Age.recipient) -> List.mem own_recipient folder_recipients) own_recipients

let run_if_recipient ~op_string ~path ~f =
  match user_is_listed_as_recipient path with
  | false -> error_not_recipient ~op_string path
  | true -> f ()

let die_if_invariant_fails ~op_string path =
  let open Storage.Secrets in
  (* If the secret's folder doesn't exist yet or is empty, there's no invariant to check, allow the operation *)
  let full_path = path |> Path.folder_of_path |> Path.abs in
  if (not (Path.is_directory full_path)) || List.is_empty (FileUtil.ls (Path.project full_path)) then ()
  else (
    (* check if i am listed on the .keys file, return early *)
    let base_folder = Path.folder_of_path path in
    match user_is_listed_as_recipient path with
    | false -> error_not_recipient ~op_string path
    | true ->
      (* if i am listed on the .keys file, check if i can decrypt all the secrets in the folder *)
      let fails_invariant =
        List.exists
          (fun s ->
            try
              let (_decrypted : string) = Secret_helpers.decrypt_silently s in
              false
            with _e ->
              let () =
                Printf.eprintf
                  "E: user is recipient of %s, but failed to decrypt %s. Please ask some user to refresh the whole \
                   folder.\n"
                  (Display.show_path base_folder) (Display.show_name s)
              in
              true)
          (get_secrets_in_folder base_folder)
      in
      if fails_invariant then die ~op_string else ())
