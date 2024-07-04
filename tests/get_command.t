  $ . ./setup_fixtures.sh

Should succeed and display only secret without comments - single line secret without comments
  $ setup_singleline_secret_without_comments single_line_no_comments
 Print to stdout
  $ passage get single_line_no_comments
  (single_line_no_comments) secret: single line
 Print as QRCode
  $ passage get -q single_line_no_comments
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ █▀▄█▄  ▄ ▀▀ ▄▄▀▀ ▀█ ▄▄▄▄▄ ████
  ████ █   █ █▄▄ ▀█▀█▄██ ▄▄█   █ █   █ ████
  ████ █▄▄▄█ ██▀▄▀▀██▄▄▀▀ █ ██ █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█▄█ ▀▄█▄▀ ▀▄▀▄█▄▀▄█▄▄▄▄▄▄▄████
  █████   █ ▄████ ▀▀▀▄█ ▄▀▀ █▄▄▀████ ▄▀████
  ████▀▀▀▄ ▀▄▀ ▄▄▀▄  ▄ ██▀▀▄▄▄ ▄▄ ▀▀▄█▄████
  ████▀▄▀█▄▀▄█  ▄▀█▄▄▄ ▀▄ █▀▄█  █ ▄▀█▀▄████
  ████▀▀ █▀▄▄ ▄▀▀▀  ▀▀█▄█▄▄ ▀▀ ▀ ▀█▀▀██████
  ████▀█▄▀▄▄▄█▀ ▄▄ ▄▄ ▀▀▀▄ ▀▄ ▀  ▀ █ ▀▀████
  █████ ▄█▀▄▄▄▄█▄    ▄▄▄▄█▄▄▄█ ▄▀ ▀▄▄▀█████
  ████  ▄▀▄▄▄ ▄▄▀▀▄█▄▀▄▀▄▀▀▄█ ▄ ▀▄██ ▄▀████
  █████▀▄ ██▄▀█▀█▄█▄▀█▄▄ ▀ ▄▄▄█ █▄ ▀▄▀ ████
  ████▄███▄█▄▄▀█▀▄  ▀█ ▀  ██▄▀ ▄▄▄ █▀ ▄████
  ████ ▄▄▄▄▄ █▀▄▀▄▀▀█  █▀  ▀▀  █▄█ ▀ ██████
  ████ █   █ █▀  ▀█▄▀█▄▀ ▄ ▄▀ ▄▄▄▄▄ ▄  ████
  ████ █▄▄▄█ █ ██████  ▄▀█▀█▀▀▀█▄▀▀▄▄█▀████
  ████▄▄▄▄▄▄▄██▄█▄▄▄██▄▄█▄█▄███▄▄▄▄█▄██████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should succeed and display only secret without comments - single line secret with comments
  $ setup_singleline_secret_with_comments single_line_with_comments
 Print to stdout
  $ passage get single_line_with_comments
  (single_line_with_comments) secret: single line
 Print as QRCode
  $ passage get -q single_line_with_comments
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ ██▄ ▀  ▀▀  ▄▄ ▀▄▄██ ▄▄▄▄▄ ████
  ████ █   █ █    ▄▄▀▀█▄▄▀▄▄  ▀█ █   █ ████
  ████ █▄▄▄█ █  █▀▀█▀▄▄▄▄▀▄▄▀▄▀█ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █▄█▄█ █ █▄▀ ▀ █▄█▄▄▄▄▄▄▄████
  ████▄▀▄ ▄ ▄▀█ ▄▀▄ ▄█  ▀ ▀█▄▄█▀▄▄▄▄ ▀▀████
  ████ ▄▄█▀▀▄▄▀███▄ ▄ █ ▀▀ ▀▄██▄ ██ ▀ █████
  ██████ ▀▀ ▄ ▄  ▄▀▀▄ ▀█▀▄▀█▄▀▄▄▀▄▄▀▀ ▀████
  ████▀ █▀█ ▄▀ ▀█▄▀▄ █▀██ ▀ ▀█   ▀▀█ ▄█████
  █████ ██ ▄▄▀▀▄▄▄▀█▄██ ▀ ▀▀ ▀▄▄▀▄▄▄██ ████
  ████▄▄ ██ ▄█▀ ▄███▀ ▄ ▀▀▄  ▀▄ ▀▄▀  ▄▀████
  ████  ▄█ ▀▄█▄▀ █▄█▀▀▀▀▀█▀ █  ▄▀▄▄███▀████
  ████ █▀▄▀▄▄█▄▄ ▀█▄██▀▄▀ ▀ ▄██▄▄▀▄█▀██████
  ████▄█▄███▄█▀▄█▄█▄ ██ █ ▀█▄█ ▄▄▄ ▀█▀▀████
  ████ ▄▄▄▄▄ █▀█   ▀▀▄▄ ▀▀ ▀█  █▄█ ▀▀ ▀████
  ████ █   █ █ ▀▀▀▀▄▄ ▀█▀▄▀▄█▀  ▄  █▀▀▀████
  ████ █▄▄▄█ █▄  ▄████▀█▀ ▀ ███▀ █▀▀ ██████
  ████▄▄▄▄▄▄▄█▄█▄███▄█▄▄█▄▄▄▄▄▄████▄█▄█████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should succeed and display only secret without comments - multiline secret without comments
  $ setup_multiline_secret_without_comments multiline_no_comments
 Print to stdout
  $ passage get multiline_no_comments
  (multiline_no_comments) secret: line 1
  (multiline_no_comments) secret: line 2
 Print as QRCode
  $ passage get -q multiline_no_comments
  █████████████████████████████████████████████
  █████████████████████████████████████████████
  ████ ▄▄▄▄▄ █▀█▄ ▀█   █▀█▄ ▄█▀▀ █▀█ ▄▄▄▄▄ ████
  ████ █   █ █  █▄▄▄▀█ ▀██▀ ▄▄▄▀▄▄ █ █   █ ████
  ████ █▄▄▄█ ██▀▄ ▄▀ ▀ ▀ ▄▄▄▀▄▀ ▀█ █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █▄█ █ █ █ █ █ █ █▄▀▄█▄▄▄▄▄▄▄████
  ████ █▀█▀█▄█ ▀▄██▀▄██▀  ▀█▄▀█ ▄ █▄▄▀▀▄▄ █████
  █████▄▄ ▀▀▄██▀ ▄▄▀▀▀▀▄▀█ ▄ ▀▀█ ▄ ▄█▀ ▀█  ████
  ████▄▄ █▄▀▄▀█▀ ▄▀  ▀▀▀▀  ██  ██▀ █▄ █ ███████
  ████ █ ▄▀▄▄██▀█ ▄▀█▄▄▄ █▀▄ █▀█  ▄ █▄█▀▀▄ ████
  █████ ▀ ▄█▄ ▄▄▀██ ▄█▀█ ▀▀█▀ ▄  ▀▀  ▀▄  ▄▄████
  ████▀█ ▀▀ ▄█▀▄▄ ▀▄▀▀ ▄█  █ ▄█▄▀▄▀▀ ▀▀ ▄█ ████
  ████▄█▄███▄▀ ▀▀▀ ▀█▀█   ▀▀▄▀ ▄ █▄  ▀  ▄▀█████
  ████ ██▄  ▄▄█▀ ▄ ▀ ▄█ ▀▀███▀▀▄▀   █▀▀ █▄ ████
  ████▀█▀▀  ▄▀ ▄██  ▀█ ▄▀▀ █▄ ▄█▄▀ █▄▀▄█▀██████
  ████ ██▀█▀▄▄█▀▀▀██ ▀██ █ █▀▀▀█▄ ▄ █ ▀▀▀█▄████
  ████▄█▄█▄▄▄█ █▄▄█ █▀█ ▄ ▄█▄▀█ ▄█ ▄▄▄  ▄▄█████
  ████ ▄▄▄▄▄ ██▀ ▄▄█  ▄▀▀▄ ▄▄▄▄▄ ▀ █▄█  ▄▀ ████
  ████ █   █ ██▀▄██▄▀███▀▀██ ▀█ ▀▄▄  ▄▄ ▄▄ ████
  ████ █▄▄▄█ ███▄▀▄▄ ▀▀█▄█▀▄ █ ▄▄█ █▀ █ ▄▄ ████
  ████▄▄▄▄▄▄▄█▄▄█▄█▄██▄▄▄████▄████▄██▄█▄██▄████
  █████████████████████████████████████████████
  █████████████████████████████████████████████

