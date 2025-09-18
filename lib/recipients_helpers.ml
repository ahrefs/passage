(** Recipients helper utilities for common patterns *)

(** Get recipients from secret name and handle "no recipients found" error *)
let get_recipients_or_die_with_hint secret_name =
  let recipients = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name) in
  match recipients with
  | [] ->
    Shell.die
      {|E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)|}
      (Display.show_name secret_name)
  | _ -> recipients

(** Get recipients from secret name, simplified without hint *)
let get_recipients_from_secret_name secret_name = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name)

(** Get recipients from path - direct wrapper *)
let get_recipients_for_path path = Storage.Secrets.get_recipients_from_path_exn path
