  $ . ./setup_fixtures.sh

Verify that no temp files are left if age fails to encrypt a secret.

  $ mkdir -p bin
  $ AGE=$(which age)
  $ cat<<EOF > bin/age
  > #!/bin/sh
  > if [ "\$1" = "--encrypt" ]; then false; else exec $AGE "\$@"; fi
  > EOF
  $ chmod u+x bin/age
  $ export PATH="$(pwd)/bin:$PATH"
  $ echo "contents" | passage create 00/secret 2>&1 | sed 's/--output.*/.../g'
  E: encrypting 00/secret failed: Failure("age --encrypt --armor ...
  $ ls -a $PASSAGE_DIR/secrets/00
  .
  ..
  .keys
  .secret_starting_with_dot.age
  secret1.age
