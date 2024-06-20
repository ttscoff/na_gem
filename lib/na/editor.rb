module NA
  module Editor
    class << self
      def default_editor(prefer_git_editor: true)
        if prefer_git_editor
          editor ||= ENV['NA_EDITOR'] || ENV['GIT_EDITOR'] || ENV['EDITOR']
        else
          editor ||= ENV['NA_EDITOR'] || ENV['EDITOR'] || ENV['GIT_EDITOR']
        end

        return editor if editor&.good? && TTY::Which.exist?(editor)

        NA.notify("No EDITOR environment variable, testing available editors", debug: true)
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

      def editor_with_args
        args_for_editor(default_editor)
      end

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

      ##
      ## Create a process for an editor and wait for the file handle to return
      ##
      ## @param      input  [String] Text input for editor
      ##
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
          if $?.exitstatus == 0
            input = IO.read(tmpfile.path)
          else
            exit_now! 'Cancelled'
          end
        ensure
          tmpfile.close
          tmpfile.unlink
        end

        input.split(/\n/).delete_if(&:ignore?).join("\n")
      end

      ##
      ## Takes a multi-line string and formats it as an entry
      ##
      ## @param      input  [String] The string to parse
      ##
      ## @return     [Array] [[String]title, [Note]note]
      ##
      def format_input(input)
        NA.notify("#{NA.theme[:error]}No content in entry", exit_code: 1) if input.nil? || input.strip.empty?

        input_lines = input.split(/[\n\r]+/).delete_if(&:ignore?)
        title = input_lines[0]&.strip
        NA.notify("#{NA.theme[:error]}No content in first line", exit_code: 1) if title.nil? || title.strip.empty?

        title = title.expand_date_tags

        note = if input_lines.length > 1
                 input_lines[1..-1]
               else
                 []
               end

        unless note.empty?
          note.map!(&:strip)
          note.delete_if { |l| l =~ /^\s*$/ || l =~ /^#/ }
        end

        [title, note]
      end
    end
  end
end
