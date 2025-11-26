open Sedlexing
open Template_parser

module Encoding = Utf8

let lexeme = Encoding.lexeme

let iden_letter = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '_' | '-' | '/' | '.' | '0' .. '9']
let iden_fragment = [%sedlex.regexp? iden_letter, Star iden_letter]

let braces = [%sedlex.regexp? '{' | '}']
let text = [%sedlex.regexp? Plus (Compl braces)]

let iden lexbuf =
  match%sedlex lexbuf with
  | iden_fragment -> IDEN (lexeme lexbuf)
  | _ -> TEXT (lexeme lexbuf)

let close_iden lexbuf =
  match%sedlex lexbuf with
  | "}}}" -> lexeme lexbuf
  | _ -> lexeme lexbuf

let try_lex_iden open_tag lexbuf =
  let iden = iden lexbuf in
  match iden with
  | TEXT t -> TEXT (open_tag ^ t)
  | EOF -> Devkit.Exn.fail "expected non-EOF"
  | IDEN i ->
  match close_iden lexbuf with
  | "}}}" -> IDEN i
  | close -> TEXT (open_tag ^ i ^ close)

let token lexbuf =
  match%sedlex lexbuf with
  | "{{{" -> try_lex_iden (lexeme lexbuf) lexbuf
  | "{" | "}" | text -> TEXT (lexeme lexbuf)
  | eof -> EOF
  | _ -> Devkit.Exn.fail "unexpected chars: '%s'" (lexeme lexbuf)
