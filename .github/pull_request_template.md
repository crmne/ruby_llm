## What this does

<!-- Clear description of what this PR does and why -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [ ] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [ ] This aligns with RubyLLM's focus on **LLM communication**
- [ ] This isn't application-specific logic that belongs in user code
- [ ] This benefits most users, not just my specific use case

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [ ] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [ ] No API changes

## Related issues

<!-- Link issues: "Fixes #123" or "Related to #123" -->
