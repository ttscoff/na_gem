# frozen_string_literal: true

require 'pathname'

module NA
  # Pagination
  module Pager
    class << self
      # Boolean determines whether output is paginated
      #
      # @return [Boolean] true if paginated
      def paginate
        @paginate ||= false
      end

      # Enable/disable pagination
      #
      # @param should_paginate [Boolean] true to paginate
      # @return [void]
      attr_writer :paginate

      # Page output. If @paginate is false, just dump to STDOUT
      #
      # @param text [String] text to paginate
      # @return [Boolean, nil] true if paged, false if not, nil if no pager
      def page(text)
        unless @paginate
          puts text
          return
        end

        # Skip pagination for small outputs (faster than starting a pager)
        if text.length < 2000 && text.lines.count < 50
          puts text
          return
        end

        pager = which_pager
        return false unless pager

        # Optimized pager execution - use spawn instead of fork+exec
        read_io, write_io = IO.pipe

        # Use spawn for better performance than fork+exec
        pid = spawn(pager, in: read_io, out: $stdout, err: $stderr)
        read_io.close

        begin
          # Write data to pager
          write_io.write(text)
          write_io.close

          # Wait for pager to complete
          _, status = Process.waitpid2(pid)
          status.success?
        rescue SystemCallError
          # Clean up on error
          begin
            write_io.close
          rescue StandardError
            nil
          end
          begin
            Process.kill('TERM', pid)
          rescue StandardError
            nil
          end
          begin
            Process.waitpid(pid)
          rescue StandardError
            nil
          end
          false
        end
      end

      private

      # Get the git pager command if available
      #
      # @return [String, nil] git pager command
      def git_pager
        TTY::Which.exist?('git') ? `#{TTY::Which.which('git')} config --get-all core.pager` : nil
      end

      # List of possible pager commands
      #
      # @return [Array<String>] pager commands
      def pagers
        [
          ENV.fetch('PAGER', nil),
          'less -FXr',
          ENV.fetch('GIT_PAGER', nil),
          git_pager,
          'more -r'
        ].remove_bad
      end

      # Find the first available executable pager command
      #
      # @param commands [Array<String>] commands to check
      # @return [String, nil] first available command
      def find_executable(*commands)
        execs = commands.empty? ? pagers : commands
        execs
          .remove_bad.uniq
          .find { |cmd| TTY::Which.exist?(cmd.split.first) }
      end

      # Determine which pager to use
      #
      # @return [String, nil] pager command
      def which_pager
        @which_pager ||= find_executable(*pagers)
      end

      # Clear pager cache (useful for testing)
      def clear_pager_cache
        @which_pager = nil
      end
    end
  end
end
