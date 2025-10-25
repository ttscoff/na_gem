# frozen_string_literal: true

module NA
  # Prompt Hooks
  module Prompt
    class << self
      # Generate the shell prompt hook script for na
      #
      # @param shell [Symbol] Shell type (:zsh, :fish, :bash)
      # @return [String] Shell script for prompt hook
      def prompt_hook(shell)
        case shell
        when :zsh
          cmd = if NA.global_file
                  case NA.cwd_is
                  when :project
                    'na next --proj $(basename "$PWD")'
                  when :tag
                    'na tagged $(basename "$PWD")'
                  else
                    NA.notify(
                      "#{NA.theme[:error]}When using a global file, a prompt hook requires `--cwd_as [tag|project]`", exit_code: 1
                    )
                  end
                else
                  'na next'
                end
          <<~EOHOOK
            # zsh prompt hook for na
            chpwd() { #{cmd} }
          EOHOOK
        when :fish
          cmd = if NA.global_file
                  case NA.cwd_is
                  when :project
                    'na next --proj (basename "$PWD")'
                  when :tag
                    'na tagged (basename "$PWD")'
                  else
                    NA.notify(
                      "#{NA.theme[:error]}When using a global file, a prompt hook requires `--cwd_as [tag|project]`", exit_code: 1
                    )
                  end
                else
                  'na next'
                end
          <<~EOHOOK
            # Fish Prompt Command
            function __should_na --on-variable PWD
              test -s (basename $PWD)".#{NA.extension}" && #{cmd}
            end
          EOHOOK
        when :bash
          cmd = if NA.global_file
                  case NA.cwd_is
                  when :project
                    'na next --proj $(basename "$PWD")'
                  when :tag
                    'na tagged $(basename "$PWD")'
                  else
                    NA.notify(
                      "#{NA.theme[:error]}When using a global file, a prompt hook requires `--cwd_as [tag|project]`", exit_code: 1
                    )
                  end
                else
                  'na next'
                end

          <<~EOHOOK
            # Bash PROMPT_COMMAND for na
            last_command_was_cd() {
              [[ $(history 1|sed -e "s/^[ ]*[0-9]*[ ]*//") =~ ^((cd|z|j|jump|g|f|pushd|popd|exit)([ ]|$)) ]] && #{cmd}
            }
            if [[ -z "$PROMPT_COMMAND" ]]; then
              PROMPT_COMMAND="eval 'last_command_was_cd'"
            else
              echo $PROMPT_COMMAND | grep -v -q "last_command_was_cd" && PROMPT_COMMAND="$PROMPT_COMMAND;"'eval "last_command_was_cd"'
            fi
          EOHOOK
        end
      end

      # Get the configuration file path for the given shell
      #
      # @param shell [Symbol] Shell type
      # @return [String] Path to shell config file
      def prompt_file(shell)
        files = {
          zsh: '~/.zshrc',
          fish: '~/.config/fish/conf.d/na.fish',
          bash: '~/.bash_profile'
        }

        files[shell]
      end

      # Display the prompt hook script and notify user of config file
      #
      # @param shell [Symbol] Shell type
      # @return [void]
      def show_prompt_hook(shell)
        file = prompt_file(shell)

        NA.notify("#{NA.theme[:warning]}# Add this to #{NA.theme[:filename]}#{file}")
        puts prompt_hook(shell)
      end

      # Install the prompt hook script into the shell config file
      #
      # @param shell [Symbol] Shell type
      # @return [void]
      def install_prompt_hook(shell)
        file = prompt_file(shell)

        File.open(File.expand_path(file), 'a') { |f| f.puts prompt_hook(shell) }
        NA.notify("#{NA.theme[:success]}Added #{NA.theme[:filename]}#{shell}{x}#{NA.theme[:success]} prompt hook to #{NA.theme[:filename]}#{file}#{NA.theme[:success]}.")
        NA.notify("#{NA.theme[:warning]}You may need to close the current terminal and open a new one to enable the script.")
      end
    end
  end
end
