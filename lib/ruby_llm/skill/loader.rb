# frozen_string_literal: true

module RubyLLM
  class Skill
    # The +load_skill+ tool a chat with skills gives the model. It returns a
    # skill's instructions, or one of the files the instructions mention,
    # and never leaves the skill's folder. Every request also lists the
    # skills, through #listing, so the model knows what it can load.
    class Loader < Tool # :nodoc:
      MAX_FILE_SIZE = 256 * 1024
      MOUNT = 'skills'

      read_only

      def self.tool_name
        'load_skill'
      end

      def self.mount_path(skill)
        "#{MOUNT}/#{skill.name}"
      end

      def initialize(skills:, code_execution:)
        super()
        @skills = skills
        @code_execution = code_execution
      end

      def description
        "Loads a skill's instructions, or a file inside a skill's folder that its instructions mention. " \
          'Call it with only skill to get the instructions before following a skill, ' \
          'and with file, a path relative to the skill folder, to read one of its files.'
      end

      def parameters_schema
        {
          'type' => 'object',
          'properties' => {
            'skill' => { 'type' => 'string', 'description' => 'The name of the skill' },
            'file' => { 'type' => 'string',
                        'description' => 'A file path relative to the skill folder. Leave it out for the instructions' }
          },
          'required' => %w[skill],
          'additionalProperties' => false
        }
      end

      def listing
        [
          'You have skills: folders of instructions, scripts, and files for specific tasks. ' \
          'When a task matches a skill, call load_skill with its name and follow the instructions it ' \
          'returns. Load the files the instructions mention with load_skill as well, one at a time.',
          scripts_note,
          "<skills>\n#{@skills.call.map { |skill| "- #{skill.name}: #{skill.description}" }.join("\n")}\n</skills>"
        ].join("\n\n")
      end

      def execute(skill:, file: nil)
        found = @skills.call.find { |candidate| candidate.name == skill.to_s }
        return { error: "No skill named #{skill}. Skills: #{@skills.call.map(&:name).join(', ')}" } unless found

        file.nil? || file.to_s.strip.empty? || file.to_s == FILE ? instructions(found) : read(found, file.to_s)
      end

      private

      def instructions(skill)
        folder = if @code_execution.call
                   mount = self.class.mount_path(skill)
                   "Its folder is at #{mount}/ in run_code's working directory, read-only, so a file these " \
                     "instructions call scripts/example.py is #{mount}/scripts/example.py there. Run its scripts " \
                     'with run_code from the working directory, and write output files to the working directory.'
                 else
                   'Paths in these instructions are relative to the skill folder. This conversation cannot run ' \
                     "code, so the skill's scripts cannot run: follow the rest of the instructions, and say so " \
                     'when a step needs a script.'
                 end
        "# Skill: #{skill.name}\n\n#{folder}\n\n#{skill.instructions.strip}"
      end

      def read(skill, file)
        file = file.delete_prefix("#{self.class.mount_path(skill)}/")
        path = skill.resolve_file(file)
        return { error: "#{file} is a folder holding: #{folder_entries(path)}" } if File.directory?(path)
        return { error: "#{file} is larger than #{MAX_FILE_SIZE} bytes. #{use_from_code(skill, file)}" } if
          File.size(path) > MAX_FILE_SIZE

        content = File.binread(path).force_encoding(Encoding::UTF_8)
        return { error: "#{file} is not a text file. #{use_from_code(skill, file)}" } unless text?(content)

        content
      rescue ArgumentError => e
        { error: e.message }
      rescue SystemCallError
        { error: "The #{skill.name} skill has no file #{file}" }
      end

      def folder_entries(path)
        Dir.children(path).sort.map { |entry| File.directory?(File.join(path, entry)) ? "#{entry}/" : entry }.join(', ')
      end

      def text?(content)
        content.valid_encoding? && !content.include?("\0")
      end

      def use_from_code(skill, file)
        return 'This conversation cannot run code to use it.' unless @code_execution.call

        "Use it from run_code at #{self.class.mount_path(skill)}/#{file}."
      end

      def scripts_note
        if @code_execution.call
          'Each skill folder is mounted read-only in every run_code working directory at skills/<name>/, ' \
            'so run_code can run its scripts, such as python skills/<name>/scripts/example.py.'
        else
          'This conversation cannot run code, so skill scripts cannot run. Follow the rest of their instructions.'
        end
      end
    end
  end
end
