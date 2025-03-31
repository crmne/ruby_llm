# frozen_string_literal: true

require 'ripper'

class CodeValidator # rubocop:disable Style/Documentation
  # Use Ruby's built-in Ripper to validate Ruby syntax instead of eval
  def self.validate_syntax(code)
    # Ripper.sexp returns nil if there's a syntax error
    result = Ripper.sexp(code)

    if result.nil?
      puts 'Syntax error in generated code'
      false
    else
      # Additional validation could go here
      true
    end
  end

  def self.extract_code_from_response(content)
    match = content.match(/```ruby\s*(.*?)\s*```/m)
    if match
      match[1].strip
    else
      puts 'No Ruby code block found in response'
      nil
    end
  end
end
