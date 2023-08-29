# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Show or install prompt hooks for the current shell'
  long_desc 'Installing the prompt hook allows you to automatically
  list next actions when you cd into a directory'
  command %i[prompt] do |c|
    c.desc 'Output the prompt hook for the current shell to STDOUT. Pass an argument to
            specify a shell (zsh, bash, fish)'
    c.arg_name 'SHELL', optional: true
    c.command %i[show] do |s|
      s.action do |_global_options, _options, args|
        shell = if args.count.positive?
                  args[0]
                else
                  File.basename(ENV['SHELL'])
                end

        case shell
        when /^f/i
          NA::Prompt.show_prompt_hook(:fish)
        when /^z/i
          NA::Prompt.show_prompt_hook(:zsh)
        when /^b/i
          NA::Prompt.show_prompt_hook(:bash)
        end
      end
    end

    c.desc 'Install the hook for the current shell to the appropriate startup file.'
    c.arg_name 'SHELL', optional: true
    c.command %i[install] do |s|
      s.action do |_global_options, _options, args|
        shell = if args.count.positive?
                  args[0]
                else
                  File.basename(ENV['SHELL'])
                end

        case shell
        when /^f/i
          NA::Prompt.install_prompt_hook(:fish)
        when /^z/i
          NA::Prompt.install_prompt_hook(:zsh)
        when /^b/i
          NA::Prompt.install_prompt_hook(:bash)
        end
      end
    end
  end
end
