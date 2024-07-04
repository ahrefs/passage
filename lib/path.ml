include Devkit.Fresh (String) ()

let is_directory p = try Sys.is_directory (project p) with Sys_error _ -> false

let file_exists p = Sys.file_exists (project p)

let of_fpath f = inject (Fpath.to_string f)

let to_fpath p = Fpath.v @@ project p

let access p = Unix.access (project p)

let basename p = Filename.basename (project p) |> inject

let dirname p = Filename.dirname (project p) |> inject

let concat p1 p2 = inject (Filename.concat (project p1) (project p2))

let is_dot p = project p = "."

let ensure_parent p =
  let p = dirname p in
  FileUtil.mkdir ~parent:true (project p);
  p

let build_rel_path rel_path =
  let path = Fpath.v rel_path in
  let normalized =
    (if Fpath.is_rel path then Fpath.append (Fpath.v "/") path else path)
    |> Fpath.normalize
    |> Fpath.rem_prefix (Fpath.v "/")
  in
  (* normalized "/." is "/" so that removing the prefix results in no path, so don't append in that case: *)
  match normalized with
  | None -> inject "."
  | Some p -> inject @@ Fpath.to_string p

let abs path = concat (inject (Lazy.force Config.secrets_dir)) (build_rel_path (project path))

let folder_of_path path = if is_directory (abs path) then path else dirname path
