  $ . ./setup_fixtures.sh

Should succeed and display only secret without comments - single line secret without comments
  $ setup_singleline_secret_without_comments single_line_no_comments
 Print to stdout
  $ passage head single_line_no_comments
  (single_line_no_comments) secret: single line
 Print as QRCode
  $ passage head -q single_line_no_comments
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ █▄▀ █▄▀▄███▄▄ █▀▄██ ▄▄▄▄▄ ████
  ████ █   █ ██  ▀▀█▄ ▀█▀█▄▄▀ ▀█ █   █ ████
  ████ █▄▄▄█ █ █▀██▄▄ ▀ ▄▄▄█▀▄██ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█▄█▄▀ ▀▄█ █ ▀ ▀▄█ █▄▄▄▄▄▄▄████
  ████▀  ▄▄ ▄ ██▄▄▀ ███ █ ▀▀▄▄█▀█▄▄█▀█ ████
  ████▀ ▀▀ █▄▀▀█▀ ██▀█  ▀█ ▀ ██ ███ ▀▀█████
  ████▄ █ ▀ ▄▀▀▀▄▄ ███▀█▀ ▀█▄▀▄ ▀▄▄█▀▀ ████
  ████▄▀ ▀▀█▄▀ ███ ▀█ █▀ █▄▀ ▀▀   ▄▀ ▄█████
  ████▀█ █ ▄▄▄██ █ █   ▀▀ ▀▄ ▀▄▄▀▄▄▄██ ████
  ████ ▄▄ ▄█▄  ▀█▄█ ▀▀█ ██  ▄▀▄▄█▄▀  ▀▀████
  ████▀███▀▀▄▀▄▀ █▀  ▀ ▄  ▀█▄ █▀▀█▄█▀█▀████
  ████ █▀▀▀ ▄▀██▀ ▄▄██ █ █▀▀ █ ▄▄▀▄ ▀▀█████
  ████▄█▄█▄█▄▄ ▄ ▀ ▄▀▀▀▄█ ▀▀▄█ ▄▄▄ ▀█  ████
  ████ ▄▄▄▄▄ █ ▄▄▄▄▄▀  █▄▀     █▄█ ▀▀▄█████
  ████ █   █ █  ▀▀▄▀▄▀▀   ▀▀█▀  ▄  ▀▀▄▀████
  ████ █▄▄▄█ █ ▀█ █   █▄▄██▀▀███ █▀  ██████
  ████▄▄▄▄▄▄▄███▄███▄███████▄█▄█▄████▄█████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should succeed and display only secret without comments - single line secret with comments
  $ setup_singleline_secret_with_comments single_line_with_comments
 Print to stdout
  $ passage head single_line_with_comments
  (single_line_with_comments) secret: single line
 Check that comments were present in the secret and correctly dropped from the above command
  $ passage get single_line_with_comments
  (single_line_with_comments) secret: single line
  (single_line_with_comments) comment: line 1
  (single_line_with_comments) comment: line 2
 Print as QRCode
  $ passage head -q single_line_with_comments
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ ███▀█▀ ▀▀  ▄▄ ▀▄▄██ ▄▄▄▄▄ ████
  ████ █   █ █ ▄▄█▀▄▀▀█▄▄▀▄▄  ▀█ █   █ ████
  ████ █▄▄▄█ █ █▄▀▄█▀▄▄▄▄▀▄▄▀▄▀█ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █ ▀▄█ █ █▄▀ ▀ █▄█▄▄▄▄▄▄▄████
  ████▄▀ ▄▄▄▄█▀█▀▀  ▄█  ▀ ▀█▄▄█▀▄▄▄▄ ▀▀████
  █████▀ █▄ ▄▄▀█▄▀▀ ▄ █ ▀▀ ▀▄██▄ ██ ▀ █████
  ████ ▄▀█▄ ▄██▄▀▄ █▄ ▀█▀▄▀█▄▀▄▄▀▄▄▀▀ ▀████
  ████ █▀▀▀▄▄█▀ ███ ▄█▀██ ▀ ▀█   ▀▀█ ▄█████
  ████ ▀██ ▀▄▀ ▄ █▄▄▀██ ▀ ▀▀ ▀▄▄▀▄▄▄██ ████
  ████▀▄▀▀▀ ▄ ▄▄▄ ▄█▀ ▄ ▀▀▄  ▀▄ ▀▄▀  ▄▀████
  ████▀  ▀▄▀▄ ▀  █ ██▀▀▀▀█▀ █  ▄▀▄▄███▀████
  ████ ██ ▀ ▄█▀▄ ▀█▀▀█▀▄▀ ▀ ▄██▄▄▀▄█▀▀▀████
  ████▄████▄▄█▀▄█▄█  ██ █ ▀█▄█ ▄▄▄ ▀█  ████
  ████ ▄▄▄▄▄ █▀█ ▀██▄▄▄ ▀▀ █▄  █▄█ ▀▀ ▀████
  ████ █   █ █ █ ▀█▄█ ▀█▀▄▀▄▄▀  ▄  █▀█▀████
  ████ █▄▄▄█ █▄▀▄ ▄▄▄█▀█▀ ▀ ███▀ █▀▀ ██████
  ████▄▄▄▄▄▄▄█▄███▄▄██▄▄█▄▄▄▄▄▄████▄█▄█████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should fail - non-existent secret
  $ passage head non_existent_secret
  E: no such secret: non_existent_secret
  [1]

Should fail - multiline secret
  $ setup_multiline_secret_without_comments multiline_no_comments
  $ passage head multiline_no_comments
  E: multiline_no_comments is expected to be singleline but it is multiline
  [1]

  $ setup_multiline_secret_with_comments multiline_with_comments
  $ passage head multiline_with_comments
  E: multiline_with_comments is expected to be singleline but it is multiline
  [1]

Should fail - user is not authorised to view secret
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage head single_line_no_comments
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt single_line_no_comments : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
