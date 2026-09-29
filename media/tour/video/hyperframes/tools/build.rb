# Builds compositions/*.html (and index.html) from src/*.html.
#   {{code NAME}}        Ruby-highlighted block, one .ln per line, tokens carry data-c (column)
#   {{code:LANG NAME}}   same with another Rouge lexer (json, python, shell, ruby)
#   {{inline NAME}}      Ruby-highlighted single line, tokens carry data-c
#   {{file PATH}}        raw file contents
require "rouge"
require "cgi"

ROOT = File.expand_path("..", __dir__)
SNIPPETS = eval(File.read(File.join(ROOT, "tools/snippets.rb")))

def lexer(lang)
  { "ruby" => Rouge::Lexers::Ruby, "json" => Rouge::Lexers::JSON, "python" => Rouge::Lexers::Python,
    "shell" => Rouge::Lexers::Shell, "text" => Rouge::Lexers::PlainText }.fetch(lang).new
end

def highlight_lines(code, lang)
  lines = [[]]
  col = 0
  lexer(lang).lex(code).each do |token, value|
    value.split("\n", -1).each_with_index do |part, i|
      if i > 0
        lines << []
        col = 0
      end
      next if part.empty?
      cls = token.shortname.to_s
      part.scan(/\S+|\s+/).each do |piece|
        if piece.strip.empty?
          lines.last << CGI.escapeHTML(piece)
        else
          lines.last << %(<span class="t #{cls}" data-c="#{col}">#{CGI.escapeHTML(piece)}</span>)
        end
        col += piece.length
      end
    end
  end
  lines.pop if lines.last.empty? && code.end_with?("\n")
  lines
end

def code_block(name, lang = "ruby")
  highlight_lines(SNIPPETS.fetch(name), lang).each_with_index.map do |parts, i|
    body = parts.empty? ? "&#8203;" : parts.join
    %(<span class="ln" data-ln="#{i}">#{body}</span>)
  end.join
end

def inline(name)
  highlight_lines(SNIPPETS.fetch(name), "ruby").map(&:join).join("\n")
end

Dir[File.join(ROOT, "src/*.html")].each do |src|
  html = File.read(src)
  3.times do
    html = html.gsub(/\{\{file ([^}]+)\}\}/) { File.read(File.join(ROOT, $1.strip)) }
  end
  html = html.gsub(/\{\{code:(\w+) ([\w-]+)\}\}/) { code_block($2, $1) }
  html = html.gsub(/\{\{code ([\w-]+)\}\}/) { code_block($1) }
  html = html.gsub(/\{\{inline ([\w-]+)\}\}/) { inline($1) }
  out = File.basename(src) == "index.html" ? File.join(ROOT, "index.html") : File.join(ROOT, "compositions", File.basename(src))
  File.write(out, html)
end
puts "built"
