  $ . ./setup_fixtures.sh

Should pass basic healthcheck with valid secrets
  $ passage healthcheck  
  
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  SUCCESS: secrets all have .keys in the immediate directory
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues

Should detect folders without .keys files
Setup folder without .keys file
  $ mkdir -p "$PASSAGE_DIR/secrets/bad_folder"
  $ echo "test content" | passage create bad_folder/secret
  
  I: using recipient group @root for secret bad_folder/secret
  I: using recipient bobby.bob for secret bad_folder/secret
  
  If you are adding a new secret in a new folder, please keep recipients to a minimum and include the following:
  - @root
  - yourself
  - people who help manage the secret, or people who would have access to it anyway
  - people who need access to do their job
  - servers/clusters that will consume the secret
  
  If the secret is a staging secret, its only recipient should be @everyone.
  
  $ rm "$PASSAGE_DIR/secrets/bad_folder/.keys"
  $ passage healthcheck
  
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  ERROR: found paths with secrets but no .keys file:
  - bad_folder
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues
  [1]


Should support verbose mode showing individual secret validation
  $ passage healthcheck -v
  
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  ERROR: found paths with secrets but no .keys file:
  - bad_folder
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  ✅ 00/.secret_starting_with_dot [ valid single-line ]
  ✅ 00/secret1 [ valid single-line ]
  ✅ 01/secret1 [ valid single-line ]
  ✅ 02/secret1 [ valid single-line ]
  ✅ 04/secret1 [ valid single-line ]
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues
  [1]


Should support dry-run upgrade mode for legacy secrets
  $ passage healthcheck --dry-run-upgrade-legacy-secrets
  
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  ERROR: found paths with secrets but no .keys file:
  - bad_folder
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues
  [1]


