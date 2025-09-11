  $ . ./setup_fixtures.sh

Should succeed - users with secrets. Shows secrets for @everyone too
  $ passage what bobby.bob
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  02/secret1
  04/secret1
  $ passage what robby.rob
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  03/secret1
  04/secret1
  $ passage what poppy.pop
  01/00/secret1
  01/00/secret2
  03/secret1
  04/secret1
  05/secret1
  $ passage what host/a
  03/secret1
  04/secret1

Should succeed - users with no secrets
  $ passage what non.existent.user
  E: no such recipient non.existent.user

Should succeed - for groups
  $ passage what @root
  03/secret1
  04/secret1

Should succeed - multiple users
  $ passage what bobby.bob poppy.pop 2> /dev/null
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  02/secret1
  04/secret1
  01/00/secret1
  01/00/secret2
  03/secret1
  04/secret1
  05/secret1

Should succeed - multiple users, users with no secrets
  $ passage what bobby.bob non.existent poppy.pop 2> /dev/null
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  02/secret1
  04/secret1
  01/00/secret1
  01/00/secret2
  03/secret1
  04/secret1
  05/secret1

Should succeed - my command as an alias for what <my.name>
  $ passage what bobby.bob
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  02/secret1
  04/secret1
  $ passage my
  00/.secret_starting_with_dot
  00/secret1
  01/secret1
  02/secret1
  04/secret1
