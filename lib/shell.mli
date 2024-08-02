val editor : string -> unit

val xclip_read_clipboard : string -> string

val xclip_copy_to_clipboard : string -> x_selection:string -> unit

val clear_clipboard_managers : unit -> unit

val die : ?exn:exn -> ('a, out_channel, unit, 'b) format4 -> 'a

val age_generate_identity_key_root_group_exn : string -> unit

val age_get_recipient_key_from_identity_file : string -> string

val age_encrypt : stdin:Unix.file_descr -> stdout:Unix.file_descr -> string list -> unit

val age_decrypt : stdin:Unix.file_descr -> stdout:Unix.file_descr -> ?stderr:Unix.file_descr -> string -> unit
