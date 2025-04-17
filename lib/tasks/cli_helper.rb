# frozen_string_literal: true

require 'io/console'

class CliHelper # rubocop:disable Style/Documentation
  def self.get_user_choice(prompt, valid_choices) # rubocop:disable Metrics/MethodLength
    loop do
      print "\n#{prompt} [#{valid_choices.join('/')}]: "
      begin
        choice = $stdin.getch.downcase
        puts choice # Echo the character

        return choice if valid_choices.include?(choice)

        puts "  Invalid choice '#{choice}'. Valid options: #{valid_choices.join(', ')}"
      rescue Interrupt
        puts "\n*** Input interrupted."
        return 'q'
      end
    end
  end
end
