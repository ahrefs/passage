# Passage

`passage` - store and manage access to shared secrets

## Installation

```sh
apt install age
opam install . --deps-only --with-dev-setup
```

## Development

Building the project
```
make build
```

Running tests
```
make test
 # or
make promote
```

Running linting
```
make fmt
```


## Secret format

Multi-line secrets with comments:
```
<empty line>
possibly several lines of comments
without empty lines
<empty line>
secret until end of file
```

Multi-line secrets without comments:
```
<empty line>
<empty line>
secret until end of file
```

Single-line secrets with comments:
```
single-line secret
<empty line>
comments until end of file
```

Single-line secrets without comments:
```
single-line secret
```

The rationale for why we have 2 distinct secret formats for multi-line and single-line secrets
(and not just multi-line secrets) is mainly for backward compatibility reasons since most of
the existing secrets are of the "single-line secret" format.

## Commands

### Reading secrets

`passage get [-c, --clip] [-l, --line=LINE] [-q, --qrcode] [-s, --singleline] SECRET_NAME`
- Outputs the content of the text of the secret in `SECRET_NAME`, excluding comments

`passage secret [-c, --clip] [-l, --line=LINE] [-q, --qrcode] [-s, --singleline] SECRET_NAME`
- An alias of `passage get`

`passage cat [-c, --clip] [-l, --line=LINE] [-q, --qrcode] SECRET_NAME`
- Outputs the whole content of the secret in `SECRET_NAME`, including comments

`passage show SECRET_NAME`
- Outputs the whole content of the secret in `SECRET_NAME`, including comments. Behaves differently when used with PATHs, please check below.

### Templating with secrets

`passage template TEMPLATE_FILE [TARGET_FILE]`
- Generates `TARGET_FILE` by substituting all secrets in `TEMPLATE_FILE`
- Secrets in `TEMPLATE_FILE` are denoted with the following format `{{{subdir/secret_name}}}`. In particular, note the following:
  - Three opening and closing braces
  - No leading and trailing whitespaces before and after `secret_name`
  - `secret_name` must start with an alphanumeric character (either lowercase or uppercase), followed by 0 or more alphanumeric characters, underscores, hyphens, slashes, or dots (reference: [template_lexer.ml](lib/template_lexer.ml))

- Example when substituting a single-line secret:
  ```sh
  $ cat template_file
  {
    "non_secret_config1": "hello",
    "sendgrid_api_key": "{{{sendgrid_api_key}}}",
    "non_secret_config2": "bye",
  }

  $ passage get sendgrid_api_key
  thesupersecretkey
  the above is the sendgrid api key!

  $ passage template template_file
  {
    "non_secret_config1": "hello",
    "sendgrid_api_key": "thesupersecretkey",
    "non_secret_config2": "bye",
  }
  ```

- Example when substituting a multi-line secret:
  ```sh
  $ cat template_file
  foo{{{multiline_secret}}}bar

  $ passage get multiline_secret

  comment_line 1
  comment_line 2

  secret_line 1
  secret_line 2

  $ passage template template_file target_file

  $ cat target_file
  foosecret_line 1
  secret_line 2bar
  ```

`passage subst [TEMPLATE_ARG]`
- similar to passage template, but you pass in a string template and the result is output to stdout
  ```bash
  $ passage secret test/secret
  unbelievable stuff

  $ passage subst "This secret is {{{test/secret}}}"
  This secret is unbelievable stuff
  ```

`passage template-secrets [TEMPLATE_FILE]`
- returns a list of sorted secrets identified in that template file per the parse format
- secrets are not checked for existence

### Specifying recipients

Secrets' recipients are specified in the `.keys` file in the immediately containing folder.  The first time a folder is used, passage will create this file. If no recipients are specified, it falls back to the caller as the sole recipient based on the file referenced by `$PASSAGE_IDENTITY`.

Recipients are not inherited from containing (parent) folders. Recipients in a folder can only be increased when added by the existing recipients.

All secrets in a given folder must share the same set of recipients.

`passage edit-who SECRET_NAME`
- edit the recipients for the specified secret (and path).

### Creating or updating secrets

`passage new SECRET_NAME`
- Interactive secret creation using `$EDITOR` and prompts.
- Can only be used in interactive shell

`passage create SECRET_NAME`
- Creates a secret using contents from standard input. Use Ctrl+d twice to signal end of input.
- Can pipe from another command into `passage create`. E.g.:
```bash
$ echo "secret" | passage create secret_folder/secret
```

`passage edit SECRET_NAME`
- Interactive editing of `SECRET_NAME` using `$EDITOR`
- Can only be used in interactive shell

`passage replace SECRET_NAME`
- Replaces `SECRET_NAME`'s secret with the user input and keeps the comments. Use Ctrl+d twice to signal end of input.
- If you use `replace` on a secret that doesn't exist, it creates a new secret without comments (only in folders where the user is already a recipient)

`passage rm [--force] [--verbose] SECRET_NAME / passage delete [--force] [--verbose] SECRET_NAME`
- Deletes `SECRET_NAME` path
- If `SECRET_NAME` is the only secret in that folder, passage deletes the whole folder

### Managing secrets

`passage list [PATH]` / `passage ls [PATH]`
- Recursively list all secrets in `PATH`

`passage search PATTERN [PATH]`
- List all secrets in `PATH` containing contents matching `PATTERN`

`passage show [PATH]`
- Recursively list all secrets in `PATH` in a tree-like format
- Will work the same way as `cat` when used with secret names instead of a PATH. Doesn't take any arguments or flags

`passage refresh [PATH]`
- Re-encrypts all secrets in `PATH` per the recipients in the corresponding .keys file

`passage who [PATH]`
- List all recipients of secrets in `PATH`

`passage what RECIPIENT_NAME`
- List all secrets that `RECIPIENT_NAME` has access to

## Environment Variables

`PASSAGE_DIR`
- Overrides the default `passage` directory.

`PASSAGE_KEYS`
- Overrides the default `passage` keys directory.

`PASSAGE_SECRETS`
- Overrides the default `passage` secrets directory.

`PASSAGE_IDENTITY`
- Overrides the default identity `.key` file that will be used by `passage`

`PASSAGE_X_SELECTION`
- Overrides the default X selection to use when clipping to clipboard.
  Allowed values are `primary`, `secondary`, or `clipboard` (default).

`PASSAGE_CLIP_TIME`
- Overrides the default clip time. Specified in seconds.

## Utilities

`passage healthcheck`
- checks for issues with secrets, and for directories without `.keys` file

`passage realpath [--verbose] [PATH]`
- show the full filesystem path to secrets/folders
