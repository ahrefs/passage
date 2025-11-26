val die_if_invariant_fails : ?use_sudo:bool -> op_string:string -> Path.t -> unit
val run_if_recipient : op_string:string -> path:Path.t -> f:(unit -> 'a) -> 'a
