#!/usr/bin/env bash

# source it in your bashrc or link into /etc/bash_completion.d/

_passage_list_secrets() {
  local CONF_DIR="${PASSAGE_DIR:-${HOME}/.config/passage}"
  local SECR_DIR="${PASSAGE_SECRETS:-${CONF_DIR}/secrets}"
  find -L "${SECR_DIR}/" -name '*.age' -type f -printf '%P\n' | sed s/.age$//
}

_passage_list_recipients() {
  local CONF_DIR="${PASSAGE_DIR:-${HOME}/.config/passage}"
  local KEYS_DIR="${PASSAGE_KEYS:-${CONF_DIR}/keys}"
  # First list groups with @ prefix
  find -L "${KEYS_DIR}/" -name '*.group' -type f -printf '@%P\n' | sed s/.group$//
  # Then list regular recipients
  find -L "${KEYS_DIR}/" -name '*.pub' -type f -printf '%P\n' | sed s/.pub$//
}

_passage_list_recipients_and_paths() {
  local CONF_DIR="${PASSAGE_DIR:-${HOME}/.config/passage}"
  local KEYS_DIR="${PASSAGE_KEYS:-${CONF_DIR}/keys}"
  local SECR_DIR="${PASSAGE_SECRETS:-${CONF_DIR}/secrets}"

  # If we're at the top level or no path is typed yet, show groups and top-level secrets
  if [[ "${COMP_WORDS[$COMP_CWORD]}" != */* ]]; then
    # First list groups with @ prefix
    find -L "${KEYS_DIR}/" -name '*.group' -type f -printf '@%P\n' | sed s/.group$//
    # Then list only top-level secrets and folders, excluding base dir
    find -L "${SECR_DIR}/" -mindepth 1 -maxdepth 1 \( -name '*.age' -type f -o -type d \) -printf '%P\n' | \
      while read -r entry; do
        if [[ -d "${SECR_DIR}/$entry" ]]; then
          echo "$entry/"
        elif [[ $entry == *.age ]]; then
          echo "${entry%.age}"
        else
          echo "$entry"
        fi
      done
  else
    # For deeper levels, only show secrets and folders in that path
    local current_path="${SECR_DIR}/${COMP_WORDS[$COMP_CWORD]%/*}"
    find -L "$current_path/" -mindepth 1 -maxdepth 1 \( -name '*.age' -type f -o -type d \) -printf "%P\n" | \
      while read -r entry; do
        if [[ -d "${current_path}/$entry" ]]; then
          echo "${COMP_WORDS[$COMP_CWORD]%/*}/$entry/"
        elif [[ $entry == *.age ]]; then
          echo "${COMP_WORDS[$COMP_CWORD]%/*}/${entry%.age}"
        else
          echo "${COMP_WORDS[$COMP_CWORD]%/*}/$entry"
        fi
      done
  fi
}

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
    local cmds="cat create delete edit edit-who get healthcheck init list ls new realpath refresh replace replace-comment rm search secret show subst template template-secrets what who"
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
    who)
      # add autocomplete only for 2nd arg
      if [[ $COMP_CWORD == 2 ]]; then
        compopt -o nospace
        COMPREPLY=($(compgen -W "$(_passage_list_recipients_and_paths)" -- "${COMP_WORDS[$COMP_CWORD]}"))
      fi;;
    *)
      # add autocomplete only for 2nd arg for remaining commands
      if [[ $COMP_CWORD == 2 ]]; then
        _passage_paths_completion "$(_passage_list_secrets)" "${COMP_WORDS[$COMP_CWORD]}"
      fi;;
    esac
  fi
}

complete -F _passage_completions passage
