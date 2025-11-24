module Init : sig
  val init : ?use_sudo:bool -> unit -> unit
end

module Get : sig
  val get_secret :
    ?use_sudo:bool ->
    ?expected_kind:Secret.kind ->
    ?line_number:int ->
    with_comments:bool ->
    ?trim_new_line:bool ->
    Storage.Secret_name.t ->
    string
end

module List_ : sig
  val list_secrets : Path.t -> unit
end

module Recipients : sig
  val add_recipients_if_none_exists : Age.recipient list -> Path.t -> unit
  val rewrite_recipients_file : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val add_recipients_to_secret : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val remove_recipients_from_secret : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val list_recipient_secrets : ?verbose:bool -> string list -> unit
  val list_recipients : Path.t -> bool -> unit
end

module Refresh : sig
  val refresh_secrets : ?use_sudo:bool -> ?verbose:bool -> Path.t list -> unit
end

module Template : sig
  val substitute : template:Template_ast.ast_node list -> string
  val substitute_file : template_file:Path.t -> string
  val list_template_secrets : Path.t -> string list
end

module Realpath : sig
  val realpath : Path.t list -> (string, string) result list
end

module Rm : sig
  val rm_secrets :
    verbose:bool -> paths:Path.t list -> force:'a -> f:(path:Path.t -> force:'a -> unit Storage.Secrets.outcome) -> unit
end

module Search : sig
  val search_secrets : ?verbose:bool -> Re2.t -> Path.t -> unit
end

module Show : sig
  val list_secrets_tree : Path.t -> string
end
