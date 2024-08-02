type t =
  | D of node list
  | F of unit Storage.Secrets.outcome
and node = string * t
type top = Top of node
val of_path : Fpath.t -> top
val pp : top -> unit
