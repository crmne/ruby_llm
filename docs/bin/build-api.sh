#!/usr/bin/env bash
# Build the RDoc API docs into the given directory, landing on the RubyLLM module page.
#   docs/bin/build-api.sh <output-dir>
set -euo pipefail

out="${1:?usage: build-api.sh <output-dir>}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "$out" in /*) ;; *) out="$repo/$out" ;; esac

( cd "$repo" && bundle exec rdoc --output "$out" --quiet lib )
( cd "$repo" && bundle exec ruby docs/bin/export-api-markdown.rb "$out" )

# Give /api/ a real index page. GitHub Pages cannot emit a server-side redirect,
# and a crawlable landing is preferable to a client-side meta refresh.
cat > "$out/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>RubyLLM Ruby API Reference</title>
<meta name="description" content="Generated Ruby API documentation for RubyLLM classes, modules, and methods.">
<meta property="og:type" content="website">
<meta property="og:title" content="RubyLLM Ruby API Reference">
<meta property="og:description" content="Generated Ruby API documentation for RubyLLM classes, modules, and methods.">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="RubyLLM Ruby API Reference">
<meta name="twitter:description" content="Generated Ruby API documentation for RubyLLM classes, modules, and methods.">
<link href="./css/rdoc.css?v=8.0.0" rel="stylesheet">
</head>
<body role="document">
<main class="main-content">
<h1>RubyLLM Ruby API Reference</h1>
<p>Generated documentation for RubyLLM classes, modules, and methods.</p>
<p><a href="RubyLLM.html">Open the RubyLLM module reference</a></p>
</main>
</body>
</html>
HTML

( cd "$repo" && bundle exec ruby docs/bin/postprocess_api_seo.rb "$out" "${SITE_BASE_URL:-https://rubyllm.com/next}" )
