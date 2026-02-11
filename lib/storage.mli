(** File output protected with atomic rename.

    [save_as path f] is similar to {!Out_channel.with_open_bin} except that writing is done to a temporary file that
    will be renamed to [path] after [f] has successfully terminated. This guarantees that either [path] is not modified
    or contains whatever [f] wrote to it.

    Mode, if absent, defaults to [0o644].

    Based on Devkit's [Files.save_as]. *)
val save_as : ?mode:int -> path:string -> (out_channel -> unit) -> unit

module Secret_name : sig
  type t

  val inject : string -> t
  val project : t -> string
  val compare : t -> t -> int
  val equal : t -> t -> bool

  val norm_secret : t -> t
end

module Keys : sig
  val keys_of_recipient : string -> Age.Key.t list
  val all_recipient_names : unit -> string list
end

module Secrets : sig
  type 'a outcome =
    | Succeeded of 'a
    | Failed of exn
    | Skipped

  val get_secrets_dir : unit -> string
  val get_own_key : ?use_sudo:bool -> unit -> Age.Key.t
  val ext : string
  val to_path : Secret_name.t -> Path.t
  val agefile_of_name : Secret_name.t -> Path.t
  val name_of_file : Path.t -> Secret_name.t
  val secret_exists : Secret_name.t -> bool
  val secret_exists_at : Path.t -> bool
  val build_secret_name : string -> Secret_name.t
  val get_secrets_tree : Path.t -> Secret_name.t list
  val get_secrets_in_folder : Path.t -> Secret_name.t list
  val all_paths : unit -> Path.t list
  val has_secret_no_keys : Path.t -> bool
  val no_keys_file : Path.t -> bool
  val all_groups_names : unit -> string list
  val recipient_of_name : string -> Age.recipient
  val recipients_of_group_name_exn : map_fn:(string -> 'a) -> string -> 'a list
  val get_secrets_for_recipient : string -> Secret_name.t list
  val get_recipients_file_path : Path.t -> Path.t
  val get_recipients_names : Path.t -> string list
  val get_recipients_from_path_exn : Path.t -> Age.recipient list
  val is_recipient_of_secret : Age.Key.t -> Secret_name.t -> bool
  val encrypt_exn :
    ?use_sudo:bool -> ?verbose:bool -> plaintext:string -> secret_name:Secret_name.t -> Age.recipient list -> unit
  val decrypt_exn : ?use_sudo:bool -> ?silence_stderr:bool -> Secret_name.t -> string
  val refresh : ?use_sudo:bool -> verbose:bool -> ?force:bool -> Secret_name.t list -> unit
  val rm : is_directory:bool -> Path.t -> unit outcome
  val search : ?use_sudo:bool -> Secret_name.t -> Re.re -> bool outcome
  val recipients_of_own_id : ?use_sudo:bool -> unit -> Age.recipient list
end
