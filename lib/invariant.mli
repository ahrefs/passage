val die_if_invariant_fails : op_string:string -> Path.t -> unit
val run_if_recipient : op_string:string -> path:Path.t -> f:(unit -> 'a) -> 'a

module With_config (Config : Types.Config) : sig
  val die_if_invariant_fails : op_string:string -> Path.t -> unit
  val run_if_recipient : op_string:string -> path:Path.t -> f:(unit -> 'a) -> 'a
end
(* We need to silence the warning 67 due to unused Config module argument. We use it in the implementation only *)
[@@ocaml.warning "-67"]