Should succeed and display only secret without comments - multiline secret comments
  $ setup_multiline_secret_with_comments multiline_with_comments
 Print to stdout
  $ passage get multiline_with_comments
  (multiline_with_comments) secret: line 1
  (multiline_with_comments) secret: line 2
 Print as QRCode
  $ passage get -q multiline_with_comments
  █████████████████████████████████████████████
  █████████████████████████████████████████████
  ████ ▄▄▄▄▄ ██▀▀█  ▀  █ ▄▄▀▄▄▀ ▀▀ █ ▄▄▄▄▄ ████
  ████ █   █ █ ▀▄▀██   ▀▄▀▄▄▄█ ▀ ▀▀█ █   █ ████
  ████ █▄▄▄█ █ █   █▄  ▄ ▄█▄█▄▄ ▀ ▄█ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █▄▀▄▀ ▀ █▄▀▄▀ ▀ █ ▀▄█▄▄▄▄▄▄▄████
  ████▄▀ ▄▄ ▄▀█▄▀▄█▄▄ ▀ ▀ ▀▀▄▀ ▄▄█▀▀  ▄▄ ▀█████
  █████▄  ▄▄▄   ▄▄ ▄██▀█▀██ ██▀▄▀▄ ▄█ █▄█  ████
  ████▄▀█▀█▀▄▀ ▀  ▄ ▄██ ▀▀▄▀  █ ▄█▀▄▄▀▄█▄▄█████
  ████▀▄▀▀▀█▄█ ▀▀ ██▀▄█▄▀█▀  █▄█  ▀ █▄▀██  ████
  ████▀ ▄▀▀█▄ ▄ ▀▀▀▄▀▀▀ ▀▀█▀▄▀  ▄   ▄▀▄▄▄▄▄████
  █████ ▀█▄▄▄██▄▄ █▀ █▀█▄▀█▀▀▀▀▄  █  ▀ ▄█▄ ████
  ████ █▄▄ █▄▄██ █  ▀▀█▄▀  ▀▄▀█ ▄█   ▀▄▄ ▀█████
  ████  ▄▀▀ ▄▀▀▀▀█ ▀▄ ▄███ ▀▀▀▄█  ▄ ▄▀▀▄█  ████
  ████ ▀▄ █▀▄▀▄ ▄▀▀█▀ █  ▀▄▀  █ ▄█▀▄▄▀▄▀ ▄█████
  ████ █ █ █▄ ▀▄█▀ █ ▄█▄▀█▀  █▄█  ▀ █▄▀███▄████
  ████▄███▄█▄█▀▄▄▄▀  █▄▄▀▀▀▀▄▀▄▄▄  ▄▄▄ ▄▄█▄████
  ████ ▄▄▄▄▄ █▀▄ ▀▄ ▄ ██ ▀█▀████ █ █▄█ ▄█▄ ████
  ████ █   █ █ ▄▀▀▀ ▄ █▄▄▀ ▀▄▀█ ▄▄   ▄ ▄ ▀▀████
  ████ █▄▄▄█ █▄ ▀ ▄▄█▄████ ▀▀▀▄█ █▀▄█ █▄█▄ ████
  ████▄▄▄▄▄▄▄█▄▄▄█▄▄▄▄█▄▄█▄█▄▄▄▄▄██▄▄█▄▄▄▄▄████
  █████████████████████████████████████████████
  █████████████████████████████████████████████

