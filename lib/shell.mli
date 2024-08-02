val editor : string -> unit Lwt.t

val xclip_read_clipboard : string -> string Lwt.t

val xclip_copy_to_clipboard : string -> x_selection:string -> unit

val clear_clipboard_managers : unit -> unit

val die : ?exn:exn -> ('a, out_channel, unit, 'b) format4 -> 'a

val age_generate_identity_key_root_group_exn : string -> unit Lwt.t

val age_get_recipient_key_from_identity_file : string -> string Lwt.t

val age_encrypt : stdin:Lwt_process.redirection -> stdout:Lwt_process.redirection -> string list -> unit Lwt.t

val age_decrypt :
  stdin:Lwt_process.redirection ->
  stdout:Lwt_process.redirection ->
  ?stderr:Lwt_process.redirection ->
  string ->
  unit Lwt.t
