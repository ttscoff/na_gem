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
          no_files: false
        }
        config = defaults.merge(config)

        return if config[:files].nil?

        if config[:nest]
          template = NA.theme[:templates][:default]
          template = NA.theme[:templates][:no_file] if config[:no_files]

          parent_files = {}
          out = []

          if config[:nest_projects]
            each do |action|
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

            each do |action|
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
          NA::Benchmark.measure('Generate action strings') do
            each_with_index do |action, idx|
              # Generate raw output without regex processing
              output << action.pretty(template: { templates: { output: template } }, regexes: [], notes: config[:notes])
              output << "\n" unless idx == size - 1
            end
          end

          # Apply regex highlighting to the entire output at once
          if config[:regexes].any?
            NA::Benchmark.measure('Apply regex highlighting') do
              output = output.highlight_search(config[:regexes])
            end
          end

          NA::Benchmark.measure('Pager.page call') do
            NA::Pager.page(output)
          end
        end
      end
    end
  end
end
