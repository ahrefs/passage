#!/usr/env/sh

BOBBY="bobby.bob"
DOBBY="dobby.dob"
POPPY="poppy.pop"
ROBBY="robby.rob"
TOMMY="tommy.tom"

export PASSAGE_DIR=./fixtures
# Set default identity as Bobby Bob
export PASSAGE_IDENTITY="$BOBBY.key"

check_age_file_format() {
  file=$1
  begin_header="-----BEGIN AGE ENCRYPTED FILE-----"
  end_header="-----END AGE ENCRYPTED FILE-----"

  if [ "$(head -n1 "$file")" = "$begin_header" ]
  then echo "OK: age file starts with expected $begin_header"
  else echo "FAIL: age file does not starts with expected $begin_header"
  fi

  if [ "$(grep -c --fixed-strings -- "$begin_header" "$file")" -eq 1 ]
  then echo "OK: age file only has 1 occurrence of $begin_header"
  else echo "FAIL: age file has multiple occurrence of $begin_header"
  fi

  if [ "$(tail -n1 "$file")" = "$end_header" ]
  then
    echo "OK: age file ends with expected $end_header"
  else
    echo "FAIL: age file does not ends with expected $end_header"
  fi

  if [ "$(grep -c --fixed-strings -- "$end_header" "$file")" -eq 1 ]
  then echo "OK: age file only has 1 occurrence of $end_header"
  else echo "FAIL: age file has multiple occurrence of $end_header"
  fi
}

setup_identity() {
  IDENTITY=$1.key
  age-keygen -o "$IDENTITY" 2> /dev/null
  touch "$PASSAGE_DIR/keys/$1.pub"
  age-keygen -y "$IDENTITY" > "$PASSAGE_DIR/keys/$1.pub"
}

setup_keys_dir() {
  mkdir -p "$PASSAGE_DIR/keys"
  setup_identity $BOBBY true
  setup_identity $DOBBY true
  setup_identity $POPPY true
  setup_identity $ROBBY true
  setup_identity $TOMMY true
}

setup_empty_secret_file() {
  SECRET_NAME=$1
  SECRET_FILE="$PASSAGE_DIR/secrets/$SECRET_NAME.age"
  DIR=$(dirname "$SECRET_FILE")
  mkdir -p "$DIR"
  touch "$SECRET_FILE"
}

setup_singleline_secret_without_comments() {
  name=$1
  cat<<EOF | passage replace "$name"
($name) secret: single line
EOF
}

setup_singleline_secret_with_comments() {
  name=$1
  cat<<EOF | passage replace "$name"
($name) secret: single line
($name) comment: line 1
($name) comment: line 2
EOF
}

setup_multiline_secret_without_comments() {
  name=$1
  cat<<EOF | passage replace "$name"


($name) secret: line 1
($name) secret: line 2
EOF
}

setup_multiline_secret_with_comments() {
  name=$1
  cat<<EOF | passage replace "$name"

($name) comment: line 1
($name) comment: line 2

($name) secret: line 1
($name) secret: line 2
EOF
}

# $PASSAGE_DIR/secrets/
# ├── .keys
# ├── 00
#     ├── .secret_starting_with_dot.age
#     └── secret1.age
# ├── 01
# │   ├── 00
# │   │   ├── .keys
# │   │   ├── secret1.age
# │   │   └── secret2.age
# │   └── secret1.age
# └── 02
#     ├── .keys
#     └── secret1.age
setup_secrets_dir() {
  mkdir -p "$PASSAGE_DIR/secrets"
  setup_empty_secret_file "00/secret1"
  setup_empty_secret_file "00/.secret_starting_with_dot"
  setup_empty_secret_file "01/00/secret1"
  setup_empty_secret_file "01/00/secret2"
  setup_empty_secret_file "01/secret1"
  setup_empty_secret_file "02/secret1"

  cat<<EOF > "$PASSAGE_DIR/secrets/.keys"
bobby.bob
robby.rob

dobby.dob

tommy.tom # should be omitted
# should be omitted

user.with.missing.key
EOF
  cat<<EOF > "$PASSAGE_DIR/secrets/01/00/.keys"
robby.rob
poppy.pop
EOF
  touch "$PASSAGE_DIR/secrets/02/.keys"
}

# $PASSAGE_DIR/templates/
# ├── single_secret.txt
# └── multiple_secrets.txt
setup_templates() {
  mkdir -p "$PASSAGE_DIR/templates"

  cat<<EOF > "$PASSAGE_DIR/templates/single_secret.txt"
this is a template with a single secret
{{{ this_should_not_be_substituted }}}
TEXT BEFORE SECRET{{{single_secret}}}TEXT AFTER SECRET
EOF

  cat<<EOF > "$PASSAGE_DIR/templates/multiple_secrets.txt"
this is a template with multiple_secrets
{{{ this_should_not_be_substituted }}}
first secret: {{{multiple_secrets_1}}}

second secret:
{{{multiple_secrets_2}}}

end of file
EOF
}

setup_keys_dir
setup_secrets_dir
setup_templates
