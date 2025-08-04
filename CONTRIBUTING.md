# Contributing to RubyLLM

Thanks for considering contributing! Here's what you need to know.

## Philosophy & Scope

RubyLLM does one thing well: **LLM communication in Ruby**.

### ✅ We Want
- LLM provider integrations and new provider features
- Convenience that benefits most users (Rails generators, etc.)
- Performance and API consistency improvements

### ❌ We Don't Want
- Application architecture (testing, persistence, error tracking)
- One-off solutions you can build in your app
- Auxiliary features unrelated to LLM communication

### Requests We'll Close
- **RAG support** → Use dedicated libraries
- **Prompt templates** → Use ERB/Mustache in your app
- **Model data fixes** → File with [Parsera](https://github.com/parsera-labs/api-llm-specs/issues)
- **Auto-failover** → Use `.with_model()` (works mid-conversation, even across providers)
- **Tool interface changes** → Handle in your tool's initializer
- **Testing helpers** → Use dependency injection

**The rule:** If you can solve it in application code, you should.

## Response Times & Paid Work

This is unpaid work I do between other priorities. I respond when I can.

**Need something fast?** Email **carmine@paolino.work** for paid development. $200/hour, 10-hour minimum ($2000).

## Quick Start

```bash
gh repo fork crmne/ruby_llm --clone && cd ruby_llm
bundle install
overcommit --install
gh issue develop 123 --checkout  # or create your own branch
# make changes, add tests
gh pr create --web
```

## Essential Rules

1. **Run `overcommit --install` before doing anything** - it auto-fixes style, runs tests, and updates model files on commit
2. **Don't edit `models.json` or `aliases.json`** - overcommit regenerates them automatically
3. **Write clear PR descriptions** - explain what and why

The git hooks handle style, tests, and file generation for you. No excuses for broken commits.

## Testing

Run linting: `bundle exec rubocop`

Run tests: `bundle exec rspec`

**Re-recording VCR cassettes?** Set API keys and run:
```bash
bundle exec rake vcr:record[openai,anthropic]  # specific providers
bundle exec rake vcr:record[all]               # everything
```

**Then inspect the YAML files** - make sure no API keys leaked.

## Model Registry

**Don't touch these files directly:**
- `models.json` - auto-generated from provider APIs + [Parsera](https://api.parsera.org/v1/llm-specs)
- `aliases.json` - auto-generated from models.json

**To update model info:**
- Public model issues → File with [Parsera](https://github.com/parsera-labs/api-llm-specs/issues)

## Support the Project

Consider [sponsoring RubyLLM](https://github.com/sponsors/crmne) to help with ongoing costs. Sponsorship supports general maintenance - for priority features, use paid development above.

---

That's it. Let's make Ruby the best AI development experience possible.

— Carmine
