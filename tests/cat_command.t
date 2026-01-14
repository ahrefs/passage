  $ . ./setup_fixtures.sh

Encrypt a secret file with identity
  $ cat <<EOF | passage create test_secret
  > 
  > 
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF

Should succeed - access contents of secret file with correct identity
  $ passage cat test_secret
  
  
  secret line 1
  secret line 2
  secret line 3\123\65

Should succeed - without -c or -q, specifying line number output specified line
  $ passage cat --line=4 test_secret
  secret line 2

Should succeed - passing -q without line number specified should display entire secret
  $ passage cat -q test_secret
  █████████████████████████████████████████
  █████████████████████████████████████████
  ████ ▄▄▄▄▄ ██▀  ▀ ▀ █ █▄  █▄▄█ ▄▄▄▄▄ ████
  ████ █   █ █  ▀▄█▄▀▀█▄▄█▄▄▄███ █   █ ████
  ████ █▄▄▄█ █ ▀ █▄ █▄▄█▄▀▄ ▄▄ █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█ █▄▀▄█▄█ █ ▀ ▀▄█▄█▄▄▄▄▄▄▄████
  ████▄█ ▄▄ ▄▀▀▄▄▄▄  █▄   ▀▀▀ ▄▀ ▄▄▄▄▀▀████
  ████ ▄▀▄▄█▄█▀▀ █▄ ▄ █ ▀▀█▀█▀▄▀▄██▀▀ ▀████
  █████▀▄▀▀ ▄▄██▀▀▀▀▄ ▀█▀██▀▀▄█▄▀▄▄▄▀██████
  █████ ▀█▄ ▄▄ █ ▄█ ▀█▀█ ▀█ ▀▀▀▄█▄▀▀▀█▀████
  ████▀▀█ ██▄▀█▀ ██▄▄██ ▀   █▀▄█▀▄▄█▀█ ████
  █████▄▀▄▄▀▄▄▄██ ▄▄▄   ▀▀▄▀▀█▀▄  ▄ ▀ █████
  ████▀▀▀  █▄▄ ▀ ▄▀██ ▀▀▀██▄  ▀▄▀▄▄▀▀▄█████
  ████ ███▄▀▄▀█▄█  ▄▄█▀█▀█ ▀██ ██ █  ▀▀████
  ████▄████▄▄▄ ▄▀ ▄▄ █▀ ▀▀▀█ █ ▄▄▄  ▀█▀████
  ████ ▄▄▄▄▄ █▀▄▄▀▄ █▄▀ ▀█  ▄  █▄█    ▀████
  ████ █   █ █  █▄ ▀▀▀▀▀▀▀▄▀▀█  ▄▄ ▀▀▀▀████
  ████ █▄▄▄█ █▄▄▄▀▀ ██▀█▄▀▀▀▀▄█▀▄█▀█ ██████
  ████▄▄▄▄▄▄▄█▄████████▄████▄█▄▄█▄███▄█████
  █████████████████████████████████████████
  █████████████████████████████████████████

Should succeed - passing -q with line number specified
  $ passage cat -q -l4 test_secret
  █████████████████████████████
  █████████████████████████████
  ████ ▄▄▄▄▄ █ █▀▀ █ ▄▄▄▄▄ ████
  ████ █   █ █▄▀▀ ▀█ █   █ ████
  ████ █▄▄▄█ █▄▀▄  █ █▄▄▄█ ████
  ████▄▄▄▄▄▄▄█▄█ █▄█▄▄▄▄▄▄▄████
  ████ █▀▄  ▄ ▄▄▀█▀ ██▄▀ ▄▄████
  █████▄▄ ▀█▄▀ █▀ ▄▀▄█▀█   ████
  █████▄▄▄██▄▄  █ ▄ █▄ ▄▀▄▄████
  ████ ▄▄▄▄▄ █ ▄ █ ▀▀▄  ▀██████
  ████ █   █ █ █  ▄▀▀▀█▀▀▄█████
  ████ █▄▄▄█ ██▀   ▄▀▀▄ ▀  ████
  ████▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄████████
  █████████████████████████████
  █████████████████████████████

NOTE: The below tests for tests for the -c flag are not executed as it depends on whether there's an X11 display on the machine running the tests

Should succeed - passing -c without line number specified should display line number 1
$ passage cat -c test_secret && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 45 seconds.
line 1

Should succeed - passing -c with line number specified
$ passage cat -c -l2 test_secret && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 45 seconds.
line 2

Clipboard should be restored after PASSAGE_CLIP_TIME
$ export INITIAL_CLIPBOARD="a\123b"
$ export PASSAGE_CLIP_TIME=5
$ printf "%s" $INITIAL_CLIPBOARD | xclip -selection "clipboard"
$ passage cat -c -l2 test_secret && sleep $((1 + $PASSAGE_CLIP_TIME)) && xclip -selection "clipboard" -o
Copied test_secret to clipboard. Will clear in 5 seconds.
a\123b
$ unset INITIAL_CLIPBOARD PASSAGE_CLIP_TIME

Should fail - line number that does not correspond to any text
  $ passage cat -q -l100 test_secret
  There is no secret at line 100
  [1]
  $ passage cat -c -l100 test_secret
  There is no secret at line 100
  [1]

Should fail - passing invalid number to -q and -c
  $ passage cat -q -lnot_a_number test_secret > /dev/null 2>&1
  [124]
  $ passage cat -c -lnot_a_number test_secret > /dev/null 2>&1
  [124]

Should fail - passing in both -c and -q flags
  $ passage cat -c -q test_secret > /dev/null 2>&1
  [124]

Should fail - passing in invalid secret names
  $ passage cat .. > /dev/null 2>&1
  [124]
  $ passage cat ../ > /dev/null 2>&1
  [124]
  $ passage cat /.. > /dev/null 2>&1
  [124]
  $ passage cat /../ > /dev/null 2>&1
  [124]
  $ passage cat /../test_secret
  
  
  secret line 1
  secret line 2
  secret line 3\123\65

  $ passage cat test_secret/.. > /dev/null 2>&1
  [124]
  $ passage cat 01/../00
  E: 00 is a directory
  [1]
  $ passage cat invalid_secret
  E: no such secret: invalid_secret
  [1]

Should get an error if used on a directory
  $ passage cat 01
  E: 01 is a directory
  [1]

Should succeed - cat a secret by a member of a group
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ passage who @root
  robby.rob
  tommy.tom
  $ PASSAGE_IDENTITY=robby.rob.key passage cat 03/secret1
  (03/secret1) secret: single line
  $ PASSAGE_IDENTITY=tommy.tom.key passage cat 03/secret1
  (03/secret1) secret: single line
