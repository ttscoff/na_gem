# frozen_string_literal: true

module GLI
  module Commands
    # Help Command Monkeypatch for paginated output
    class Help < Command
      def show_help(global_options, options, arguments, out, error)
        NA::Pager.paginate = true

        command_finder = HelpModules::CommandFinder.new(@app, arguments, error)
        if options[:c]
          help_output = HelpModules::HelpCompletionFormat.new(@app, command_finder, arguments).format
          out.puts help_output unless help_output.nil?
        elsif arguments.empty? || options[:c]
          NA::Pager.page HelpModules::GlobalHelpFormat.new(@app, @sorter, @text_wrapping_class).format
        else
          name = arguments.shift
          command = command_finder.find_command(name)
          unless command.nil?
            NA::Pager.page HelpModules::CommandHelpFormat.new(
              command,
              @app,
              @sorter,
              @synopsis_formatter_class,
              @text_wrapping_class
            ).format
          end
        end
      end
    end
  end
end
