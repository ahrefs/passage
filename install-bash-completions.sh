#!/bin/bash

# Define variables
completion_dir="$HOME/.local/share/bash-completion"
completion_file="passage-completion.sh"
completion_path="$completion_dir/$completion_file"
bashrc="$HOME/.bashrc"
source_line="source $completion_path"

# Check if the ~/.local/share/bash-completion directory exists, create it if it doesn't
if [ ! -d "$completion_dir" ]; then
  mkdir -p "$completion_dir"
fi

# Always copy the file, even if it already exists. This will update the completions
cp -f "$completion_file" "$completion_path"

# Check if the completions are already sourced in the ~/.bashrc file, inform on how to add completions if not
if ! grep -Fq "$source_line" "$bashrc"; then
  echo -e "Installed bash completions script for passage. To have them working, update the $bashrc file to source the completions: \n"
  echo "echo \"$source_line\" >> ~/.bashrc"
fi
