  $ . ./setup_fixtures.sh

Should succeed - users with secrets
  $ passage what bobby.bob
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  $ passage what robby.rob
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  $ passage what poppy.pop
  01/00/secret1
  01/00/secret2

Should succeed - users with no secrets
  $ passage what non.existent.user
  No secrets found for non.existent.user
