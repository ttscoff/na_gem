# frozen_string_literal: true

require 'English'

module NA
  # Provides editor selection and argument helpers for launching text editors.
  module Editor
    class << self
      # Returns the default editor command, checking environment variables and available editors.
      # @param prefer_git_editor [Boolean] Prefer GIT_EDITOR over EDITOR
      # @return [String, nil] Editor command or nil if not found
      def default_editor(prefer_git_editor: true)
        editor ||= if prefer_git_editor
                     ENV['NA_EDITOR'] || ENV['GIT_EDITOR'] || ENV.fetch('EDITOR', nil)
                   else
                     ENV['NA_EDITOR'] || ENV['EDITOR'] || ENV.fetch('GIT_EDITOR', nil)
                   end

        return editor if editor&.good? && TTY::Which.exist?(editor)

        NA.notify('No EDITOR environment variable, testing available editors', debug: true)
        editors = %w[vim vi code subl mate mvim nano emacs]
        editors.each do |ed|
          try = TTY::Which.which(ed)
          if try
            NA.notify("Using editor #{try}", debug: true)
            return try
          end
        end

        NA.notify("#{NA.theme[:error]}No editor found", exit_code: 5)

        nil
      end

      # Returns the default editor command with its arguments.
      # @return [String] Editor command with arguments
      def editor_with_args
        args_for_editor(default_editor)
      end

      # Returns the editor command with appropriate arguments for file opening.
      # @param editor [String] Editor command
      # @return [String] Editor command with arguments
      def args_for_editor(editor)
        return editor if editor =~ /-\S/

        args = case editor
               when /^(subl|code|mate)$/
                 ['-w']
               when /^(vim|mvim)$/
                 ['-f']
               else
                 []
               end
        "#{editor} #{args.join(' ')}"
      end

      # Create a process for an editor and wait for the file handle to return
      #
      # @param input [String] Text input for editor
      # @return [String] Edited text
      def fork_editor(input = '', message: :default)
        # raise NonInteractive, 'Non-interactive terminal' unless $stdout.isatty || ENV['DOING_EDITOR_TEST']

        NA.notify("#{NA.theme[:error]}No EDITOR variable defined in environment", exit_code: 5) if default_editor.nil?

        tmpfile = Tempfile.new(['na_temp', '.na'])

        File.open(tmpfile.path, 'w+') do |f|
          f.puts input
          unless message.nil?
            f.puts message == :default ? '# First line is the action, lines after are added as a note' : message
          end
        end

        pid = Process.fork { system("#{editor_with_args} #{tmpfile.path}") }

        trap('INT') do
          begin
            Process.kill(9, pid)
          rescue StandardError
            Errno::ESRCH
          end
          tmpfile.unlink
          tmpfile.close!
          exit 0
        end

        Process.wait(pid)

        begin
          if $CHILD_STATUS.exitstatus.zero?
            input = File.read(tmpfile.path)
          else
            exit_now! 'Cancelled'
          end
        ensure
          tmpfile.close
          tmpfile.unlink
        end

        # Don't strip comments if this looks like multi-action format (has # ------ markers)
        if input.include?('# ------ ')
          input
        else
          input.split("\n").delete_if(&:ignore?).join("\n")
        end
      end

      # Takes a multi-line string and formats it as an entry
      #
      # @param input [String] The string to parse
      # @return [Array] [[String]title, [Note]note]
      def format_input(input)
        NA.notify("#{NA.theme[:error]}No content in entry", exit_code: 1) if input.nil? || input.strip.empty?

        input_lines = input.split(/[\n\r]+/).delete_if(&:ignore?)
        title = input_lines[0]&.strip
        NA.notify("#{NA.theme[:error]}No content in first line", exit_code: 1) if title.nil? || title.strip.empty?

        title = title.expand_date_tags

        note = if input_lines.length > 1
                 input_lines[1..]
               else
                 []
               end

        unless note.empty?
          note.map!(&:strip)
          note.delete_if { |l| l =~ /^\s*$/ || l =~ /^#/ }
        end

        [title, note]
      end

      # Format multiple actions for multi-edit
      # @param actions [Array<Action>] Actions to edit
      # @return [String] Formatted editor content
      def format_multi_action_input(actions)
        header = <<~EOF
          # Instructions:
          # - Edit the action text (the lines WITHOUT # comment markers)
          # - DO NOT remove or edit the lines starting with "# ------"
          # - Add notes on new lines after the action
          # - Blank lines are ignored
          #

        EOF

        # Use + to create a mutable string
        content = +header

        actions.each do |action|
          # Use file_path to get the path and file_line to get the line number
          content << "# ------ #{action.file_path}:#{action.file_line}\n"
          content << "#{action.action}\n"
          content << "#{action.note.join("\n")}\n" if action.note.any?
          content << "\n" # Blank line separator
        end

        content
      end

      # Parse multi-action editor output
      # @param content [String] Editor output
      # @return [Hash] Hash mapping file:line to [action, note]
      def parse_multi_action_output(content)
        results = {}
        current_file = nil
        current_action = nil
        current_note = []

        content.lines.each do |line|
          stripped = line.strip

          # Check for file marker: # ------ path:line
          match = stripped.match(/^# ------ (.+?):(\d+)$/)
          if match
            # Save previous action if exists
            results[current_file] = [current_action, current_note] if current_file && current_action

            # Start new action
            current_file = "#{match[1]}:#{match[2]}"
            current_action = nil
            current_note = []
            next
          end

          # Skip other comment lines
          next if stripped.start_with?('#')

          # Skip blank lines
          next if stripped.empty?

          # Store as action or note based on what we've seen so far
          if current_action.nil?
            current_action = stripped
          else
            # Subsequent lines are notes
            current_note << stripped
          end
        end

        # Save last action
        results[current_file] = [current_action, current_note] if current_file && current_action

        results
      end
    end
  end
end
