val printfn : ('a, unit, string, unit) format4 -> 'a
val eprintfn : ('a, unit, string, unit) format4 -> 'a
val verbose_eprintlf : ?verbose:bool -> ('a, unit, string, unit) format4 -> 'a

(** File output protected with atomic rename.

    [save_as path f] is similar to {!Out_channel.with_open_bin} except that writing is done to a temporary file that
    will be renamed to [path] after [f] has successfully terminated. This guarantees that either [path] is not modified
    or contains whatever [f] wrote to it.

    Based on Devkit's [Files.save_as]. *)
val save_as : ?mode:int -> path:string -> (out_channel -> unit) -> unit

module Show : sig
  val show_path : Path.t -> string
  val show_name : Storage.Secret_name.t -> string
  val path_of_secret_name : Storage.Secret_name.t -> Path.t
  val secret_name_of_path : Path.t -> Storage.Secret_name.t
end

module Recipients : sig
  val get_recipients_or_die : Storage.Secret_name.t -> Age.recipient list
end

module Secret : sig
  val decrypt_and_parse : ?use_sudo:bool -> ?silence_stderr:bool -> Storage.Secret_name.t -> Secret.t
  val reconstruct_secret : ?comments:string -> Secret.t -> string
  val check_exists_or_die : Storage.Secret_name.t -> unit
  val check_path_exists_or_die : Storage.Secret_name.t -> Path.t -> unit
  val decrypt_silently : ?use_sudo:bool -> Storage.Secret_name.t -> string
  val die_no_recipients_found : Path.t -> 'a
  val die_failed_get_recipients : ?exn:exn -> string -> 'a
  val reconstruct_with_new_text : is_singleline:bool -> new_text:string -> existing_comments:string option -> string
end
