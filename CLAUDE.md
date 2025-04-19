# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands
- Build: `bundle exec rake build`
- Install dependencies: `bundle install`
- Run all tests: `bundle exec rspec`
- Run specific test: `bundle exec rspec spec/ruby_llm/chat_spec.rb`
- Run specific test by description: `bundle exec rspec -e "description"`
- Re-record VCR cassettes: `bundle exec rake vcr:record[all]` or `bundle exec rake vcr:record[openai,anthropic]`
- Check style: `bundle exec rubocop`
- Auto-fix style: `bundle exec rubocop -A`

## Code Style Guidelines
- Follow [Standard Ruby](https://github.com/testdouble/standard) style
- Use frozen_string_literal comment at the top of each file
- Follow model naming conventions from CONTRIBUTING.md when adding providers
- Use RSpec for tests with descriptive test names that form clean VCR cassettes
- Handle errors with specific error classes from RubyLLM::Error
- Use method keyword arguments with Ruby 3+ syntax
- Document public APIs with YARD comments
- Maintain backward compatibility for minor version changes