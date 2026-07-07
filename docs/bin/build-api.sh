#!/usr/bin/env bash
# Build the RDoc API docs into the given directory, landing on the RubyLLM module page.
#   docs/bin/build-api.sh <output-dir>
set -euo pipefail

out="${1:?usage: build-api.sh <output-dir>}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "$out" in /*) ;; *) out="$repo/$out" ;; esac

( cd "$repo" && bundle exec rdoc --output "$out" --quiet lib )
( cd "$repo" && bundle exec ruby docs/bin/export-api-markdown.rb "$out" )

# RDoc's main page must be a file, so the curated landing lives in the RubyLLM
# module doc and the index redirects there.
cat > "$out/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=RubyLLM.html">
<link rel="canonical" href="RubyLLM.html">
<title>RubyLLM API</title>
</head>
<body><a href="RubyLLM.html">RubyLLM API documentation</a></body>
</html>
HTML
