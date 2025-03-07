#!/usr/bin/env bash

# source it in your bashrc/zshrc or link into /etc/bash_completion.d/ or /usr/share/zsh/site-functions/

# Common functions for both shells
_passage_list_secrets() {
  local CONF_DIR="${PASSAGE_DIR:-${HOME}/.config/passage}"
  local SECR_DIR="${PASSAGE_SECRETS:-${CONF_DIR}/secrets}"
  find -L "${SECR_DIR}/" -name '*.age' -type f -printf '%P\n' | sed s/.age$//
}

_passage_list_recipients() {
  local CONF_DIR="${PASSAGE_DIR:-${HOME}/.config/passage}"
  local KEYS_DIR="${PASSAGE_KEYS:-${CONF_DIR}/keys}"
  find -L "${KEYS_DIR}/" -name '*.pub' -type f -printf '%P\n' | sed s/.pub$//
}

# BASH COMPLETION
if [[ -n "$BASH_VERSION" ]]; then
  # Do completion from a passed list of paths
  #
  # Accepts 2 arguments
  # 1. The list of paths to complete from
  # 2. The current word being completed
  #
  # Reference: https://stackoverflow.com/a/19974100
  _passage_paths_completion() {
    # This forces readline to only display the last item separated by a slash
    compopt -o filenames

    local IFS=$'\n'
    local k="${#COMPREPLY[@]}"

    for path in $(compgen -W "$1" -- $2)
    do
      local trailing_trim

      # Determine what to trim from the end
      trailing_trim="${path#${2%/*}/}/"
      trailing_trim="${trailing_trim#*/}"
      trailing_trim="${trailing_trim%/}"

      # Don't add a space if there is more to complete
      [[ "$trailing_trim" != "" ]] && compopt -o nospace

      # Remove the slash if mark-directories is off
      if ! _rl_enabled mark-directories
      then
        # If The current typed path doesnt have a slash in it yet check if
        # it is the full first portion of a path and ignore everything after
        # if it is. We don't have to do this once the typed path has a slash
        # in it as the logic above will pick up on it
        [[ "$2" != */* && "$path" == ${2}/* ]] && path="$2/$trailing_trim"

        trailing_trim="/$trailing_trim"
      fi

      # disable filenames option so that compgen doesn't append trailing slash
      compopt +o filenames
      COMPREPLY[k++]="${path%%${trailing_trim}}"
    done
  }

  _passage_completions()
  {
    if [ "${#COMP_WORDS[@]}" -le 2 ]; then
      local cmds="create delete edit edit-who get head list ls new realpath refresh replace search secret show template template-secrets what who"
      COMPREPLY=($(compgen -W "$cmds" -- "${COMP_WORDS[1]}"))
    else
      case "${COMP_WORDS[1]}" in
      search)
        # add autocomplete only for 3rd arg. Skip 2nd arg as it corresponds to pattern
        if [[ $COMP_CWORD == 3 ]]; then
          _passage_paths_completion "$(_passage_list_secrets)" "${COMP_WORDS[$COMP_CWORD]}"
        fi;;
      template)
        # add autocomplete only for 2nd and 3rd arg (corresponding to template and target file respectively)
        if [[ $COMP_CWORD == 2 || $COMP_CWORD == 3 ]]; then
          compopt -o default
        fi;;
      template-secrets)
        if [[ $COMP_CWORD == 2 ]]; then
          compopt -o default
        fi;;
      what)
        # add autocomplete only for 2nd arg
        if [[ $COMP_CWORD == 2 ]]; then
          COMPREPLY=($(compgen -W "$(_passage_list_recipients)" -- "${COMP_WORDS[$COMP_CWORD]}"))
        fi;;
      *)
        # add autocomplete only for 2nd arg
        if [[ $COMP_CWORD == 2 ]]; then
          _passage_paths_completion "$(_passage_list_secrets)" "${COMP_WORDS[$COMP_CWORD]}"
        fi;;
      esac
    fi
  }

  complete -F _passage_completions passage

# ZSH COMPLETION
elif [[ -n "$ZSH_VERSION" ]]; then
  # Function to complete paths with proper handling of directories
  _passage_zsh_path_completion() {
    local secrets
    secrets=($(_passage_list_secrets))
    _describe 'secrets' secrets
  }

  # Function to complete recipients
  _passage_zsh_recipient_completion() {
    local recipients
    recipients=($(_passage_list_recipients))
    _describe 'recipients' recipients
  }

  # Main completion function for passage in zsh
  _passage() {
    local -a commands
    commands=(
      'create:Create a new secret'
      'delete:Delete a secret'
      'edit:Edit a secret'
      'edit-who:Edit recipients for a secret'
      'get:Get a secret'
      'head:View the first few lines of a secret'
      'list:List all secrets'
      'ls:List all secrets (alias for list)'
      'new:Create a new secret (alias for create)'
      'realpath:Show the real path of a secret'
      'refresh:Refresh the cache'
      'replace:Replace a secret'
      'search:Search secrets with a pattern'
      'secret:Create a secret from input'
      'show:Show a secret (alias for get)'
      'template:Process a template file'
      'template-secrets:Process secrets into a template'
      'what:Show which identity file(s) correspond to a recipient'
      'who:List the recipients of a secret'
    )

    _arguments -C \
      '1: :->command' \
      '*: :->args'

    case $state in
      command)
        _describe 'command' commands
        ;;
      args)
        case ${words[2]} in
          search)
            if (( CURRENT == 3 )); then
              # Pattern argument - no completion
              return 0
            elif (( CURRENT == 4 )); then
              _passage_zsh_path_completion
            fi
            ;;
          template)
            if (( CURRENT == 3 || CURRENT == 4 )); then
              _files
            fi
            ;;
          template-secrets)
            if (( CURRENT == 3 )); then
              _files
            fi
            ;;
          what)
            if (( CURRENT == 3 )); then
              _passage_zsh_recipient_completion
            fi
            ;;
          *)
            if (( CURRENT == 3 )); then
              _passage_zsh_path_completion
            fi
            ;;
        esac
        ;;
    esac
  }

  # Special case for when this file is sourced directly
  if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]]; then
    compdef _passage passage
  fi
  
  # IMPORTANT: Return at this point to indicate this is a valid completion function
  return 0
fi
