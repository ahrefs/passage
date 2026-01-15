val printfn : ('a, unit, string, unit) format4 -> 'a
val eprintfn : ('a, unit, string, unit) format4 -> 'a
val verbose_eprintlf : ?verbose:bool -> ('a, unit, string, unit) format4 -> 'a
val die : ?exn:exn -> ('a, unit, string, 'b) format4 -> 'a
