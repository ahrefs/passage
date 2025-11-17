val xclip_read_clipboard : string -> string

val xclip_copy_to_clipboard : string -> x_selection:string -> unit

val clear_clipboard_managers : unit -> unit

val kill_processes : string -> unit

val die : ?exn:exn -> ('a, out_channel, unit, 'b) format4 -> 'a

val age_generate_identity_key_root_group_exn : string -> unit

val age_get_recipient_key_from_identity_file : string -> string

val run_cmd :
  ?stdin:Bos.OS.Cmd.run_in ->
  ?silence_stderr:bool ->
  stdout:(Bos.OS.Cmd.run_out -> ('r * ('i * [< `Exited of int | `Signaled of int ]), [< `Msg of string ]) result) ->
  string ->
  'r
