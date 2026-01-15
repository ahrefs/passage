module Init : sig
  val init : ?use_sudo:bool -> unit -> unit
end

module Get : sig
  val get_secret :
    ?use_sudo:bool ->
    ?expected_kind:Secret.kind ->
    ?line_number:int ->
    ?with_comments:bool ->
    ?trim_new_line:bool ->
    Storage.Secret_name.t ->
    string
end

module List_ : sig
  val list_secrets : Path.t -> string list
end

module Recipients : sig
  val add_recipients_if_none_exists : Age.recipient list -> Path.t -> unit
  val rewrite_recipients_file : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val add_recipients_to_secret : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val remove_recipients_from_secret : ?use_sudo:bool -> Storage.Secret_name.t -> string list -> unit
  val list_recipient_secrets : ?use_sudo:bool -> ?verbose:bool -> string list -> unit
  val list_recipients : Path.t -> bool -> unit
end

module Refresh : sig
  val refresh_secrets : ?use_sudo:bool -> ?verbose:bool -> string list -> unit
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
  val rm_secrets : verbose:bool -> paths:Path.t list -> force:bool -> ?confirm:(path:Path.t -> bool) -> unit -> unit
end

module Search : sig
  val search_secrets : ?verbose:bool -> ?use_sudo:bool -> Re.re -> Path.t -> unit
end

module Show : sig
  val list_secrets_tree : Path.t -> string
end

module Edit : sig
  val show_recipients_notice_if_true : bool -> unit
  val edit_secret :
    ?use_sudo:bool ->
    ?self_fallback:bool ->
    ?verbose:bool ->
    ?allow_retry:(plaintext:string -> secret_name:Storage.Secret_name.t -> Age.recipient list -> unit) ->
    get_updated_secret:(string option -> (string, string) result) ->
    Storage.Secret_name.t ->
    unit
end

module Create : sig
  val add : ?use_sudo:bool -> comments:string option -> Storage.Secret_name.t -> string -> unit
  val bare : ?use_sudo:bool -> f:(Storage.Secret_name.t -> 'a) -> Storage.Secret_name.t -> 'a
end

module Replace : sig
  val replace_secret : Storage.Secret_name.t -> string -> unit
  val replace_comment : ?use_sudo:bool -> Storage.Secret_name.t -> (string option -> string) -> unit
end
