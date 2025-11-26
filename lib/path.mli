type t
val inject : string -> t
val project : t -> string
val inject_list : string list -> t list
val project_list : t list -> string list
val compare : t -> t -> int
val equal : t -> t -> bool
val is_directory : t -> bool
val file_exists : t -> bool
val of_fpath : Fpath.t -> t
val to_fpath : t -> Fpath.t
val access : t -> Unix.access_permission list -> unit
val basename : t -> t
val dirname : t -> t
val concat : t -> t -> t
val is_dot : t -> bool
val ensure_parent : t -> t
val build_rel_path : string -> t
val abs : t -> t
val folder_of_path : t -> t
