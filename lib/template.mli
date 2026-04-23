type t

val parse : string -> t
val parse_file : Path.t -> t
val substitute_all : substitute:(string -> (string, string) result) -> t -> (string, (string * string) list) result

(** Debug representation of the parsed template. *)
val dump : t -> string

(** The secret names in template. *)
val secrets : t -> string list
