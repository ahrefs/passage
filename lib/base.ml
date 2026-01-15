let printfn fmt = Printf.ksprintf print_endline fmt
let eprintfn fmt = Printf.ksprintf prerr_endline fmt

let verbose_eprintlf ?(verbose = false) fmt = Printf.ksprintf (fun s -> if verbose then prerr_endline s else ()) fmt

let die ?exn fmt =
  Printf.ksprintf
    (fun s ->
      let s =
        match exn with
        | None -> s
        | Some exn -> s ^ ": " ^ Printexc.to_string exn
      in
      failwith s)
    fmt
