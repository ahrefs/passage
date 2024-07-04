  $ . ./setup_fixtures.sh

Extract secret names from a string
  $ echo "{{{01/00/secret}}}" > template
  $ passage template-secrets template
  01/00/secret

Extract multiple secret names from a string
  $ echo "{{{01/00/secret}}}{{{random}}}" > template
  $ passage template-secrets template
  01/00/secret
  random

Non-existent template file
  $ passage template-secrets no_such_file
  Failed to parse the file : Sys_error("no_such_file: No such file or directory")
  [1]

