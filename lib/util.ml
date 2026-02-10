let printfn fmt = Printf.ksprintf print_endline fmt
let eprintfn fmt = Printf.ksprintf prerr_endline fmt

let verbose_eprintlf ?(verbose = false) fmt = Printf.ksprintf (fun s -> if verbose then prerr_endline s else ()) fmt

let save_as ?(mode = 0o644) ~path f =
  let temp = Printf.sprintf "%s.save.%d.tmp" path (Unix.getpid ()) in
  let fd = Unix.openfile temp [ Unix.O_WRONLY; Unix.O_CREAT ] mode in
  Fun.protect ~finally:(fun () -> Unix.close fd) @@ fun () ->
  try
    let ch = Unix.out_channel_of_descr fd in
    f ch;
    flush ch;
    Unix.fsync fd;
    Unix.rename temp path
  with exn ->
    (try Unix.unlink temp with _ -> ());
    raise exn

(** Display and conversion functions for paths and secret names *)
module Show = struct
  let show_path p = Path.project p

  let show_name name = Storage.Secret_name.project name

  let path_of_secret_name name = show_name name |> Path.inject

  let secret_name_of_path path = show_path path |> Storage.Secrets.build_secret_name
end

open Show

(** Recipients helper utilities for common patterns *)
module Recipients = struct
  (** Get recipients from secret name and handle "no recipients found" error *)
  let get_recipients_or_die secret_name =
    let recipients = Storage.Secrets.(get_recipients_from_path_exn @@ to_path secret_name) in
    match recipients with
    | [] ->
      Exn.die
        {|E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)|}
        (show_name secret_name)
    | _ -> recipients
end

(** Secret helper utilities for common patterns *)
module Secret = struct
  (** Decrypt and parse a secret in one operation *)
  let decrypt_and_parse ?use_sudo ?(silence_stderr = false) secret_name =
    let plaintext = Storage.Secrets.decrypt_exn ?use_sudo ~silence_stderr secret_name in
    Secret.Validation.parse_exn plaintext

  (** Reconstruct a secret from parsed secret and new comments *)
  let reconstruct_secret ?comments { Secret.kind; text; _ } =
    match kind with
    | Secret.Singleline -> Secret.singleline_from_text_description text (Option.value ~default:"" comments)
    | Secret.Multiline -> Secret.multiline_from_text_description text (Option.value ~default:"" comments)

  (** Check if a secret exists, die with hint about create/new if not *)
  let check_exists_or_die secret_name =
    match Storage.Secrets.secret_exists secret_name with
    | false -> Exn.die "E: no such secret: %s.  Use \"new\" or \"create\" for new secrets." (show_name secret_name)
    | true -> ()

  (** Check if a secret exists at path, die with standard error if not *)
  let check_path_exists_or_die secret_name path =
    match Storage.Secrets.secret_exists_at path with
    | false -> Exn.die "E: no such secret: %s" (show_name secret_name)
    | true -> ()

  (** Decrypt secret with silent stderr - common pattern *)
  let decrypt_silently ?use_sudo secret_name = Storage.Secrets.decrypt_exn ?use_sudo ~silence_stderr:true secret_name

  (** Common recipient error messages *)
  let die_no_recipients_found path = Exn.die "E: no recipients found for %s" (show_path path)

  let die_failed_get_recipients ?exn msg =
    match exn with
    | Some e -> Exn.die ~exn:e "E: failed to get recipients"
    | None -> Exn.die "E: failed to get recipients: %s" msg

  (** Create a secret with new text but keeping existing secret's comments *)
  let reconstruct_with_new_text ~is_singleline ~new_text ~existing_comments =
    let comments = Option.value ~default:"" existing_comments in
    match is_singleline with
    | true -> Secret.singleline_from_text_description new_text comments
    | false -> Secret.multiline_from_text_description new_text comments
end
