#!/usr/env/sh

BOBBY="bobby.bob"
DOBBY="dobby.dob"
POPPY="poppy.pop"
ROBBY="robby.rob"
TOMMY="tommy.tom"
HOST_A="host/a"

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

setup_group() {
  NAME=$1
  GROUP_FILE="$PASSAGE_DIR/keys/$NAME.group"
  touch "$GROUP_FILE"

  # Shift the first argument (group name) off the list
  shift

  # Now, loop through the recipients and add them to the group file
  for recipient in "$@"
  do
      echo "$recipient" >> "$GROUP_FILE"
  done
}

setup_keys_dir() {
  mkdir host
  mkdir -p "$PASSAGE_DIR/keys"
  mkdir -p "$PASSAGE_DIR/keys/host"
  setup_identity $BOBBY
  setup_identity $DOBBY
  setup_identity $POPPY
  setup_identity $ROBBY
  setup_identity $TOMMY
  setup_identity $HOST_A
}

setup_singleline_secret_without_comments() {
  name=$1
  cat<<EOF | passage create "$name"
($name) secret: single line
EOF
}

setup_singleline_secret_with_identity() {
  name=$1
  id=$2
  cat<<EOF | PASSAGE_IDENTITY=$2 passage create "$name"
($name) secret: single line
EOF
}

setup_singleline_secret_with_comments() {
  name=$1
  cat<<EOF | passage create "$name"
($name) secret: single line

($name) comment: line 1
($name) comment: line 2
EOF
}

setup_multiline_secret_without_comments() {
  name=$1
  cat<<EOF | passage create "$name"


($name) secret: line 1
($name) secret: line 2
EOF
}

setup_multiline_secret_with_comments() {
  name=$1
  cat<<EOF | passage create "$name"

($name) comment: line 1
($name) comment: line 2

($name) secret: line 1
($name) secret: line 2
EOF
}

# $PASSAGE_DIR/secrets/
# ├── .keys
# ├── 00
# │   ├── .keys
# │   ├── .secret_starting_with_dot.age
# │   └── secret1.age
# ├── 01
# │   ├── .keys
# │   ├── 00
# │   │   ├── .keys
# │   │   ├── secret1.age
# │   │   └── secret2.age
# │   └── secret1.age
# ├── 02
# │   └── .keys
# │   └── secret1.age
# ├── 03
# │   └── .keys
# │   └── secret1.age
# ├── 04
# │   └── .keys
# │   └── secret1.age
# └── 05
#     ├── .keys
#     └── secret1.age

setup_secrets_dir() {
  mkdir -p "$PASSAGE_DIR/secrets"

  # Create the directories and keys files for the secrets folders manually, so that we don't have to handle
  # it with passage at the fixtures setup time. We will test these things in the cram tests
  mkdir -p "$PASSAGE_DIR/secrets/00" \
  "$PASSAGE_DIR/secrets/01" "$PASSAGE_DIR/secrets/01/00" "$PASSAGE_DIR/secrets/02" "$PASSAGE_DIR/secrets/03" "$PASSAGE_DIR/secrets/04" "$PASSAGE_DIR/secrets/05"

  cat<<EOF > "$PASSAGE_DIR/secrets/.keys"
bobby.bob
robby.rob

dobby.dob

tommy.tom # should be omitted
# should be omitted

user.with.missing.key
EOF
  cat<<EOF > "$PASSAGE_DIR/secrets/00/.keys"
bobby.bob
robby.rob
dobby.dob
tommy.tom
user.with.missing.key
EOF
  cat<<EOF > "$PASSAGE_DIR/secrets/01/.keys"
bobby.bob
robby.rob
dobby.dob
tommy.tom
user.with.missing.key
EOF
  cat<<EOF > "$PASSAGE_DIR/secrets/01/00/.keys"
robby.rob
poppy.pop
EOF
  cat<<EOF > "$PASSAGE_DIR/secrets/02/.keys"
bobby.bob
EOF

  cat<<EOF > "$PASSAGE_DIR/secrets/03/.keys"
host/a
poppy.pop
@root
EOF

  cat<<EOF > "$PASSAGE_DIR/secrets/04/.keys"
@everyone
EOF

  cat<<EOF > "$PASSAGE_DIR/secrets/05/.keys"
@with_issues
EOF

  # Add groups
  setup_group root robby.rob tommy.tom
  setup_group with_issues poppy.pop no.user this.one.doesnt.exist

  # Add base secrets
  setup_singleline_secret_without_comments "00/secret1"
  setup_singleline_secret_without_comments "00/.secret_starting_with_dot"
  setup_singleline_secret_with_identity "01/00/secret1" "$ROBBY.key"
  setup_singleline_secret_with_identity "01/00/secret2" "$ROBBY.key"
  setup_singleline_secret_without_comments "01/secret1"
  setup_singleline_secret_without_comments "02/secret1"
  setup_singleline_secret_with_identity "03/secret1" "$POPPY.key"
  setup_singleline_secret_without_comments "04/secret1"
  setup_singleline_secret_with_identity "05/secret1" "$POPPY.key"

}

# $PASSAGE_DIR/templates/
# ├── crazy_secret.txt
# ├── inaccessible_secret.txt
# ├── multiple_secrets.txt
# └── single_secret.txt
setup_templates() {
  mkdir -p "$PASSAGE_DIR/templates"

  cat<<EOF > "$PASSAGE_DIR/templates/crazy_secret.txt"
okay secret: {{{/./..//-//././../00/secret}}}
EOF

  cat<<EOF > "$PASSAGE_DIR/templates/inaccessible_secret.txt"
not okay secret: {{{01/00/secret3}}}
not okay secret: {{{01/00/secret3}}}
EOF

  cat<<EOF > "$PASSAGE_DIR/templates/single_secret.txt"
this is a template with a single secret
{{{ this_should_not_be_substituted }}}
TEXT BEFORE SECRET{{{single_secret}}}TEXT AFTER SECRET
EOF

  cat<<EOF > "$PASSAGE_DIR/templates/single_secret_for_groups.txt"
this is a template with a single secret
{{{ this_should_not_be_substituted }}}
TEXT BEFORE SECRET-{{{03/secret1}}}-TEXT AFTER SECRET
EOF

  cat<<EOF > "$PASSAGE_DIR/templates/single_secret_for_everyone.txt"
this is a template with a single secret
{{{ this_should_not_be_substituted }}}
TEXT BEFORE SECRET-{{{04/secret1}}}-TEXT AFTER SECRET
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
