type t

val parse : string -> t
val parse_file : Path.t -> t
val substitute_all : substitute:(string -> (string, string) result) -> t -> (string, (string * string) list) result
val secrets : t -> string list

(** Debug representation of the parsed template. *)
val dump : t -> string
