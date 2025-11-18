type t =
  | D of node list
  | F of unit Storage.Secrets.outcome
and node = string * t
type top = Top of node
val of_path : Fpath.t -> top
val pp : top -> string

module With_config (Config : Types.Config) : sig
  type t =
    | D of node list
    | F of unit Storage.Secrets.outcome
  and node = string * t
  type top = Top of node
  val of_path : Fpath.t -> top
  val pp : top -> string
end
(* We need to silence the warning 67 due to unused Config module argument. We use it in the implementation only *)
[@@ocaml.warning "-67"]
