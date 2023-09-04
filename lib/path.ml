include Devkit.Fresh (String) ()

let is_directory p = try Sys.is_directory (project p) with Sys_error _ -> false

let file_exists p = Sys.file_exists (project p)

let access p = Unix.access (project p)

let basename p = Filename.basename (project p)

let dirname p = Filename.dirname (project p) |> inject

let concat p1 p2 = Filename.concat (project p1) (project p2)
