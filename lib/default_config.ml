let home_dir = lazy (Sys.getenv "HOME")
let base_dir =
  lazy
    (Option.value (Sys.getenv_opt "PASSAGE_DIR")
       ~default:(List.fold_left (fun accum s -> Filename.concat accum s) (Lazy.force home_dir) [ ".config"; "passage" ]))

(* Paths indicated by config values may not exist, and will result in an exn raised
   by ExtUnix.All.realpath. Therefore, we lazily evaluate these values so that exns
   are raised only when we do use these paths.
*)
let keys_dir =
  lazy
    (let path = Option.value (Sys.getenv_opt "PASSAGE_KEYS") ~default:(Filename.concat (Lazy.force base_dir) "keys") in
     try ExtUnix.All.realpath path
     with Unix.Unix_error (Unix.ENOENT, "realpath", _) ->
       Printf.ksprintf failwith "keys directory (%s) is not initialised. Is passage setup? Try 'passage init'." path)

let secrets_dir =
  lazy
    (let path =
       Option.value (Sys.getenv_opt "PASSAGE_SECRETS") ~default:(Filename.concat (Lazy.force base_dir) "secrets")
     in
     try ExtUnix.All.realpath path
     with Unix.Unix_error (Unix.ENOENT, "realpath", _) ->
       Printf.ksprintf failwith "secrets directory (%s) is not initialised. Is passage setup? Try 'passage init'." path)

let identity_file =
  lazy
    (let path =
       Option.value (Sys.getenv_opt "PASSAGE_IDENTITY") ~default:(Filename.concat (Lazy.force base_dir) "identity.key")
     in
     try ExtUnix.All.realpath path
     with Unix.Unix_error (Unix.ENOENT, "realpath", _) ->
       Printf.ksprintf failwith "no identity file found (%s). Is passage setup? Try 'passage init'." path)

let x_selection = Option.value (Sys.getenv_opt "PASSAGE_X_SELECTION") ~default:"clipboard"

let clip_time = Option.value (Sys.getenv_opt "PASSAGE_CLIP_TIME") ~default:"45" |> int_of_string
