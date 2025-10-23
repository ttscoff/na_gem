# frozen_string_literal: true

require 'pathname'

module NA
  # Pagination
  module Pager
    class << self
      # Boolean determines whether output is paginated
      def paginate
        @paginate ||= false
      end

      # Enable/disable pagination
      #
      # @param      should_paginate  [Boolean] true to paginate
      def paginate=(should_paginate)
        @paginate = should_paginate
      end

      # Page output. If @paginate is false, just dump to
      # STDOUT
      #
      # @param      text  [String] text to paginate
      #
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
        rescue SystemCallError => e
          # Clean up on error
          write_io.close rescue nil
          Process.kill('TERM', pid) rescue nil
          Process.waitpid(pid) rescue nil
          false
        end
      end

      private

      def git_pager
        TTY::Which.exist?('git') ? `#{TTY::Which.which('git')} config --get-all core.pager` : nil
      end

      def pagers
        [
          ENV['PAGER'],
          'less -FXr',
          ENV['GIT_PAGER'],
          git_pager,
          'more -r'
        ].remove_bad
      end

      def find_executable(*commands)
        execs = commands.empty? ? pagers : commands
        execs
          .remove_bad.uniq
          .find { |cmd| TTY::Which.exist?(cmd.split.first) }
      end

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
