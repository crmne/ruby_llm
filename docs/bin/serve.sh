#!/usr/bin/env bash
# Preview all versions and rebuild /next/ when the working tree changes.
# Run directly, not via bundle exec/rake.
#   docs/bin/serve.sh   |   PORT=4002 docs/bin/serve.sh
set -euo pipefail

unset RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLE_BIN BUNDLE_APP_CONFIG

cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec bundle exec jekyll-vitepress serve --port "${PORT:-4000}"
