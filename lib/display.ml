(** Display and conversion functions for paths and secret names *)

let show_path p = Path.project p

let show_name name = Storage.Secret_name.project name

let path_of_secret_name name = show_name name |> Path.inject

let secret_name_of_path path = show_path path |> Storage.Secrets.build_secret_name
