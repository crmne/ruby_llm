#!/usr/bin/env bash
# Build stable release docs at /, main at /next/, and the latest 1.x at /v1/.
# Run directly. --serve to preview on :4000.
set -euo pipefail

unset RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLE_BIN BUNDLE_APP_CONFIG

BASE="${BASE:-}"
BASE="${BASE%/}"
PORT="${PORT:-4000}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docs="$repo_root/docs"
site="${SITE:-$docs/_site}"
gemfile="$docs/Gemfile"
registry="${MODEL_REGISTRY_FILE:-$repo_root/lib/ruby_llm/models.json}"
releases="$(ruby "$docs/bin/release_tags.rb" "$repo_root")"
read -r stable_ref onex_ref <<< "$releases"

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

archive_release() {
  local ref="$1" source="$2"
  shift 2
  mkdir -p "$source"
  git -C "$repo_root" archive "$ref" docs/ lib/ "$@" | tar -x -C "$source"
  if git -C "$repo_root" cat-file -e "$ref:.rdoc_options" 2>/dev/null; then
    git -C "$repo_root" show "$ref:.rdoc_options" > "$source/.rdoc_options"
  else
    cp "$repo_root/.rdoc_options" "$source/.rdoc_options"
  fi
}

prepare_version() {
  local source="$1" channel="$2"
  mkdir -p "$source/_data" "$source/_includes" "$source/_plugins"
  cp "$docs/_data/versions.yml" "$source/_data/versions.yml"
  cp "$docs/_includes/version_select.html" "$source/_includes/"
  cp "$docs/_plugins/versioned_docs.rb" "$source/_plugins/"
  cp -R "$docs/_plugins/social_cards.rb" "$docs/_plugins/social_cards" "$source/_plugins/"
  sed -i.bak '/^ *- jekyll-og-image$/d' "$source/_config.yml" && rm "$source/_config.yml.bak"
  ruby "$docs/bin/prepare_versions.rb" "$source/_data/versions.yml" "$channel" "$BASE" "$stable_ref" "$onex_ref"
}

share_home_tour() {
  local source="$1"
  cp "$docs/_includes/home_tour.html" "$source/_includes/"
  cp "$docs/assets/css/home-tour.css" "$source/assets/css/"
  cp "$docs/assets/images/home/tour-cover.jpg" "$source/assets/images/home/"
  perl -0pi -e 's{    <div class="home-demo-frame" data-demo-video>\n.*?<img class="home-demo-avatar"[^\n]*\n    </div>\n}{    \{% include home_tour.html %\}\n}s' \
    "$source/index.md"
}

render_models_page() {
  local source="$1" docs_dir="$2"
  BUNDLE_GEMFILE="$repo_root/Gemfile" bundle exec ruby "$docs/bin/render_models_page.rb" \
    "$source" "$registry" "$docs_dir/_reference/available-models.md"
}

build_version() {
  local source="$1" output="$2" prefix="$3" api_source="$4"
  ( cd "$source" && BUNDLE_GEMFILE="$gemfile" bundle exec jekyll build --baseurl "$prefix" -d "$output" --quiet )
  SITE_BASE_URL="https://rubyllm.com${prefix}" "$docs/bin/build-api.sh" "$output/api" "$api_source"
}

echo "==> Building stable docs ($stable_ref) -> /"
archive_release "$stable_ref" "$workspace/stable" tasks/
prepare_version "$workspace/stable/docs" stable
share_home_tour "$workspace/stable/docs"
render_models_page "$workspace/stable" "$workspace/stable/docs"
build_version "$workspace/stable/docs" "$workspace/stable-out" "$BASE" "$workspace/stable"

echo "==> Building next docs (main) -> /next/"
mkdir -p "$workspace/next"
rsync -a --exclude='_site' --exclude='_data_serve' --exclude='_config_serve.yml' --exclude='vendor' --exclude='.jekyll-cache' --exclude='.bundle' "$docs/" "$workspace/next/"
prepare_version "$workspace/next" next
render_models_page "$repo_root" "$workspace/next"
build_version "$workspace/next" "$workspace/next-out" "$BASE/next" "$repo_root"

echo "==> Building 1.x docs ($onex_ref) -> /v1/"
archive_release "$onex_ref" "$workspace/v1"
"$docs/bin/prepare_one_x_docs.rb" "$workspace/v1/docs"
prepare_version "$workspace/v1/docs" v1
perl -0pi -e 's{(\{% include components/header.html %\}\n)}{$1    {% include version_select.html %}\n}' \
  "$workspace/v1/docs/_layouts/default.html"
build_version "$workspace/v1/docs" "$workspace/v1-out" "$BASE/v1" "$workspace/v1"

echo "==> Assembling -> $site"
rm -rf "$site"
mkdir -p "$site/next" "$site/v1"
cp -a "$workspace/stable-out/." "$site/"
cp -a "$workspace/next-out/." "$site/next/"
cp -a "$workspace/v1-out/." "$site/v1/"
ruby "$docs/bin/build_version_redirects.rb" "$site" "$BASE"
cp "$registry" "$site/models.json"
rm -rf "$workspace"
trap - EXIT

echo "Done.  / = $stable_ref   /next/ = main   /v1/ = $onex_ref   /models.json = live registry"
if [[ "${1:-}" == "--serve" ]]; then
  exec python3 -m http.server "$PORT" --directory "$site"
fi
