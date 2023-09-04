  $ . ./setup_fixtures.sh

Set default target file
  $ TARGET="target.txt"

Should succeed - template with only 1 secret with no key-value pairs specified
 Single line secret without comments
  $ setup_singleline_secret_without_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: single lineTEXT AFTER SECRET

 Single line secret with comments - comments should not be substituted
  $ setup_singleline_secret_with_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: single lineTEXT AFTER SECRET

 Multiline secret without comments
  $ setup_multiline_secret_without_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: line 1
  (single_secret) secret: line 2TEXT AFTER SECRET

 Multiline secret with comments - comments should not be substituted
  $ setup_multiline_secret_with_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: line 1
  (single_secret) secret: line 2TEXT AFTER SECRET

Should succeed - template with only 1 secret with key-value pairs specified
  $ setup_multiline_secret_with_comments different/secret/name/from/template
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET single_secret=different/secret/name/from/template
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(different/secret/name/from/template) secret: line 1
  (different/secret/name/from/template) secret: line 2TEXT AFTER SECRET

Should succeed - template with multiple secrets with no key-value pairs specified
  $ setup_singleline_secret_with_comments multiple_secrets_1
  $ setup_multiline_secret_with_comments multiple_secrets_2
  $ passage template $PASSAGE_DIR/templates/multiple_secrets.txt $TARGET
  $ cat $TARGET
  this is a template with multiple_secrets
  {{{ this_should_not_be_substituted }}}
  first secret: (multiple_secrets_1) secret: single line
  
  second secret:
  (multiple_secrets_2) secret: line 1
  (multiple_secrets_2) secret: line 2
  
  end of file

Should succeed - template with multiple secrets with key-value pairs specified
  $ setup_singleline_secret_with_comments singleline/secret
  $ setup_multiline_secret_with_comments multiline/secret
  $ passage template $PASSAGE_DIR/templates/multiple_secrets.txt $TARGET multiple_secrets_1=singleline/secret multiple_secrets_2=multiline/secret
  $ cat $TARGET
  this is a template with multiple_secrets
  {{{ this_should_not_be_substituted }}}
  first secret: (singleline/secret) secret: single line
  
  second secret:
  (multiline/secret) secret: line 1
  (multiline/secret) secret: line 2
  
  end of file

Should fail - invalid key-value pairs
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET key
  passage: KEY_VALUE_PAIR… arguments: failed to parse key-value pair.
           Expected format of 'KEY=VALUE' but received 'key'
  Usage: passage template [OPTION]… TEMPLATE_FILE TARGET_FILE [KEY_VALUE_PAIR]…
  Try 'passage template --help' or 'passage --help' for more information.
  [124]
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET key=
  passage: KEY_VALUE_PAIR… arguments: failed to parse key-value pair.
           Expected format of 'KEY=VALUE' but received 'key='
  Usage: passage template [OPTION]… TEMPLATE_FILE TARGET_FILE [KEY_VALUE_PAIR]…
  Try 'passage template --help' or 'passage --help' for more information.
  [124]
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET =value
  passage: KEY_VALUE_PAIR… arguments: failed to parse key-value pair.
           Expected format of 'KEY=VALUE' but received '=value'
  Usage: passage template [OPTION]… TEMPLATE_FILE TARGET_FILE [KEY_VALUE_PAIR]…
  Try 'passage template --help' or 'passage --help' for more information.
  [124]
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET =
  passage: KEY_VALUE_PAIR… arguments: failed to parse key-value pair.
           Expected format of 'KEY=VALUE' but received '='
  Usage: passage template [OPTION]… TEMPLATE_FILE TARGET_FILE [KEY_VALUE_PAIR]…
  Try 'passage template --help' or 'passage --help' for more information.
  [124]

Should fail - invalid template file
  $ passage template non_existent_template $TARGET
  E: failed to substitute file : Sys_error("non_existent_template: No such file or directory")
  [1]
