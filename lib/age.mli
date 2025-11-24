module Key : sig
  type t
  val inject : string -> t
  val project : t -> string
  val inject_list : string list -> t list
  val project_list : t list -> string list
  val compare : t -> t -> int
  val equal : t -> t -> bool
  val from_identity_file : ?use_sudo:bool -> string -> t
end
type recipient = {
  name : string;
  keys : Key.t list;
}

val ext : string
val recipient_compare : recipient -> recipient -> int
val is_group_recipient : string -> bool
val get_recipients_keys : recipient list -> Key.t list
val decrypt_string : ?use_sudo:bool -> identity_file:string -> silence_stderr:bool -> string -> string
val encrypt_string : ?use_sudo:bool -> recipients:recipient list -> string -> string
