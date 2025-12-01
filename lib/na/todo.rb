# frozen_string_literal: true

module NA
  # Represents a parsed todo file, including actions, projects, and file management.
  #
  # @example Parse a todo file
  #   todo = NA::Todo.new(file_path: 'todo.txt')
  class Todo
    attr_accessor :actions, :projects, :files

    # Initialize a Todo object and parse actions/projects/files
    #
    # @param options [Hash] Options for parsing todo files
    # @return [void]
    # @example
    #   todo = NA::Todo.new(file_path: 'todo.txt')
    def initialize(options = {})
      @files, @actions, @projects = parse(options)
    end

    # Read a todo file and create a list of actions
    #
    # @param options [Hash] The options
    # @option options [Number] :depth The directory depth to search for files
    # @option options [Boolean] :done include @done actions
    # @option options [Hash] :query The todo file query
    # @option options [Array] :tag Tags to search for
    # @option options [String] :search A search string
    # @option options [Boolean] :negate Invert results
    # @option options [Boolean] :regex Interpret as regular expression
    # @option options [String] :project The project
    # @option options [Boolean] :require_na Require @na tag
    # @option options [String] :file_path file path to parse
    # @return [Array] files, actions, projects
    # @example
    #   files, actions, projects = todo.parse(file_path: 'todo.txt')
    def parse(options)
      NA::Benchmark.measure('Todo.parse') do
        defaults = {
          depth: 1,
          done: false,
          file_path: nil,
          negate: false,
          hidden: false,
          project: nil,
          query: nil,
          regex: false,
          require_na: true,
          search: nil,
          search_note: true,
          tag: nil
        }

        settings = defaults.merge(options)
        # Coerce settings[:search] to a string or nil if it's an integer
        if settings[:search].is_a?(Integer)
          settings[:search] = settings[:search] <= 0 ? nil : settings[:search].to_s
        end
        # Ensure tag is always an Array
        if settings[:tag].nil?
          settings[:tag] = []
        elsif !settings[:tag].is_a?(Array)
          settings[:tag] = [settings[:tag]]
        end

        actions = NA::Actions.new
        required = []
        optional = []
        negated = []
        required_tag = []
        optional_tag = []
        negated_tag = []
        projects = []

        NA.notify("Tags: #{settings[:tag]}", debug: true)
        NA.notify("Search: #{settings[:search]}", debug: true)

        settings[:tag]&.each do |t|
          # If t is a Hash, use its keys; if String, treat as a tag string
          if t.is_a?(Hash)
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
          elsif t.is_a?(String)
            # Treat string as a simple tag
            optional_tag.push({ tag: t })
          end
        end
        # Track whether strings came from direct path (need escaping) or parse_search (already processed)
        strings_from_direct_path = false
        unless settings[:search].nil? || (settings[:search].respond_to?(:empty?) && settings[:search].empty?)
          if settings[:regex] || settings[:search].is_a?(String) || settings[:search].is_a?(Regexp)
            strings_from_direct_path = true
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
        # When regex is false and string came from direct path, escape special characters
        # When regex is true, use as-is (it's already a regex pattern)
        # Strings from parse_search are already processed by wildcard_to_rx, so use as-is
        compile_regex = lambda do |rx|
          if rx.is_a?(Regexp)
            rx
          elsif settings[:regex]
            Regexp.new(rx, Regexp::IGNORECASE)
          elsif strings_from_direct_path
            Regexp.new(Regexp.escape(rx.to_s), Regexp::IGNORECASE)
          else
            # From parse_search, already processed by wildcard_to_rx
            # Try to compile as-is, but if it fails, escape it (handles edge cases with special chars)
            begin
              Regexp.new(rx, Regexp::IGNORECASE)
            rescue RegexpError
              # If compilation fails, escape the string (fallback for edge cases)
              Regexp.new(Regexp.escape(rx.to_s), Regexp::IGNORECASE)
            end
          end
        end

        optional = optional.map(&compile_regex)
        required = required.map(&compile_regex)
        negated = negated.map(&compile_regex)

        files = if !settings[:file_path].nil?
                  [settings[:file_path]]
                elsif settings[:query].nil?
                  NA.find_files(depth: settings[:depth], include_hidden: settings[:hidden])
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
          next if File.directory?(file)

          NA::Benchmark.measure("Parse file: #{File.basename(file)}") do
            NA.save_working_dir(File.expand_path(file))
            content = file.read_file
            indent_level = 0
            parent = []
            in_yaml = false
            in_action = false
            content.split("\n").each.with_index do |line, idx|
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

                next if project_regex && parent.join('/') !~ project_regex

                # Only create Action if we passed basic filters
                action = line.action
                new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action, idx)

                projects[-1].last_line = idx if projects.any?

                # Tag matching
                has_tag = !optional_tag.empty? || !required_tag.empty? || !negated_tag.empty?
                next if has_tag && !new_action.tags_match?(any: optional_tag,
                                                           all: required_tag,
                                                           none: negated_tag)

                actions.push(new_action)
                in_action = true
              elsif in_action
                actions[-1].note.push(line.strip) if actions.any?
                projects[-1].last_line = idx if projects.any?
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

    # Parse a search tag and categorize as optional, required, or negated
    #
    # @param tag [Hash] Search tag with :token, :negate, :required
    # @param negate [Boolean] Invert results
    # @return [Array<Array>] Arrays of optional, required, and negated regexes
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
