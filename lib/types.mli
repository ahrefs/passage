(** Abstract type generator.

    Copied from [Devkit.Prelude], which see. *)
module Fresh (T : sig
  type t
  val compare : t -> t -> int
end) : sig
  type t
  val inject : T.t -> t
  val project : t -> T.t
  val inject_list : T.t list -> t list
  val project_list : t list -> T.t list
  val compare : t -> t -> int
  val equal : t -> t -> bool
  val map : (T.t -> T.t) -> t -> t
  val map2 : (T.t -> T.t -> T.t) -> t -> t -> t
end
