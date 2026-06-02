#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <source_pgdata_dir> <target_pgdata_dir>" >&2
  exit 1
fi

source_dir=$1
target_dir=$2

if [[ ! -d "$source_dir" ]]; then
  echo "source directory not found: $source_dir" >&2
  exit 1
fi

mkdir -p "$target_dir"

rsync -a --delete "$source_dir"/ "$target_dir"/

echo "cloned PGDATA into $target_dir"
