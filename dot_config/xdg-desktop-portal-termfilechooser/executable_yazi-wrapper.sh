#!/usr/bin/env sh
# @file yazi-wrapper.sh
# @brief Select portal files in Yazi through Foot.
# @description Uses the termfilechooser wrapper argument contract without re-evaluating application-supplied paths as shell commands.
set -eu

directory=$2
path=$4
out=$5
cwd=

# The packaged wrapper rebuilds a shell command, allowing expansion of dollar signs and backticks in suggested filenames.
set -- --chooser-file="$out" "$path"
if [ "$directory" = 1 ]; then
    cwd=$(mktemp)
    trap 'rm -f -- "$cwd"' EXIT
    set -- --cwd-file="$cwd" "$@"
fi

foot --title 'File picker — Yazi' yazi "$@"

# In directory mode, quitting inside a folder selects it even without an explicit selection.
if [ -n "$cwd" ] && [ ! -s "$out" ]; then
    cat -- "$cwd" > "$out"
fi
