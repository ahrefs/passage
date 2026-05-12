type t = {
  name : string;
  path : Path.t;
}

let root = { name = "."; path = Path.root }

let of_string name = { name; path = Path.build_rel_path name }
let of_secret_name secret_name = Storage.Secret_name.project secret_name |> of_string
let of_path path = { name = Path.project path; path }

let show { name; _ } = name
let path { path; _ } = path
let pp fmt p = Format.fprintf fmt "%s" (show p)
