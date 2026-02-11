open Printf
open Printexc

let () =
  Printexc.register_printer (function
    | Unix.Unix_error (e, f, s) -> Some (sprintf "Unix_error %s(%s) %s" f s (Unix.error_message e))
    | _exn -> None)

(** The original backtrace is captured via `Printexc.get_raw_backtrace ()`. However, note that this backtrace might not
    correspond to the provided `exn` if another exception was raised before `fail` is called. *)
let die ?exn fmt =
  let fails s =
    match exn with
    | None -> failwith s
    | Some original_exn ->
      let orig_bt = get_raw_backtrace () in
      let exn = Failure (sprintf "%s: %s" s (to_string original_exn)) in
      raise_with_backtrace exn orig_bt
  in
  ksprintf fails fmt
