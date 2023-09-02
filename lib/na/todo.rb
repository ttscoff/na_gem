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
            optional_tag.push(t) unless t[:negate]
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

      files = if !settings[:file_path].nil?
                [settings[:file_path]]
              elsif settings[:query].nil?
                NA.find_files(depth: settings[:depth])
              else
                NA.match_working_dir(settings[:query])
              end

      files.each do |file|
        NA.save_working_dir(File.expand_path(file))
        content = file.read_file
        indent_level = 0
        parent = []
        in_action = false
        content.split(/\n/).each.with_index do |line, idx|
          if line.project?
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
            in_action = false
          elsif line.action?
            in_action = false

            action = line.action
            new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action, idx)

            projects[-1].last_line = idx if projects.count.positive?

            next if line.done? && !settings[:done]

            next if settings[:require_na] && !line.na?

            has_search = !optional.empty? || !required.empty? || !negated.empty?

            next if has_search && !new_action.search_match?(any: optional,
                                                            all: required,
                                                            none: negated)

            if settings[:project]
              rx = settings[:project].split(%r{[/:]}).join('.*?/')
              next unless parent.join('/') =~ Regexp.new("#{rx}.*?", Regexp::IGNORECASE)
            end

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

      [files, actions, projects]
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
