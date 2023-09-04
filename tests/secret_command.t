  $ . ./setup_fixtures.sh

Should succeed and display only secret without comments - single line secret without comments
  $ setup_singleline_secret_without_comments single_line_no_comments
 Print to stdout
  $ passage secret single_line_no_comments
  (single_line_no_comments) secret: single line
 Print as QRCode
  $ passage secret -q single_line_no_comments
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
  $ passage secret single_line_with_comments
  (single_line_with_comments) secret: single line
 Print as QRCode
  $ passage secret -q single_line_with_comments
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

Should succeed and display only secret without comments - multiline secret without comments
  $ setup_multiline_secret_without_comments multiline_no_comments
 Print to stdout
  $ passage secret multiline_no_comments
  (multiline_no_comments) secret: line 1
  (multiline_no_comments) secret: line 2
 Print as QRCode
  $ passage secret -q multiline_no_comments
  █████████████████████████████████████████████
  █████████████████████████████████████████████
  ████ ▄▄▄▄▄ ███▀▄▄▀▄▄█▄▀▄█▄█▄▀ ▀▀ █ ▄▄▄▄▄ ████
  ████ █   █ █ ▀▀▀██▄▄▀▀███▄ ▄▄▀  ▄█ █   █ ████
  ████ █▄▄▄█ █ ▄▀  ▀ █ ▀ ▄▄ ▀▄▀ ▀▀ █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ ▀▄▀ ▀ ▀▄█ █ ▀ █ █▄█▄█▄▄▄▄▄▄▄████
  ████▄▀ ▄▄▄▄▀▀███▄█  ▀▀  █▀ ▀█  ▄▀█▄ ▄  ▀█████
  ██████▄▀▀█▄▀██ █  ▀█▀▄▀█   ▀▀█   ▄█▀ ██  ████
  █████▄▄▄▄ ▄ █ ▄ █ ▀█  ▀▀▀▀▄▀ ▄▄█▀▄▄▀▄▄▄▄█████
  ████▄ ▀█ ▄▄▀▀ ██▀ ▀   ▀██ ▄█▀█▄▄  █▄▀██▄ ████
  ████▄ ██▄ ▄▄ ▄  ███▀▀█▀▀▀▀▀ ▄  █▀  ▀▄▄ ▄▄████
  ██████▀█ ▄▄ ▄▀█ ▄█▀█▀██▀▀▀▀███       ▄█▄ ████
  █████▀▄▀▀▄▄▄█▀▄ ▄▀ █▀   ██ ▀ ▄▄▀   ▀▄▄ ▀█████
  ████▄ ▄▄█ ▄ █▄█ ▄ █ █ ▀▀█▀█▀▀▄▀▄  █▀▀▄█▄ ████
  ████▀▄▀█▀ ▄▀▀ ▀▄▄▄▄▀▀█▀ ▀▀█▀▄▄██▀▄▄ █▀ ▄█████
  ████ █▀ ▄█▄█ ██▀ ▀██▀█ █▄▀█▀▀█ ▄  █ ███▀ ████
  ████▄██▄▄▄▄█  ▀▀▄ ▀██ ▄ ▄▀▄▀█ ▄▀ ▄▄▄ ▄▄▄█████
  ████ ▄▄▄▄▄ █▀▄█▀   ▄█ ▀█▀ ██▄█▀█ █▄█ ▄█  ████
  ████ █   █ █  █ ██ ▀▀█▀▀▀▀▄▀█ █    ▄ ▄ ▄ ████
  ████ █▄▄▄█ █▄███▀▀ █▀█▄█▀  █ ▄▄▀ █▀ █▄▄▄ ████
  ████▄▄▄▄▄▄▄█▄▄▄▄▄█████▄▄▄█▄██▄▄██▄██▄▄▄▄▄████
  █████████████████████████████████████████████
  █████████████████████████████████████████████

Should succeed and display only secret without comments - multiline secret comments
  $ setup_multiline_secret_with_comments multiline_with_comments
 Print to stdout
  $ passage secret multiline_with_comments
  (multiline_with_comments) secret: line 1
  (multiline_with_comments) secret: line 2
 Print as QRCode
  $ passage secret -q multiline_with_comments
  █████████████████████████████████████████████
  █████████████████████████████████████████████
  ████ ▄▄▄▄▄ █▄ ▄▀▄ ▀▄▄█ ▀▀▄▄▄▀█▄▄ █ ▄▄▄▄▄ ████
  ████ █   █ █▀▄▀▀▀▄▀█▀▄▀▀▄▄▀ █▀ ▀▄█ █   █ ████
  ████ █▄▄▄█ █  ▀ ▄█▀█ ▄ ▀ ▀█▄▄█▄█▄█ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ ▀▄▀ ▀▄▀ ▀ ▀▄▀▄█▄█ ▀ █▄▄▄▄▄▄▄████
  ████ ▀▀▀▄▀▄▄ ▀ ▄▄▄▀▄▀ ▀█▄▄▄▀ ▀▀ ▀  ▄  ▀▀▄████
  ████ █▀▀▀█▄ ▀ ▀█ ███▄ ▄██   ▄▄▀▄█▀  █▄ ██████
  ███████▀ ▀▄█▄███ ▄▀ █ ▀▄▀▄  ██▀ ▀▄▄▄▀ ▄▄█████
  ████▄ ▄▄▀▄▄▀  █ █▀█▄ ▀▄█▀ █ ▀█  ▄█ ▄▀█ ██████
  ████▀▄▀  ▀▄█▄▀ ▄█▄▄▄▀ ▀▄ ▄▄▀ █▀█  ▄▄▀▀▄▄▄████
  ████▄▀▀ ▀▄▄▄▄█▀  ▀▀█▄ ▀▀█▀▄▄▄▄   ██▀ ▄ ▀█████
  █████▄▄▀ ▄▄█▀ ▀▄▄▀█▄█▄▀██▄▄▀██▀    ▄▀▀ ▀█████
  ████▀▄██▀▄▄█▀▀▀▄▀▄▄ ▀  █ ▀▄▄▀█  ▀█▀▀▀▄ ██████
  ████▀ ▄▄▄█▄█▀██▀▄█▀█▀  ▄▀▄  ██▀ ▀▄▄▄▀▄ ▄█████
  ██████▀▀ ▄▄█▄▄ ▄█▀▀█▄▀▄█▀ █ ▀█  ▄█ ▄▀█ ▄█████
  ████▄▄▄█▄█▄▄ ▄▀▀ ▀▀ ▄▄▀▄▄▄▄▀▄▀▀█ ▄▄▄ ▀▄█▄████
  ████ ▄▄▄▄▄ █▄▀█ ███   █▀█▀   █ █ █▄█ ▄ ▀█████
  ████ █   █ █▄▄ ▄ █ ██▄▄▄█▄▄▀██▀▀    ▄▀ ▀▀████
  ████ █▄▄▄█ ██▄█▄ ▀█▄   █ ▀▄▄▀█ █▄▀  █▄ ▀█████
  ████▄▄▄▄▄▄▄█▄█▄███▄██▄▄▄█▄▄▄▄██▄█▄▄▄██▄▄▄████
  █████████████████████████████████████████████
  █████████████████████████████████████████████

Should fail - non-existent secret
  $ passage secret non_existent_secret
  E: no such secret: non_existent_secret
  [1]

Should fail - user is not authorised to view secret
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage secret single_line_no_comments
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt single_line_no_comments : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
