# frozen_string_literal: true

module NA
  # Actions controller
  class Actions < Array
    def initialize(actions = [])
      super
    end

    # Pretty print a list of actions
    #
    # @param depth [Integer] The depth of the action
    # @param config [Hash] The configuration options
    # @option config [Array] :files The files to include in the output
    # @option config [Array] :regexes The regexes to match against
    # @option config [Boolean] :notes Whether to include notes in the output
    # @option config [Boolean] :nest Whether to nest the output
    # @option config [Boolean] :nest_projects Whether to nest projects in the output
    # @option config [Boolean] :no_files Whether to include files in the output
    # @return [String] The output string
    def output(depth, config = {})
      NA::Benchmark.measure('Actions.output') do
        defaults = {
          files: nil,
          regexes: [],
          notes: false,
          nest: false,
          nest_projects: false,
          no_files: false,
          times: false,
          human: false,
          only_timed: false,
          json_times: false
        }
        config = defaults.merge(config)

        return if config[:files].nil?

        # Optionally filter to only actions with a computable duration (@started and @done)
        filtered_actions = if config[:only_timed]
                             self.select do |a|
                               t = a.tags
                               (t['started'] || t['start']) && t['done']
                             end
                           else
                             self
                           end

        if config[:nest]
          template = NA.theme[:templates][:default]
          template = NA.theme[:templates][:no_file] if config[:no_files]

          parent_files = {}
          out = []

          if config[:nest_projects]
            filtered_actions.each do |action|
              parent_files[action.file] ||= []
              parent_files[action.file].push(action)
            end

            parent_files.each do |file, acts|
              projects = NA.project_hierarchy(acts)
              out.push("#{file.sub(%r{^./}, '').shorten_path}:")
              out.concat(NA.output_children(projects, 0))
            end
          else
            template = NA.theme[:templates][:default]
            template = NA.theme[:templates][:no_file] if config[:no_files]

            filtered_actions.each do |action|
              parent_files[action.file] ||= []
              parent_files[action.file].push(action)
            end

            parent_files.each do |file, acts|
              out.push("#{file.sub(%r{^\./}, '')}:")
              acts.each do |a|
                out.push("\t- [#{a.parent.join('/')}] #{a.action}")
                out.push("\t\t#{a.note.join("\n\t\t")}") unless a.note.empty?
              end
            end
          end
          NA::Pager.page out.join("\n")
        else
          # Optimize template selection
          template = if config[:no_files]
                       NA.theme[:templates][:no_file]
                     elsif config[:files]&.count&.positive?
                       config[:files].count == 1 ? NA.theme[:templates][:single_file] : NA.theme[:templates][:multi_file]
                     elsif depth > 1
                       NA.theme[:templates][:multi_file]
                     else
                       NA.theme[:templates][:default]
                     end
          template += '%note' if config[:notes]

          # Show './' for current directory only when listing also includes subdir files
          if template == NA.theme[:templates][:multi_file]
            has_subdir = config[:files]&.any? { |f| File.dirname(f) != '.' } || depth > 1
            NA.show_cwd_indicator = !has_subdir.nil?
          else
            NA.show_cwd_indicator = false
          end

          # Skip debug output if not verbose
          config[:files]&.each { |f| NA.notify(f, debug: true) } if config[:files] && NA.verbose

          # Optimize output generation - compile all output first, then apply regexes
          output = String.new
          total_seconds = 0
          totals_by_tag = Hash.new(0)
          timed_items = []
          NA::Benchmark.measure('Generate action strings') do
            filtered_actions.each_with_index do |action, idx|
              # Generate raw output without regex processing
              line = action.pretty(template: { templates: { output: template } }, regexes: [], notes: config[:notes])

              if config[:times]
                # compute duration from @started/@done
                tags = action.tags
                begun = tags['started'] || tags['start']
                finished = tags['done']
                if begun && finished
                  begin
                    start_t = Time.parse(begun)
                    end_t = Time.parse(finished)
                    secs = [end_t - start_t, 0].max.to_i
                    total_seconds += secs
                    dur_color = NA.theme[:duration] || '{y}'
                    line << NA::Color.template(" #{dur_color}[#{format_duration(secs, human: config[:human])}]{x}")

                    # collect for JSON output
                    timed_items << {
                      action: NA::Color.uncolor(action.action),
                      started: start_t.iso8601,
                      ended: end_t.iso8601,
                      duration: secs
                    }

                    # accumulate per-tag durations (exclude time-control tags)
                    tags.each_key do |k|
                      next if k =~ /^(start|started|done)$/i

                      totals_by_tag[k.sub(/^@/, '')] += secs
                    end
                  rescue StandardError
                    # ignore parse errors
                  end
                end
              end

              unless config[:only_times]
                output << line
                output << "\n" unless idx == filtered_actions.size - 1
              end
            end
          end

          # If JSON output requested, emit JSON and return immediately
          if config[:json_times]
            require 'json'
            json = {
              timed: timed_items,
              tags: totals_by_tag.map { |k, v| { tag: k, duration: v } }.sort_by { |h| -h[:duration] },
              total: {
                seconds: total_seconds,
                timestamp: format_duration(total_seconds, human: false),
                human: format_duration(total_seconds, human: true)
              }
            }
            puts JSON.pretty_generate(json)
            return
          end

          # Apply regex highlighting to the entire output at once
          if config[:regexes].any?
            NA::Benchmark.measure('Apply regex highlighting') do
              output = output.highlight_search(config[:regexes])
            end
          end

          if config[:times] && total_seconds.positive?
            # Build Markdown table of per-tag totals
            if totals_by_tag.empty?
              # No tag totals, just show total line
              dur_color = NA.theme[:duration] || '{y}'
              output << "\n"
              output << NA::Color.template("{x}#{dur_color}Total time: [#{format_duration(total_seconds, human: config[:human])}]{x}")
            else
              rows = totals_by_tag.sort_by { |_, v| -v }.map do |tag, secs|
                disp = format_duration(secs, human: config[:human])
                ["@#{tag}", disp]
              end
              # Pre-compute total display for width calculation
              total_disp = format_duration(total_seconds, human: config[:human])
              # Determine column widths, including footer labels/values
              tag_header = 'Tag'
              dur_header = config[:human] ? 'Duration (human)' : 'Duration'
              tag_width = ([tag_header.length, 'Total'.length] + rows.map { |r| r[0].length }).max
              dur_width = ([dur_header.length, total_disp.length] + rows.map { |r| r[1].length }).max

              # Header
              output << "\n"
              output << "| #{tag_header.ljust(tag_width)} | #{dur_header.ljust(dur_width)} |\n"
              # Separator for header
              output << "| #{'-' * tag_width} | #{'-' * dur_width} |\n"
              # Body rows
              rows.each do |tag, disp|
                output << "| #{tag.ljust(tag_width)} | #{disp.ljust(dur_width)} |\n"
              end
              # Footer separator (kramdown footer separator with '=') and footer row
              output << "| #{'=' * tag_width} | #{'=' * dur_width} |\n"
              output << "| #{'Total'.ljust(tag_width)} | #{total_disp.ljust(dur_width)} |\n"
            end
          end

          NA::Benchmark.measure('Pager.page call') do
            NA::Pager.page(output)
          end
        end
      end
    end

    private

    def format_duration(secs, human: false)
      return '' if secs.nil?

      secs = secs.to_i
      days = secs / 86_400
      rem = secs % 86_400
      hours = rem / 3600
      rem %= 3600
      minutes = rem / 60
      seconds = rem % 60
      if human
        parts = []
        parts << "#{days} days" if days.positive?
        parts << "#{hours} hours" if hours.positive?
        parts << "#{minutes} minutes" if minutes.positive?
        parts << "#{seconds} seconds" if seconds.positive? || parts.empty?
        parts.join(', ')
      else
        format('%<d>02d:%<h>02d:%<m>02d:%<s>02d', d: days, h: hours, m: minutes, s: seconds)
      end
    end
  end
end
