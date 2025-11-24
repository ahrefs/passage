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
  val decrypt_and_parse : ?silence_stderr:bool -> Storage.Secret_name.t -> Secret.t
  val reconstruct_secret : comments:string option -> Secret.t -> string
  val check_exists_or_die : Storage.Secret_name.t -> unit
  val check_path_exists_or_die : Storage.Secret_name.t -> Path.t -> unit
  val decrypt_silently : Storage.Secret_name.t -> string
  val die_no_recipients_found : Path.t -> 'a
  val die_failed_get_recipients : ?exn:exn -> string -> 'a
  val reconstruct_with_new_text : is_singleline:bool -> new_text:string -> existing_comments:string option -> string
end

val die : ?exn:exn -> ('a, unit, string, 'b) format4 -> 'a
val verbose_eprintlf : ?verbose:bool -> ('a, unit, string, unit) format4 -> 'a
