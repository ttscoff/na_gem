# frozen_string_literal: true

module NA
  class Todo
    attr_accessor :actions, :projects, :files

    def initialize(options = {})
      @files, @actions, @projects = parse(options)
    end

    ##
    ## Read a todo file and create a list of actions
    ##
    ## @param      options  The options
    ##
    ## @option      depth       [Number] The directory depth to
    ##                         search for files
    ## @option      done        [Boolean] include @done actions
    ## @option      query       [Hash] The todo file query
    ## @option      tag         [Array] Tags to search for
    ## @option      search      [String] A search string
    ## @option      negate      [Boolean] Invert results
    ## @option      regex       [Boolean] Interpret as regular
    ##                         expression
    ## @option      project     [String] The project
    ## @option      require_na  [Boolean] Require @na tag
    ## @option      file_path   [String] file path to parse
    ##
    def parse(options)
      NA::Benchmark.measure('Todo.parse') do
        defaults = {
          depth: 1,
          done: false,
          file_path: nil,
          negate: false,
          project: nil,
          query: nil,
          regex: false,
          require_na: true,
          search: nil,
          search_note: true,
          tag: nil
        }

        settings = defaults.merge(options)

      actions = NA::Actions.new
      required = []
      optional = []
      negated = []
      required_tag = []
      optional_tag = []
      negated_tag = []
      projects = []

      NA.notify("Tags: #{settings[:tag]}", debug:true)
      NA.notify("Search: #{settings[:search]}", debug:true)

      settings[:tag]&.each do |t|
        unless t[:tag].nil?
          if settings[:negate]
            optional_tag.push(t) if t[:negate]
            required_tag.push(t) if t[:required] && t[:negate]
            negated_tag.push(t) unless t[:negate]
          else
            optional_tag.push(t) unless t[:negate] || t[:required]
            required_tag.push(t) if t[:required] && !t[:negate]
            negated_tag.push(t) if t[:negate]
          end
        end
      end

      unless settings[:search].nil? || settings[:search].empty?
        if settings[:regex] || settings[:search].is_a?(String)
          if settings[:negate]
            negated.push(settings[:search])
          else
            optional.push(settings[:search])
            required.push(settings[:search])
          end
        else
          settings[:search].each do |t|
            opt, req, neg = parse_search(t, settings[:negate])
            optional.concat(opt)
            required.concat(req)
            negated.concat(neg)
          end
        end
      end

      # Pre-compile regexes for better performance
      optional = optional.map { |rx| rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE) }
      required = required.map { |rx| rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE) }
      negated = negated.map { |rx| rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE) }

      files = if !settings[:file_path].nil?
                [settings[:file_path]]
              elsif settings[:query].nil?
                NA.find_files(depth: settings[:depth])
              else
                NA.match_working_dir(settings[:query])
              end

      NA.notify("Files: #{files.join(', ')}", debug: true)
      # Cache project regex compilation outside the line loop for better performance
      project_regex = if settings[:project]
                        rx = settings[:project].split(%r{[/:]}).join('.*?/')
                        Regexp.new("#{rx}.*?", Regexp::IGNORECASE)
                      end

        files.each do |file|
          NA::Benchmark.measure("Parse file: #{File.basename(file)}") do
            NA.save_working_dir(File.expand_path(file))
            content = file.read_file
            indent_level = 0
            parent = []
            in_yaml = false
            in_action = false
            content.split(/\n/).each.with_index do |line, idx|
          if in_yaml && line !~ /^(---|~~~)\s*$/
            NA.notify("YAML: #{line}", debug: true)
          elsif line =~ /^(---|~~~)\s*$/
            in_yaml = !in_yaml
          elsif line.project? && !in_yaml
            in_action = false
            proj = line.project
            indent = line.indent_level

            if indent.zero? # top level project
              parent = [proj]
            elsif indent <= indent_level # if indent level is same or less, split parent before indent level and append
              parent.slice!(indent, parent.count - indent)
              parent.push(proj)
            else # if indent level is greater, append project to parent
              parent.push(proj)
            end

            projects.push(NA::Project.new(parent.join(':'), indent, idx, idx))

            indent_level = indent
          elsif line.blank?
            in_action = false # Comment out to allow line breaks in of notes, which isn't TaskPaper-compatible
          elsif line.action?
            in_action = false

            # Early exits before creating Action object
            next if line.done? && !settings[:done]

            next if settings[:require_na] && !line.na?

            if project_regex
              next unless parent.join('/') =~ project_regex
            end

            # Only create Action if we passed basic filters
            action = line.action
            new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action, idx)

            projects[-1].last_line = idx if projects.count.positive?

            # Tag matching
            has_tag = !optional_tag.empty? || !required_tag.empty? || !negated_tag.empty?
            next if has_tag && !new_action.tags_match?(any: optional_tag,
                                                       all: required_tag,
                                                       none: negated_tag)

            actions.push(new_action)
            in_action = true
          elsif in_action
            actions[-1].note.push(line.strip) if actions.count.positive?
            projects[-1].last_line = idx if projects.count.positive?
          end
            end
            projects = projects.dup
          end
        end

        NA::Benchmark.measure('Filter actions by search') do
          actions.delete_if do |new_action|
            has_search = !optional.empty? || !required.empty? || !negated.empty?
            has_search && !new_action.search_match?(any: optional,
                                                   all: required,
                                                   none: negated,
                                                   include_note: settings[:search_note])
          end
        end

        [files, actions, projects]
      end
    end

    def parse_search(tag, negate)
      required = []
      optional = []
      negated = []
      new_rx = tag[:token].to_s.wildcard_to_rx

      if negate
        optional.push(new_rx) if tag[:negate]
        required.push(new_rx) if tag[:required] && tag[:negate]
        negated.push(new_rx) unless tag[:negate]
      else
        optional.push(new_rx) unless tag[:negate]
        required.push(new_rx) if tag[:required] && !tag[:negate]
        negated.push(new_rx) if tag[:negate]
      end

      [optional, required, negated]
    end
  end
end
