type kind =
  | Singleline
  | Multiline

type t = {
  kind : kind;
  text : string;
  comments : string option;
}

module Validation : sig
  type validation_error =
    | SingleLineLegacy
    | MultilineEmptySecret
    | EmptySecret
    | InvalidFormat

  val validate : string -> (kind, string * validation_error) result
  val parse_exn : string -> t
  val validity_to_string : string -> string -> string
end

val kind_to_string : kind -> string
val singleline_from_text_description : string -> string -> string
val multiline_from_text_description : string -> string -> string
val format_explainer : string
