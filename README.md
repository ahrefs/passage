# Passage

`passage` - store and manage access to shared secrets

## Installation

```sh
apt install age
opam install . --deps-only
```

## Development

Building the project
```
make build
```

Running tests
```
make test
```

## Secret format

Multiline secrets:
```
<empty line>
possibly several lines of comments without empty lines
<empty line>
secret until end of file
```

Single-line secrets:
```
single-line secret
comments until end of file
```

The rationale for why we have 2 distinct secret formats for multiline and single-line secrets
(and not just multiline secrets) is mainly for backward compatibility reasons since most of
the existing secrets are of the "single-line secret" format.

## Commands

### Reading secrets

`passage get [--clip] [--line=LINE] [--qrcode] SECRET_NAME`
- Outputs the entire content of `SECRET_NAME`

`passage secret [--clip] [--qrcode] SECRET_NAME`
- Outputs only the secret content of `SECRET_NAME`. Specifically, comments are excluded.

`passage head [--clip] [--qrcode] SECRET_NAME`
- Outputs the first line of `SECRET_NAME`, and errors out on multiline secrets

`passage template TEMPLATE_FILE TARGET_FILE [KEY=VALUE]...`
- Generates `TARGET_FILE` by substituting all secrets in `TEMPLATE_FILE` based on the key-value mappings provided if any.
- Secrets in `TEMPLATE_FILE` are denoted with the following format `{{{secret_name}}}`. In particular, note the following:
  - Three opening and closing braces
  - No leading and trailing whitespaces before and after `secret_name`
  - `secret_name` must start with an alphabetical character (either lowercase or uppercase), followed by 0 or more alphanumeric characters, underscores, hyphens, slashes, or dots (reference: [template_lexer.ml](lib/template_lexer.ml))
- A key-value pair maps an identifier in the `TEMPLATE_FILE` to a secret name.

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

  $ passage template_file target_file

  $ cat target_file
  {
    "non_secret_config1": "hello",
    "sendgrid_api_key": "thesupersecretkey",
    "non_secret_config2": "bye",
  }
  ```

- Example when substituting a multiline secret:
  ```sh
  $ cat template_file
  foo{{{multiline_secret}}}bar

  $ passage get multiline_secret

  comment_line 1
  comment_line 2

  secret_line 1
  secret_line 2

  $ passage template_file target_file

  $ cat target_file
  foosecret_line 1
  secret_line 2bar
  ```

### Creating or updating secrets

`passage edit SECRET_NAME`
- Allows editing of `SECRET_NAME` using `$EDITOR`

`passage append SECRET_NAME`
- Appends the user input to `SECRET_NAME`

`passage replace SECRET_NAME`
- Replaces `SECRET_NAME` with the user input

### Managing secrets

`passage list [PATH]` / `passage ls [PATH]`
- Recursively list all secrets in `PATH`

`passage search PATTERN [PATH]`
- List all secrets in `PATH` containing contents matching `PATTERN`

`passage show [PATH]`
- Recursively list all secrets in `PATH` in a tree-like format

`passage refresh [PATH]`
- Re-encrypts all secrets in `PATH`

`passage who [PATH]`
- List all recipients of secrets in `PATh`

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
