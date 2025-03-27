# RubyLLM Development Guidelines

## Commands
- Run all tests: `bundle exec rspec`
- Run single test: `bundle exec rspec spec/path/to/file_spec.rb`
- Run specific test: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- Code style check: `bundle exec rubocop`
- Auto-fix style issues: `bundle exec rubocop -A`
- Record VCR cassettes: `bundle exec rake vcr:record[provider]` (where provider is openai, anthropic, gemini, etc.)

## Style Guidelines
- Follow Standard Ruby style (https://github.com/testdouble/standard)
- Use frozen_string_literal comment at top of files
- Add YARD documentation comments for public methods
- Use proper error handling with specific error classes
- Follow consistent model naming conventions across providers
- Keep normalized model IDs (separate model from provider)
- Use consistent parameter naming across providers
- Always run rubycop to lint

## Testing Practices
- Tests automatically create VCR cassettes based on their descriptions
- Use specific, descriptive test descriptions
- Check VCR cassettes for sensitive information
- Write tests for all new features and bug fixes