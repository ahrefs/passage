(** Composable command validation - functions that can be chained with |> *)

(** Check that a secret exists and pass it through the pipeline *)
let require_secret_exists secret_name =
  Secret_helpers.check_exists_or_die secret_name;
  secret_name

(** Check that a path exists (directory or secret) and pass it through *)
let require_path_exists secret_name =
  let secret_path = Storage.Secrets.(to_path secret_name) in
  match Path.is_directory (Path.abs secret_path), Storage.Secrets.secret_exists_at secret_path with
  | false, false -> Shell.die "E: no such secret: %s" (Display.show_name secret_name)
  | _, true | true, _ -> secret_name

(** Add recipients to the pipeline context *)
let with_recipients secret_name =
  let recipients = Recipients_helpers.get_recipients_or_die secret_name in
  secret_name, recipients

(** Run operation with recipient permission check - terminal operation *)
let if_recipient ~op_string secret_name ~f =
  let path = Storage.Secrets.(to_path secret_name) in
  Invariant.run_if_recipient ~op_string ~path ~f:(fun () -> f secret_name)

(** Check that a secret exists with directory detection and pass it through *)
let require_secret_exists_with_directory_check secret_name =
  let secret_exists =
    try Storage.Secrets.secret_exists secret_name with exn -> Shell.die ~exn "E: %s" (Display.show_name secret_name)
  in
  match secret_exists with
  | false ->
    if Path.is_directory Storage.Secrets.(to_path secret_name |> Path.abs) then
      Shell.die "E: %s is a directory" (Display.show_name secret_name)
    else Shell.die "E: no such secret: %s" (Display.show_name secret_name)
  | true -> secret_name

(** Check that a path exists (secret or directory) and pass path and directory flag through *)
let require_path_exists_for_rm path =
  let is_directory = Path.is_directory (Path.abs path) in
  match Storage.Secrets.secret_exists_at path, is_directory with
  | false, false -> Shell.die "E: no secrets exist at %s" (Display.show_path path)
  | _ -> path, is_directory

type show_mode =
  | ShowSecret
  | ShowTree

(** Check path for show command - returns the path and what to show *)
let check_path_for_show path =
  let full_path = Path.abs path in
  match Path.is_directory full_path, Storage.Secrets.secret_exists_at path with
  | false, true -> path, ShowSecret
  | false, false -> Shell.die "No secrets at this path : %s" (Display.show_path full_path)
  | true, _ -> path, ShowTree

(** Check that a path has secrets (either a secret exists at path or path has secrets in subtree) *)
let require_path_has_secrets path =
  match Storage.Secrets.secret_exists_at path || Storage.Secrets.get_secrets_tree path <> [] with
  | false -> Shell.die "E: no such secret %s" (Display.show_path path)
  | true -> path

(** Check that secret doesn't exist, then run invariant check for create operations *)
let if_can_create ~op_string secret_name ~f =
  if Storage.Secrets.secret_exists secret_name then
    Shell.die "E: refusing to create: a secret by that name already exists"
  else (
    let path = Storage.Secrets.(to_path secret_name) in
    let%lwt () = Invariant.die_if_invariant_fails ~op_string path in
    f secret_name)

(** Run operation with recipient permission check, passing recipients - terminal operation *)
let if_recipient_with_data ~op_string (secret_name, recipients) ~f =
  let path = Storage.Secrets.(to_path secret_name) in
  Invariant.run_if_recipient ~op_string ~path ~f:(fun () -> f secret_name recipients)
