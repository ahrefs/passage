let home_dir = Sys.getenv "HOME"
let base_dir =
  Option.value (Sys.getenv_opt "PASSAGE_DIR")
    ~default:(List.fold_left (fun accum s -> Filename.concat accum s) home_dir [ ".config"; "passage" ])

(* Paths indicated by config values may not exist, and will result in an exn raised
   by ExtUnix.All.realpath. Therefore, we lazily evaluate these values so that exns
   are raised only when we do use these paths.
*)
let keys_dir =
  lazy (Option.value (Sys.getenv_opt "PASSAGE_KEYS") ~default:(Filename.concat base_dir "keys") |> ExtUnix.All.realpath)

let secrets_dir =
  lazy
    (Option.value (Sys.getenv_opt "PASSAGE_SECRETS") ~default:(Filename.concat base_dir "secrets")
    |> ExtUnix.All.realpath)

let identity_file =
  lazy
    (Option.value (Sys.getenv_opt "PASSAGE_IDENTITY") ~default:(Filename.concat base_dir "identity.key")
    |> ExtUnix.All.realpath)

let x_selection = Option.value (Sys.getenv_opt "PASSAGE_X_SELECTION") ~default:"clipboard"

let clip_time = Option.value (Sys.getenv_opt "PASSAGE_CLIP_TIME") ~default:"45" |> int_of_string
