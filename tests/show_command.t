  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage show
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

Should succeed - curr dir as path
  $ passage show .
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

Should succeed - single-level path
  $ passage show 01
  .
  ├── 00
  │   ├── secret1
  │   └── secret2
  └── secret1

Should succeed - single-level path with trailing slash
  $ passage show 01/
  .
  ├── 00
  │   ├── secret1
  │   └── secret2
  └── secret1

Should succeed - multi-level path
  $ passage show 01/00
  .
  ├── secret1
  └── secret2

Should succeed - valid secret path that ends with ..
  $ passage show 01/..
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

Should succeed - valid secret path that includes .. in the middle
  $ passage show 01/../00
  .
  ├── .secret_starting_with_dot
  └── secret1

Should succeed - path that goes out of secrets dir points to the root
  $ passage show ..
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

  $ passage show ../
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

  $ passage show /..
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

  $ passage show /../
  .
  ├── 00
  │   ├── .secret_starting_with_dot
  │   └── secret1
  ├── 01
  │   ├── 00
  │   │   ├── secret1
  │   │   └── secret2
  │   └── secret1
  ├── 02
  │   └── secret1
  ├── 03
  │   └── secret1
  ├── 04
  │   └── secret1
  └── 05
      └── secret1

Should fail - single-level invalid path
  $ passage show invalid_path
  No secrets at this path : $TESTCASE_ROOT/fixtures/secrets/invalid_path
  [1]

Should fail - multi-level invalid path
  $ passage show 01/invalid_path
  No secrets at this path : $TESTCASE_ROOT/fixtures/secrets/01/invalid_path
  [1]

Should behave as cat when using on secrets paths
Setup a couple of secrets
  $ echo "secret" | passage create singleline_secret
  $ cat <<EOF | passage create multiline_secret
  > 
  > 
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF

Should succeed - access contents of secret file with correct identity
  $ passage cat singleline_secret
  secret
  $ passage cat multiline_secret
  
  
  secret line 1
  secret line 2
  secret line 3\123\65



Should try to decrypt and fail if not a recipient of the secret
  $ passage show 01/00/secret2
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 01/00/secret2 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]
