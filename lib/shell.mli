val editor : string -> unit Lwt.t
val list_files_with_ext_and_strip_ext_tree : path:string -> ext:string -> unit Lwt.t
val xclip_read_clipboard : string -> string Lwt.t
val xclip_copy_to_clipboard : string -> x_selection:string -> unit Lwt.t
val clear_clipboard_managers : unit -> unit Lwt.t
val sleep : string -> int -> unit Lwt.t
val kill_processes : string -> unit Lwt.t
val age_get_recipient_key_from_identity_file : string -> string Lwt.t
val age_encrypt : stdin:Lwt_process.redirection -> stdout:Lwt_process.redirection -> string list -> unit Lwt.t
val age_decrypt :
  stdin:Lwt_process.redirection ->
  stdout:Lwt_process.redirection ->
  ?stderr:Lwt_process.redirection ->
  string ->
  unit Lwt.t
