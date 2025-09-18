(** Retry utilities for operations that may fail *)

let eprintlf = Lwt_io.eprintlf

(** Generic retry function for any operation *)
let rec retry_with_prompt ~operation ~error_message ~prompt_message =
  try%lwt operation ()
  with exn ->
    let%lwt () = eprintlf "%s: %s" error_message (Devkit.Exn.to_string exn) in
    let%lwt () = Lwt_io.(flush stderr) in
    (match%lwt Prompt.yesno prompt_message with
    | false -> Shell.die "E: retry cancelled"
    | true -> retry_with_prompt ~operation ~error_message ~prompt_message)

(** Retry encryption operation with user prompt *)
let encrypt_with_retry ~plaintext ~secret_name recipients =
  retry_with_prompt
    ~operation:(fun () -> Storage.Secrets.encrypt_exn ~plaintext ~secret_name recipients)
    ~error_message:"Encryption failed" ~prompt_message:"Would you like to try again?"
