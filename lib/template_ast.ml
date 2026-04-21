type ast_node =
  | Iden of string
  | Text of string

type ast = ast_node list

let to_string node =
  match node with
  | Iden s -> "[[[" ^ String.uppercase_ascii s ^ "]]]"
  | Text s -> s
