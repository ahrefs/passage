(** Secret helper utilities for common patterns *)

(** Decrypt and parse a secret in one operation *)
let decrypt_and_parse ?(silence_stderr = false) secret_name =
  let%lwt plaintext = Storage.Secrets.decrypt_exn ~silence_stderr secret_name in
  Lwt.return (Secret.Validation.parse_exn plaintext)

(** Reconstruct a secret from parsed secret and new comments *)
let reconstruct_secret ~comments { Secret.kind; text; _ } =
  match kind with
  | Secret.Singleline -> Secret.singleline_from_text_description text (Option.value ~default:"" comments)
  | Secret.Multiline -> Secret.multiline_from_text_description text (Option.value ~default:"" comments)

(** Check if a secret exists, die with standard error if not *)
let check_exists secret_name =
  match Storage.Secrets.secret_exists secret_name with
  | false -> Shell.die "E: no such secret: %s" (Display.show_name secret_name)
  | true -> ()

(** Check if a secret exists, die with hint about create/new if not *)
let check_exists_or_die secret_name =
  match Storage.Secrets.secret_exists secret_name with
  | false ->
    Shell.die "E: no such secret: %s.  Use \"new\" or \"create\" for new secrets." (Display.show_name secret_name)
  | true -> ()

(** Check if a secret exists at path, die with standard error if not *)
let check_path_exists_or_die secret_name path =
  match Storage.Secrets.secret_exists_at path with
  | false -> Shell.die "E: no such secret: %s" (Display.show_name secret_name)
  | true -> ()

(** Decrypt secret with silent stderr - common pattern *)
let decrypt_silently secret_name = Storage.Secrets.decrypt_exn ~silence_stderr:true secret_name

(** Common recipient error messages *)
let die_no_recipients_found path = Shell.die "E: no recipients found for %s" (Display.show_path path)

let die_failed_get_recipients ?exn msg =
  match exn with
  | Some e -> Shell.die ~exn:e "E: failed to get recipients"
  | None -> Shell.die "E: failed to get recipients: %s" msg

(** Create a secret with new text but keeping existing secret's comments *)
let reconstruct_with_new_text ~is_singleline ~new_text ~existing_comments =
  let comments = Option.value ~default:"" existing_comments in
  match is_singleline with
  | true -> Secret.singleline_from_text_description new_text comments
  | false -> Secret.multiline_from_text_description new_text comments
