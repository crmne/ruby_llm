---
layout: default
title: Structured Output
parent: Agent SDK
nav_order: 8
permalink: /agent-sdk/structured-output
---

# Structured Output

Extract JSON data from agent responses with schema validation.

## Basic Usage

Define a JSON schema and the agent will return structured data:

```ruby
schema = {
  type: "object",
  properties: {
    summary: { type: "string", description: "Brief summary" },
    issues: {
      type: "array",
      items: {
        type: "object",
        properties: {
          severity: { type: "string", enum: ["low", "medium", "high", "critical"] },
          file: { type: "string" },
          line: { type: "integer" },
          description: { type: "string" }
        },
        required: ["severity", "file", "description"]
      }
    },
    overall_score: { type: "number", minimum: 0, maximum: 100 }
  },
  required: ["summary", "issues", "overall_score"]
}

result = RubyLLM::AgentSDK.query(
  "Review this codebase for security issues",
  allowed_tools: %w[Read Glob Grep],
  output_format: { type: 'json_schema', schema: schema }
).find(&:result?)

data = result.structured_output
puts data[:summary]
puts "Score: #{data[:overall_score]}"
data[:issues].each do |issue|
  puts "#{issue[:severity].upcase}: #{issue[:file]} - #{issue[:description]}"
end
```

## With Fluent API

```ruby
result = RubyLLM::AgentSDK.query(
  "Analyze the API endpoints"
).with_output_format({
  type: "object",
  properties: {
    endpoints: {
      type: "array",
      items: {
        type: "object",
        properties: {
          method: { type: "string" },
          path: { type: "string" },
          description: { type: "string" }
        }
      }
    }
  }
}).find(&:result?)

puts result.structured_output[:endpoints]
```

## Common Schemas

### Code Analysis

```ruby
CODE_ANALYSIS_SCHEMA = {
  type: "object",
  properties: {
    files_analyzed: { type: "integer" },
    complexity_score: { type: "number" },
    issues: {
      type: "array",
      items: {
        type: "object",
        properties: {
          type: { type: "string", enum: ["bug", "smell", "security", "performance"] },
          severity: { type: "string", enum: ["info", "warning", "error"] },
          location: {
            type: "object",
            properties: {
              file: { type: "string" },
              line: { type: "integer" }
            }
          },
          message: { type: "string" },
          suggestion: { type: "string" }
        },
        required: ["type", "severity", "message"]
      }
    },
    recommendations: {
      type: "array",
      items: { type: "string" }
    }
  },
  required: ["files_analyzed", "issues"]
}
```

### Test Coverage Report

```ruby
TEST_COVERAGE_SCHEMA = {
  type: "object",
  properties: {
    total_files: { type: "integer" },
    tested_files: { type: "integer" },
    coverage_percentage: { type: "number" },
    untested_files: {
      type: "array",
      items: {
        type: "object",
        properties: {
          file: { type: "string" },
          priority: { type: "string", enum: ["low", "medium", "high"] },
          reason: { type: "string" }
        }
      }
    },
    suggested_tests: {
      type: "array",
      items: {
        type: "object",
        properties: {
          file: { type: "string" },
          test_cases: {
            type: "array",
            items: { type: "string" }
          }
        }
      }
    }
  }
}
```

### Dependency Audit

```ruby
DEPENDENCY_AUDIT_SCHEMA = {
  type: "object",
  properties: {
    total_dependencies: { type: "integer" },
    outdated: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          current_version: { type: "string" },
          latest_version: { type: "string" },
          update_urgency: { type: "string", enum: ["low", "medium", "high", "critical"] }
        }
      }
    },
    vulnerabilities: {
      type: "array",
      items: {
        type: "object",
        properties: {
          dependency: { type: "string" },
          cve: { type: "string" },
          severity: { type: "string" },
          description: { type: "string" },
          fix_version: { type: "string" }
        }
      }
    },
    unused: {
      type: "array",
      items: { type: "string" }
    }
  }
}
```

### API Documentation

