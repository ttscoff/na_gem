# frozen_string_literal: true

module NA
  # Prompt Hooks
  module Prompt
    class << self
      def prompt_hook(shell)
        case shell
        when :zsh
          <<~EOHOOK
            # zsh prompt hook for na
            chpwd() { na }
          EOHOOK
        when :fish
          <<~EOHOOK
            # Fish Prompt Command
            function __should_na --on-variable PWD
              test -s (basename $PWD)".#{NA.extension}" && na
            end
          EOHOOK
        when :bash
          <<~EOHOOK
            # Bash PROMPT_COMMAND for na
            last_command_was_cd() {
              [[ $(history 1|sed -e "s/^[ ]*[0-9]*[ ]*//") =~ ^((cd|z|j|jump|g|f|pushd|popd|exit)([ ]|$)) ]] && na
            }
            if [[ -z "$PROMPT_COMMAND" ]]; then
              PROMPT_COMMAND="eval 'last_command_was_cd'"
            else
              echo $PROMPT_COMMAND | grep -v -q "last_command_was_cd" && PROMPT_COMMAND="$PROMPT_COMMAND;"'eval "last_command_was_cd"'
            fi
          EOHOOK
        end
      end

      def prompt_file(shell)
        files = {
          zsh: '~/.zshrc',
          fish: '~/.config/fish/conf.d/na.fish',
          bash: '~/.bash_profile'
        }

        files[shell]
      end

      def show_prompt_hook(shell)
        file = prompt_file(shell)

        $stderr.puts NA::Color.template("{bw}# Add this to {y}#{file}{x}")
        puts prompt_hook(shell)
      end

      def install_prompt_hook(shell)
        file = prompt_file(shell)

        File.open(File.expand_path(file), 'a') { |f| f.puts prompt_hook(shell) }
        $stderr.puts NA::Color.template("{y}Added {bw}#{shell}{xy} prompt hook to {bw}#{file}{x}")
      end
    end
  end
end
