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

## Required for new features

<!-- Skip this section for bug fixes and documentation -->

- [ ] I opened an issue **before** writing code and received maintainer approval
- [ ] Linked issue: #___

**PRs for new features or enhancements without a prior approved issue will be closed.**

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [ ] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## AI-generated code

- [ ] I used AI tools to help write this code
- [ ] I have reviewed and understand all generated code (required if above is checked)

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [ ] No API changes
