  $ . ./setup_fixtures.sh

Encrypt a secret file with identity
  $ TEST_SECRET=test_secret
  $ cat <<EOF | age -r $(age-keygen -y $PASSAGE_IDENTITY) > $PASSAGE_DIR/secrets/$TEST_SECRET.age
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF

Should succeed - access contents of secret file with correct identity
  $ passage get $TEST_SECRET
  secret line 1
  secret line 2
  secret line 3\123\65

Should succeed - without -c or -q, specifying line number output specified line
  $ passage get --line=2 $TEST_SECRET
  secret line 2

Should succeed - passing -q without line number specified should display entire secret
  $ passage get -q $TEST_SECRET
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ █▄ █ ██▄▄  ▄▀▀▀██▄█ ▄▄▄▄▄ ████
  ████ █   █ █▀█▀▄ ▄▀▀ ▀▀██ █ ▀█ █   █ ████
  ████ █▄▄▄█ █  ▄▄▄ ▄▀▄▄▄▄▀ ▄▄ █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █▄█▄█ █▄▀▄▀ ▀ █▄█▄▄▄▄▄▄▄████
  ████ █▀▀ █▄▄▄ █▀ █▀   ▀█   ▀▀ ▄ ▄ ▀█▄████
  ████  █ ▀ ▄█▀ ▀ █ ▄▄ █▄█▀ ▀ █ █  ██ █████
  █████ █▄  ▄▀▀▄▀██ ▀▄▀▀▀ ▄▄▀▀▀ ▄▀▄▀▀▀▄████
  ████▄███ █▄█▀██▀▀▀▀█▄ ▀ ▀▀▄ ▄▄▄▄█ █ ▀████
  ████▄▀▀  ▄▄ █▀▀▄▄▀ ▄█ ▀██▄▄▀ ▀▄█▄█▀ ▄████
  ████▀▄███▄▄ █▀█ ▀ ▀▄ █▄█ ▀▀  ██▄ █▄▄▀████
  ████▀▀█▀ ▀▄▄█ ▄▀ █ █▀▀▀ ▄▄▀▀▀▄▄▀▄▄▀▄▄████
  ██████▀▀▀▄▄▀▄ ▀▀▄ ▀█▄▀▄ ▀ █ ▀▀▄▀▄▄█ █████
  ████▄▄▄▄█▄▄█▀█▄▄▀ █ ▄ ▀█▄▄▄▄ ▄▄▄ █▀▄▄████
  ████ ▄▄▄▄▄ █▄▀█ ▄▀▄  █▄▀█ ██ █▄█ ▄▄ ▀████
  ████ █   █ █▄█▀▄ ▄ █▀█▀  ███▄▄   ▀█▄▄████
  ████ █▄▄▄█ ██  █ █ █▄  ▀█▀▄█▄█▄█ ▄███████
  ████▄▄▄▄▄▄▄█▄█▄▄▄▄█▄█▄▄██▄▄▄▄██▄████▄████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should succeed - passing -q with line number specified
  $ passage get -q -l2 $TEST_SECRET
  █████████████████████████████
  █████████████████████████████
  ████ ▄▄▄▄▄ ██▄█▄ █ ▄▄▄▄▄ ████
  ████ █   █ █ ▄▄ ██ █   █ ████
  ████ █▄▄▄█ █ ▀█▀▄█ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ ▀▄█▄█▄▄▄▄▄▄▄████
  ████ ▀    ▄▀██ ▄▀▀     █▀████
  ████▄  ▀▀█▄██▀ █▄▀█▀█   ▀████
  █████▄▄▄▄█▄▄ ▄█▀▄█  ▀█▀▀▀████
  ████ ▄▄▄▄▄ █▀▀██  █ █ ▀ █████
  ████ █   █ █ ▀▄█▄▀ █▀▄▀▄▄████
  ████ █▄▄▄█ █▄  ▀ ▀▄██▀▀██████
  ████▄▄▄▄▄▄▄█▄▄█▄▄█▄████▄█████
  █████████████████████████████
  █████████████████████████████

NOTE: The below tests for tests for the -c flag are not executed as it depends on whether there's an X11 display on the machine running the tests

Should succeed - passing -c without line number specified should display line number 1
$ passage get -c $TEST_SECRET && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 45 seconds.
line 1

Should succeed - passing -c with line number specified
$ passage get -c -l2 $TEST_SECRET && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 45 seconds.
line 2

Clipboard should be restored after PASSAGE_CLIP_TIME
$ export INITIAL_CLIPBOARD="a\123b"
$ export PASSAGE_CLIP_TIME=5
$ printf "%s" $INITIAL_CLIPBOARD | xclip -selection "clipboard"
$ passage get -c -l2 $TEST_SECRET && sleep $((1 + $PASSAGE_CLIP_TIME)) && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 5 seconds.
a\123b
$ unset INITIAL_CLIPBOARD PASSAGE_CLIP_TIME


Should fail - line number that does not correspond to any text
  $ passage get -q -l100 $TEST_SECRET
  There is no secret at line 100
  [1]
  $ passage get -c -l100 $TEST_SECRET
  There is no secret at line 100
  [1]

Should fail - passing invalid number to -q and -c
  $ passage get -q -lnot_a_number $TEST_SECRET
  passage: option '-l': invalid value 'not_a_number', expected an integer
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get -c -lnot_a_number $TEST_SECRET
  passage: option '-l': invalid value 'not_a_number', expected an integer
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]

Should fail - passing in both -c and -q flags
  $ passage get -c -q $TEST_SECRET
  passage: options '-q' and '-c' cannot be present at the same time
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]

Should fail - passing in invalid secret names
  $ passage get ..
  passage: SECRET_NAME argument: .. is not a valid secret
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get ../
  passage: SECRET_NAME argument: ../ is not a valid secret
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get /..
  passage: SECRET_NAME argument: /.. is not a valid secret
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get /../
  passage: SECRET_NAME argument: /../ is not a valid secret
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get /../$TEST_SECRET
  E: no such secret: /../test_secret
  [1]
  $ passage get $TEST_SECRET/..
  passage: SECRET_NAME argument: test_secret/.. is not a valid secret
  Usage: passage get [--clip] [--line=LINE] [--qrcode] [OPTION]… SECRET_NAME
  Try 'passage get --help' or 'passage --help' for more information.
  [124]
  $ passage get 01/../00
  E: no such secret: 01/../00
  [1]
  $ passage get invalid_secret
  E: no such secret: invalid_secret
  [1]
