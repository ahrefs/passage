val editor : string -> unit

val xclip_read_clipboard : string -> string

val xclip_copy_to_clipboard : string -> x_selection:string -> unit

val clear_clipboard_managers : unit -> unit

val kill_processes : string -> unit

val die : ?exn:exn -> ('a, out_channel, unit, 'b) format4 -> 'a

val age_generate_identity_key_root_group_exn : string -> unit

val age_get_recipient_key_from_identity_file : string -> string

val age_encrypt : stdin:in_channel -> stdout:out_channel -> string list -> unit

val age_decrypt : stdin:in_channel -> stdout:out_channel -> ?stderr:out_channel -> string -> unit
