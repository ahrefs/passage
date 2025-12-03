Should fail if passage is not configured, and show a message to run passage init
  $ PASSAGE_IDENTITY="" passage healthcheck
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ❌ ERROR: Passage is not set up
  
  Passage identity file not found. Please run 'passage init' to set up passage.
  [1]

Setup fixtures.
Tests will show the "from PASSAGE_IDENTITY environment variable" text
because PASSAGE_IDENTITY is exported in the fixtures setup script.
  $ . ./setup_fixtures.sh

Should show a warning if identity is not a recipient of any secrets
  $ age-keygen > "not_a_recipient.key" 2> /dev/null
  $ PASSAGE_IDENTITY="not_a_recipient.key" passage healthcheck 2>&1 | sed 's/Public key:.*$/Public key:/'
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ✅ Passage is configured
  
  ⚠️  WARNING: No registered recipient names found for your identity
  Identity key path: not_a_recipient.key (from PASSAGE_IDENTITY environment variable)
  
  Public key:
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  SUCCESS: secrets all have .keys in the immediate directory
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  ⚠️  Not a recipient of any secrets

Should pass basic healthcheck with valid secrets
  $ passage healthcheck 2>&1 | sed 's/Public key:.*$/Public key:/'
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ✅ Passage is configured
  
  Registered recipient name(s):
    - bobby.bob
  
  Identity key path: bobby.bob.key (from PASSAGE_IDENTITY environment variable)
  
  Public key:
  
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
  $ passage healthcheck 2>&1 | sed 's/Public key:.*$/Public key:/'
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ✅ Passage is configured
  
  Registered recipient name(s):
    - bobby.bob
  
  Identity key path: bobby.bob.key (from PASSAGE_IDENTITY environment variable)
  
  Public key:
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  ERROR: found paths with secrets but no .keys file:
  - bad_folder
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues

Should support verbose mode showing individual secret validation
  $ passage healthcheck -v 2>&1 | sed 's/Public key:.*$/Public key:/'
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ✅ Passage is configured
  
  Registered recipient name(s):
    - bobby.bob
  
  Identity key path: bobby.bob.key (from PASSAGE_IDENTITY environment variable)
  
  Public key:
  
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

Should support dry-run upgrade mode for legacy secrets
  $ passage healthcheck --dry-run-upgrade-legacy-secrets 2>&1 | sed 's/Public key:.*$/Public key:/'
  
  PASSAGE HEALTHCHECK. Diagnose for common problems
  
  ==========================================================================
  Checking passage installation
  ==========================================================================
  
  ✅ Passage is configured
  
  Registered recipient name(s):
    - bobby.bob
  
  Identity key path: bobby.bob.key (from PASSAGE_IDENTITY environment variable)
  
  Public key:
  
  ==========================================================================
  Checking for folders without .keys file
  ==========================================================================
  
  ERROR: found paths with secrets but no .keys file:
  - bad_folder
  
  ==========================================================================
  Checking for validity of own secrets. Use -v flag to break down per secret
  ==========================================================================
  
  
  I: 5 valid secrets, 0 invalid and 0 with decryption issues
