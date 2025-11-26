  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage list
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

Should succeed - curr dir as path
  $ passage list .
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls .
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

Should succeed - single-level path
  $ passage list 01
  01/00/secret1
  01/00/secret2
  01/secret1
  $ passage ls 01
  01/00/secret1
  01/00/secret2
  01/secret1

Should succeed - single-level path with trailing slash
  $ passage list 01/
  01/00/secret1
  01/00/secret2
  01/secret1
  $ passage ls 01/
  01/00/secret1
  01/00/secret2
  01/secret1

Should succeed - multi-level path
  $ passage list 01/00/secret2
  01/00/secret2
  $ passage ls 01/00/secret2
  01/00/secret2

Should succeed - valid secret path that ends with ..
  $ passage list 01/..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls 01/..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

Should succeed - valid secret path that includes .. in the middle
  $ passage list 01/../00
  00/.secret_starting_with_dot
  00/secret1
  $ passage ls 01/../00
  00/.secret_starting_with_dot
  00/secret1

Should fail - path that goes out of the secrets dir
  $ passage list ..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls ..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

  $ passage list ../
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls ../
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

  $ passage list /..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls /..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1

  $ passage list /../
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1
  $ passage ls /../
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  03/secret1
  04/secret1
  05/secret1


Should fail - single-level invalid path
  $ passage list invalid_path
  No secrets at invalid_path
  [1]
  $ passage ls invalid_path
  No secrets at invalid_path
  [1]

Should fail - multi-level invalid path
  $ passage list 01/invalid_path
  No secrets at 01/invalid_path
  [1]
  $ passage ls 01/invalid_path
  No secrets at 01/invalid_path
  [1]

Should fail gracefully - invalid setup
  $ PASSAGE_DIR=. passage list 01
  E: 01: Failure("secrets directory (./secrets) is not initialised. Is passage setup? Try 'passage init'.")
  [1]
