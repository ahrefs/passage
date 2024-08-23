#!/bin/bash

# Define variables
completion_dir="$HOME/.local/share/bash-completion"
completion_file="passage-completion.sh"
completion_path="$completion_dir/$completion_file"
bashrc="$HOME/.bashrc"
source_line="source $completion_path"

# Check if the ~/.local/share/bash-completion directory exists, create it if it doesn't
# If the directory doesn't exist it's likely the first time the script is run. We don't want to repeat it every time.
if [ ! -d "$completion_dir" ]; then
  echo "Setting up bash completions for Passage. Installing in $completion_dir and source them in your .bashrc file."
  echo "Directory $completion_dir does not exist. Creating it."
  mkdir -p "$completion_dir"
fi

if [ ! -f "$completion_path" ]; then
  # Copy the passage-completion.sh file into the completion directory, replacing any existing file
  echo "Copying $completion_file into $completion_dir."
fi

# Always copy the file, even if it already exists. This will update the completions
cp -f "$completion_file" "$completion_path"

# Check if the source line is already in the ~/.bashrc file, append it if not
if ! grep -Fq "$source_line" "$bashrc"; then
  echo "Updating $bashrc to source the completions."
  echo "$source_line" >> "$bashrc"

  # Source the completions in the current shell
  source "$completion_path"
fi
