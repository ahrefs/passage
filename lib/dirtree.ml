open Printf
open Storage.Secrets

type t =
  | D of node list
  | F of unit outcome
and node = string * t

type top = Top of node

let self_key = lazy (Age.Key.from_identity_file @@ Lazy.force Config.identity_file)

(* always recurse on directories and keep files with extension [ext] *)
let ext_filt ext base nm sub =
  let full = Fpath.add_seg base nm in
  let s = Fpath.to_string full in
  try
    if Sys.is_directory s then (
      let sf = sub full in
      Some (nm, D sf))
    else if FileUtil.test FileUtil.Is_file s && Fpath.has_ext ext full then (
      let name = name_of_file (Path.of_fpath full) in
      let res =
        try
          let self_key = Lazy.force self_key in
          match is_recipient_of_secret self_key name with
          | false -> Skipped
          | true ->
            (match decrypt_exn ~silence_stderr:true name with
            | exception exn -> Failed exn
            | _ -> Succeeded ())
        with _ -> Skipped
      in
      Some (Fpath.(to_string @@ rem_ext (v nm)), F res))
    else None
  with _ -> None

let filt = ext_filt ext

let of_path path =
  let rec sub p =
    let names = Sys.readdir (Fpath.to_string p) in
    Array.sort compare names;
    names |> Array.to_list |> List.filter_map (fun v -> filt p v sub)
  in
  let sp = sub path in
  Top (Fpath.to_string path, D sp)

let bar = "│   "
let mid = "├── "
let el = "└── "
let space = "    "

let to_pref_str is_last_l =
  let rec p_aux acc d =
    match d with
    | [] -> String.concat "" acc
    | v :: rest -> p_aux ((if v then space else bar) :: acc) rest
  in
  match is_last_l with
  | v :: rest -> if v then p_aux [ el ] rest else p_aux [ mid ] rest
  | [] -> ""

let p d = Lwt_io.printf "%s%s\n" (to_pref_str d)

(* call a different function for the last item *)
let rec iter_but_one f lastf l =
  match l with
  | [] -> Lwt.return_unit
  | [ i ] -> lastf i
  | i :: rest ->
    let%lwt () = f i in
    iter_but_one f lastf rest

let red = "31"
let blue = "34"
let green = "32"

let color c s = sprintf "\027[01;%sm%s\027[00m" c s

let rec pp_node d n =
  match n with
  | nm, F r ->
    (match r with
    | Succeeded _ -> p d (color green nm)
    | Failed _ -> p d (color red nm)
    | _ -> p d nm)
  | nm, D nl ->
    let%lwt () = p d (color blue nm) in
    iter_but_one (pp_node (false :: d)) (pp_node (true :: d)) nl

let pp t =
  match t with
  | Top (_, D l) ->
    let%lwt () = Lwt_io.printl "." in
    iter_but_one (pp_node [ false ]) (pp_node [ true ]) l
  | Top (_, F _) -> Lwt.return_unit
