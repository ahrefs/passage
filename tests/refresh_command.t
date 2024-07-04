  $ . ./setup_fixtures.sh

Encrypt a secret file with identity
  $ cat <<EOF | passage create test_secret
  > 
  > 
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF

Should refresh test_secret, 00/.secret_starting_with_dot, 00/secret1, 01/secret1, 02/secret1
Should skip 01/00/secret1, 01/00/secret2, 03/secret1
Should show individual operations on secrets when -v is passed
  $ passage refresh
  I: refreshed 6 secrets, skipped 4, failed 0
  $ passage refresh -v
  I: refreshed 00/.secret_starting_with_dot
  I: refreshed 00/secret1
  I: skipped 01/00/secret1
  I: skipped 01/00/secret2
  I: refreshed 01/secret1
  I: refreshed 02/secret1
  I: skipped 03/secret1
  I: refreshed 04/secret1
  I: skipped 05/secret1
  I: refreshed test_secret
  I: refreshed 6 secrets, skipped 4, failed 0

Refreshed secrets should have the same permissions as before (0o644)
  $ stat -c "%a" $PASSAGE_DIR/secrets/test_secret.age
  644

Secret content should be the same before and after refresh.
  $ passage cat test_secret
  
  
  secret line 1
  secret line 2
  secret line 3\123\65

Secret should be viewable by those specified in .keys after refresh
  $ PASSAGE_IDENTITY="robby.rob.key" passage cat test_secret
  
  
  secret line 1
  secret line 2
  secret line 3\123\65

Should fail - refreshing invalid directory with no secrets
  $ passage refresh invalid_dir
  E: no secrets at invalid_dir
  [1]

Should succeed - refreshing a specific secret
  $ passage refresh -v test_secret
  I: refreshed test_secret
  I: refreshed 1 secrets, skipped 0, failed 0

Refreshing a path that has the same name as a secret - should refresh secrets in the path instead of the specific secret
  $ mkdir $PASSAGE_DIR/secrets/dir
  $ cp $PASSAGE_DIR/secrets/.keys $PASSAGE_DIR/secrets/dir/
  $ setup_singleline_secret_without_comments dir/secret1
  $ setup_singleline_secret_without_comments dir/secret2
 Create a secret named 'dir', which is also the name of an existing directory
  $ setup_singleline_secret_without_comments dir
  $ passage refresh -v dir
  I: refreshed dir/secret1
  I: refreshed dir/secret2
  I: refreshed 2 secrets, skipped 0, failed 0
