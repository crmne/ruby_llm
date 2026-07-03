#!/usr/bin/env bash
# Serve the 2.0 docs live at / (with reload) and the frozen 1.x docs at /v1/.
# Run directly — not via bundle exec/rake (that leaks the gem bundle and breaks the Jekyll build).
#   docs/bin/serve.sh   |   PORT=4002 docs/bin/serve.sh
set -euo pipefail

# Drop the parent bundle's env so the docs Gemfile resolves on its own.
unset RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLE_BIN BUNDLE_APP_CONFIG

ONE_X_REF="${ONE_X_REF:-ec673f21}"   # last clean 1.x docs commit
PORT="${PORT:-4000}"

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docs="$repo/docs"
site="$docs/_site"
versions="$docs/_data/versions.yml"
latest="$(ruby -ryaml -e 'puts YAML.load_file(ARGV[0])["latest"]' "$versions")"

# The committed versions.yml with local URLs (next at /, the latest 1.x at /v1/) and a given `current`.
local_versions() { # <out> <current>
  ruby -ryaml -e '
    d = YAML.load_file(ARGV[0]); latest = d["latest"]
    d["items"].each { |i| i["url"] = "/" if i["id"] == "next"; i["url"] = "/v1/" if i["id"] == latest }
    d["current"] = ARGV[1]
    File.write(ARGV[2], YAML.dump(d))
  ' "$versions" "$2" "$1"
}

echo "==> Building frozen 1.x docs (@ $ONE_X_REF) -> /v1/"
onex="$(mktemp -d)"
git -C "$repo" archive "$ONE_X_REF" docs/ | tar -x -C "$onex"
cp "$docs/_includes/version_select.html" "$onex/docs/_includes/"
mkdir -p "$onex/docs/_data"
local_versions "$onex/docs/_data/versions.yml" "$latest"
perl -0pi -e 's{(\{% include components/header.html %\}\n)}{$1    {% include version_select.html %}\n}' \
  "$onex/docs/_layouts/default.html"
( cd "$onex/docs" && BUNDLE_GEMFILE="$docs/Gemfile" bundle exec jekyll build --baseurl /v1 -d "$site/v1" --quiet )
rm -rf "$onex"

# Serve live; versions come from a temp data dir so the committed versions.yml stays untouched.
mkdir -p "$docs/_data_serve"
local_versions "$docs/_data_serve/versions.yml" next
serve_cfg="$docs/_config_serve.yml"
printf "data_dir: _data_serve\nkeep_files: ['.git', '.svn', 'v1']\n" > "$serve_cfg"
trap 'rm -rf "$docs/_data_serve" "$serve_cfg"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "==> Serving http://localhost:$PORT/  (2.0 dev, live)   +   /v1/ (1.x)   — Ctrl-C to stop"
cd "$docs"
BUNDLE_GEMFILE="$docs/Gemfile" bundle exec jekyll serve --livereload --port "$PORT" --config _config.yml,_config_serve.yml
