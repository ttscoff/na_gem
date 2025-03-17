# frozen_string_literal: true

module NA
  # Actions controller
  class Actions < Array
    def initialize(actions = [])
      super
      concat(actions)
    end

    ##
    ## Pretty print a list of actions
    ##
    ## @param depth [Integer] The depth of the action
    ## @param config [Hash] The configuration options
    ##
    ## @option config [Array] :files The files to include in the output
    ## @option config [Array] :regexes The regexes to match against
    ## @option config [Boolean] :notes Whether to include notes in the output
    ## @option config [Boolean] :nest Whether to nest the output
    ## @option config [Boolean] :nest_projects Whether to nest projects in the output
    ## @option config [Boolean] :no_files Whether to include files in the output
    ##
    ## @return [String] The output string
    ##
    def output(depth, config = {})
      defaults = {
        files: nil,
        regexes: [],
        notes: false,
        nest: false,
        nest_projects: false,
        no_files: false,
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
            out.push("#{file.sub(%r{^./}, "").shorten_path}:")
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
            out.push("#{file.sub(%r{^\./}, "")}:")
            acts.each do |a|
              out.push("\t- [#{a.parent.join("/")}] #{a.action}")
              out.push("\t\t#{a.note.join("\n\t\t")}") unless a.note.empty?
            end
          end
        end
        NA::Pager.page out.join("\n")
      else
        template = if config[:no_files]
            NA.theme[:templates][:no_file]
          elsif config[:files].count.positive?
            config[:files].count == 1 ? NA.theme[:templates][:single_file] : NA.theme[:templates][:multi_file]
          elsif NA.find_files(depth: depth).count > 1
            depth > 1 ? NA.theme[:templates][:multi_file] : NA.theme[:templates][:single_file]
          else
            NA.theme[:templates][:default]
          end
        template += "%note" if config[:notes]

        config[:files].map { |f| NA.notify(f, debug: true) } if config[:files]

        output = map { |action| action.pretty(template: { templates: { output: template } }, regexes: config[:regexes], notes: config[:notes]) }
        NA::Pager.page(output.join("\n"))
      end
    end
  end
end