```ruby
API_DOCS_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    version: { type: "string" },
    base_url: { type: "string" },
    endpoints: {
      type: "array",
      items: {
        type: "object",
        properties: {
          method: { type: "string", enum: ["GET", "POST", "PUT", "PATCH", "DELETE"] },
          path: { type: "string" },
          summary: { type: "string" },
          description: { type: "string" },
          parameters: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                in: { type: "string", enum: ["path", "query", "header", "body"] },
                type: { type: "string" },
                required: { type: "boolean" },
                description: { type: "string" }
              }
            }
          },
          responses: {
            type: "object",
            additionalProperties: {
              type: "object",
              properties: {
                description: { type: "string" },
                schema: { type: "object" }
              }
            }
          }
        },
        required: ["method", "path", "summary"]
      }
    }
  },
  required: ["title", "endpoints"]
}
```

## Rails Integration

Use structured output in Rails services:

```ruby
# app/services/code_analyzer.rb
class CodeAnalyzer
  SCHEMA = {
    type: "object",
    properties: {
      quality_score: { type: "number" },
      issues: { type: "array", items: { type: "object" } },
      summary: { type: "string" }
    },
    required: ["quality_score", "summary"]
  }.freeze

  def initialize(repository_path)
    @repository_path = repository_path
  end

  def analyze
    result = RubyLLM::AgentSDK.query(
      "Analyze code quality and identify issues",
      cwd: @repository_path,
      allowed_tools: %w[Read Glob Grep],
      permission_mode: :bypass_permissions,
      output_format: { type: 'json_schema', schema: SCHEMA }
    ).find(&:result?)

    CodeAnalysisResult.new(result.structured_output)
  end
end

# Usage
analysis = CodeAnalyzer.new(Rails.root).analyze
puts "Quality Score: #{analysis.quality_score}"
```

## Error Handling

Handle schema validation failures:

```ruby
result = RubyLLM::AgentSDK.query(
  "Extract data",
  output_format: { type: 'json_schema', schema: schema }
).find(&:result?)

if result.error_max_structured_output_retries?
  # Agent couldn't produce valid output after multiple attempts
  puts "Failed to extract structured data"
  puts result.errors
elsif result.structured_output
  # Success - use the data
  process_data(result.structured_output)
else
  # No structured output but no error either
  puts "Raw result: #{result.content}"
end
```

## Combining with Hooks

Validate structured output with hooks:

```ruby
hooks = {
  post_tool_use: [
    {
      handler: ->(ctx) {
        if ctx.tool_name == "structured_output"
          data = ctx.tool_response
          # Custom validation
          if data[:quality_score] && data[:quality_score] < 50
            Rails.logger.warn "Low quality score detected"
          end
        end
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ]
}

RubyLLM::AgentSDK.query(
  "Analyze code",
  output_format: { type: 'json_schema', schema: schema },
  hooks: hooks
)
```

## Best Practices

1. **Keep schemas simple** - Complex nested schemas increase failure rates
2. **Use descriptions** - Help the agent understand what you want
3. **Make fields optional** when possible - More flexibility
4. **Set reasonable max_turns** - Retries can be expensive
5. **Validate on your end** - Don't trust the output blindly

```ruby
# Good: Simple, clear schema
schema = {
  type: "object",
  properties: {
    files: {
      type: "array",
      description: "List of files that need attention",
      items: { type: "string" }
    },
    urgent: {
      type: "boolean",
      description: "Whether immediate action is required"
    }
  },
  required: ["files", "urgent"]
}

# Validate after receiving
result = RubyLLM::AgentSDK.query("Check for issues", output_format: { type: 'json_schema', schema: schema }).find(&:result?)

if result.structured_output
  data = result.structured_output

  # Additional validation
  raise "Invalid data" unless data[:files].is_a?(Array)
  raise "Invalid data" unless [true, false].include?(data[:urgent])

  process(data)
end
```

## Next Steps

- [API Reference]({% link agent_sdk/api-reference.md %}) - Full options documentation
- [Rails Integration]({% link agent_sdk/rails.md %}) - Use in Rails apps
- [Examples]({% link agent_sdk/examples.md %}) - More patterns
