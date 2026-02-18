type prompt_reply =
  | NoTTY
  | TTY of bool

val is_TTY : bool
val yesno : string -> bool
val yesno_tty_check : string -> prompt_reply
val input_help_if_user_input : ?msg:string -> unit -> unit
val get_valid_input_from_stdin_exn : unit -> (string, string) result
module Editor : sig
  val edit_with_validation : ?initial:string -> validate:(string -> ('a, string) result) -> unit -> ('a, string) result
end
val edit_recipients : Passage.Storage.Secret_name.t -> unit