Should fail - non-existent secret
  $ passage get non_existent_secret
  E: no such secret: non_existent_secret
  [1]

Should fail - user is not authorised to view secret
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage get single_line_no_comments
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt single_line_no_comments : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]

Should succeed and display only secret without comments when using the -s for single line secret with comments
  $ passage get -s single_line_with_comments
  (single_line_with_comments) secret: single line
 Check that comments were present in the secret and correctly dropped from the above command
  $ passage cat single_line_with_comments
  (single_line_with_comments) secret: single line
  
  (single_line_with_comments) comment: line 1
  (single_line_with_comments) comment: line 2

Should fail - multiline secret when using the -s flag
  $ passage get -s multiline_no_comments
  E: multiline_no_comments is expected to be a single-line secret but it is a multi-line secret
  [1]

  $ passage get -s multiline_with_comments
  E: multiline_with_comments is expected to be a single-line secret but it is a multi-line secret
  [1]

Should succeed using the -n flag to remove the new-line character at the end of the output.
Default is to add a new-line character at the end
  $ passage get single_line_no_comments | wc -c
  46
  $ passage get -n single_line_no_comments | wc -c
  45
  $ passage get single_line_with_comments | wc -c
  48
  $ passage get -n single_line_with_comments | wc -c
  47
  $ passage get multiline_no_comments | wc -c
  78
  $ passage get -n multiline_no_comments | wc -c
  77
  $ passage get multiline_with_comments | wc -c
  82
  $ passage get -n multiline_with_comments | wc -c
  81

Should succeed - decrypting a secret by a member of a group
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ passage who @root
  robby.rob
  tommy.tom
  $ PASSAGE_IDENTITY=robby.rob.key passage get 03/secret1
  (03/secret1) secret: single line
  $ PASSAGE_IDENTITY=tommy.tom.key passage get 03/secret1
  (03/secret1) secret: single line
