(** Retry utilities for operations that may fail *)

let eprintlf = Printf.eprintf

(** Generic retry function for any operation *)
let rec retry_with_prompt ~operation ~error_message ~prompt_message =
  try operation ()
  with exn ->
    let () = eprintlf "%s: %s\n" error_message (Devkit.Exn.to_string exn) in
    let () = flush stderr in
    (match Prompt.yesno prompt_message with
    | false -> Shell.die "E: retry cancelled"
    | true -> retry_with_prompt ~operation ~error_message ~prompt_message)

(** Retry encryption operation with user prompt *)
let encrypt_with_retry ~plaintext ~secret_name recipients =
  retry_with_prompt
    ~operation:(fun () -> Storage.Secrets.encrypt_exn ~plaintext ~secret_name recipients)
    ~error_message:"Encryption failed" ~prompt_message:"Would you like to try again?"
