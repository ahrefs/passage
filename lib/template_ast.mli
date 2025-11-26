type ast_node =
  | Iden of string
  | Text of string

type ast = ast_node list

val to_string : ast_node -> string
