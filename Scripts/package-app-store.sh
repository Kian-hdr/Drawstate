#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${1:-release}

exec "$project_dir/Scripts/package-app.sh" "$configuration" app-store
