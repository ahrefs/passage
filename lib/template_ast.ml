open Printf

type ast_node =
  | Iden of string
  | Text of string

type ast = ast_node list

let to_string node =
  match node with
  | Iden s -> sprintf "Iden(%S)" s
  | Text s -> sprintf "Text(%S)" s
