#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=${1:?Usage: Scripts/render-homebrew-cask.sh VERSION SHA256 OUTPUT}
checksum=${2:?Usage: Scripts/render-homebrew-cask.sh VERSION SHA256 OUTPUT}
output=${3:?Usage: Scripts/render-homebrew-cask.sh VERSION SHA256 OUTPUT}
template="$project_dir/Packaging/homebrew/drawstate.rb.template"

[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Invalid version: $version" >&2; exit 1; }
[[ "$checksum" =~ '^[0-9a-f]{64}$' ]] || { echo "Invalid SHA-256" >&2; exit 1; }

sed -e "s/VERSION/$version/g" -e "s/SHA256/$checksum/g" "$template" > "$output"
ruby -c "$output"
