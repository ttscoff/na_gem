# frozen_string_literal: true

module NA
  class Action < Hash
    attr_reader :file, :project, :tags, :line
    attr_accessor :parent, :action, :note

    def initialize(file, project, parent, action, idx, note = [])
      super()

      @file = file
      @project = project
      @parent = parent
      @action = action.gsub('{', '\\{')
      @tags = scan_tags
      @line = idx
      @note = note
    end

    # Update the action string and note with priority, tags, and completion status
    #
    # @param priority [Integer] Priority value to set
    # @param finish [Boolean] Mark as finished
    # @param add_tag [Array<String>] Tags to add
    # @param remove_tag [Array<String>] Tags to remove
    # @param note [Array<String>] Notes to set
    # @return [void]
    def process(priority: 0, finish: false, add_tag: [], remove_tag: [], note: [])
      string = @action.dup

      if priority&.positive?
        string.gsub!(/(?<=\A| )@priority\(\d+\)/, '')
        string.strip!
        string += " @priority(#{priority})"
      end

      remove_tag.each do |tag|
        string.gsub!(/(?<=\A| )@#{tag.gsub(/([()*?])/, '\\\\1')}(\(.*?\))?/, '')
        string.strip!
      end

      add_tag.each do |tag|
        string.gsub!(/(?<=\A| )@#{tag.gsub(/([()*?])/, '\\\\1')}(\(.*?\))?/, '')
        string.strip!
        string += " @#{tag}"
      end

      string = "#{string.strip} @done(#{Time.now.strftime('%Y-%m-%d %H:%M')})" if finish && string !~ /(?<=\A| )@done/

      @action = string.expand_date_tags
      @note = note unless note.empty?
    end

    # String representation of the action
    #
    # @return [String]
    def to_s
      note = if @note.count.positive?
               "\n#{@note.join("\n")}"
             else
               ''
             end
      "(#{@file}:#{@line}) #{@project}:#{@parent.join('>')} | #{@action}#{note}"
    end

    # Pretty string representation of the action with color formatting
    #
    # @return [String]
    def to_s_pretty
      note = if @note.count.positive?
               "\n#{@note.join("\n")}"
             else
               ''
             end
      "{x}#{NA.theme[:filename]}#{File.basename(@file)}:#{@line}{x}#{NA.theme[:bracket]}[{x}#{NA.theme[:project]}#{@project}:#{@parent.join('>')}{x}#{NA.theme[:bracket]}]{x} | #{NA.theme[:action]}#{@action}{x}#{NA.theme[:note]}#{note}"
    end

    # Inspect the action object
    #
    # @return [String]
    def inspect
      <<~EOINSPECT
        @file: #{@file}
        @project: #{@project}
        @parent: #{@parent.join('>')}
        @action: #{@action}
        @tags: #{@tags}
        @note: #{@note}
      EOINSPECT
    end

    #
    # Pretty print an action with color and template formatting
    #
    # @param extension [String] File extension
    # @param template [Hash] Color template
    # @param regexes [Array] Regexes to highlight
    # @param notes [Boolean] Include notes
    # @param detect_width [Boolean] Detect terminal width
    # @return [String]
    def pretty(extension: 'taskpaper', template: {}, regexes: [], notes: false, detect_width: true)
      NA::Benchmark.measure('Action.pretty') do
        # Use cached theme instead of loading every time
        theme = NA.theme
        template = theme.merge(template)

        # Pre-compute common template parts to avoid repeated processing
        output_template = template[:templates][:output]
        needs_filename = output_template.include?('%filename')
        needs_parents = output_template.include?('%parents') || output_template.include?('%parent')
        needs_project = output_template.include?('%project')

        # Create the hierarchical parent string (optimized)
        parents = if needs_parents && @parent.any?
                    parent_parts = @parent.map { |par| "#{template[:parent]}#{par}" }.join(template[:parent_divider])
                    NA::Color.template("{x}#{template[:bracket]}[#{template[:error]}#{parent_parts}{x}#{template[:bracket]}]{x} ")
                  else
                    ''
                  end

        # Create the project string (optimized)
        project = if needs_project && !@project.empty?
                    NA::Color.template("{x}#{template[:project]}#{@project}{x} ")
                  else
                    ''
                  end

        # Create the source filename string (optimized)
        filename = if needs_filename
                     path = @file ? @file.sub(%r{^\./}, '').sub(/#{Dir.home}/, '~') : ''
                     if File.dirname(path) == '.'
                       fname = NA.include_ext ? File.basename(path) : File.basename(path, ".#{extension}")
                       fname = "./#{fname}" if NA.show_cwd_indicator
                       NA::Color.template("#{template[:filename]}#{fname} {x}")
                     else
                       colored = (NA.include_ext ? path : path.sub(/\.#{extension}$/, '')).highlight_filename
                       NA::Color.template("#{template[:filename]}#{colored} {x}")
                     end
                   else
                     ''
                   end

        # colorize the action and highlight tags (optimized)
        action_text = @action.dup
        action_text.gsub!(/\{(.*?)\}/, '\\{\1\\}')
        action_text = action_text.sub(/ @#{NA.na_tag}\b/, '')
        action = NA::Color.template("#{template[:action]}#{action_text}{x}")
        action = action.highlight_tags(color: template[:tags],
                                       parens: template[:value_parens],
                                       value: template[:values],
                                       last_color: template[:action])

        # Handle notes and wrapping (optimized)
        note = ''
        if @note.any?
          if notes
            if detect_width
              # Cache width calculation
              width = @cached_width ||= TTY::Screen.columns
              # Calculate indent more efficiently - avoid repeated template processing
              base_template = output_template.gsub('%action', '').gsub('%note', '')
              base_output = base_template.gsub('%filename', filename).gsub('%project', project).gsub(/%parents?/,
                                                                                                     parents)
              indent = NA::Color.uncolor(NA::Color.template(base_output)).length
              note = NA::Color.template(@note.wrap(width, indent, template[:note]))
            else
              note = NA::Color.template("\n#{@note.map { |l| "  {x}#{template[:note]}• #{l}{x}" }.join("\n")}")
            end
          else
            action += "{x}#{template[:note]}*"
          end
        end

        # Wrap action if needed (optimized)
        if detect_width && !action.empty?
          width = @cached_width ||= TTY::Screen.columns
          base_template = output_template.gsub('%action', '').gsub('%note', '')
          base_output = base_template.gsub('%filename', filename).gsub('%project', project).gsub(/%parents?/, parents)
          indent = NA::Color.uncolor(NA::Color.template(base_output)).length
          action = action.wrap(width, indent)
        end

        # Replace variables in template string and output colorized (optimized)
        final_output = output_template.dup
        final_output.gsub!('%filename', filename)
        final_output.gsub!('%project', project)
        final_output.gsub!(/%parents?/, parents)
        final_output.gsub!('%action', action.highlight_search(regexes))
        final_output.gsub!('%note', note)
        final_output.gsub!('\\{', '{')

        NA::Color.template(final_output)
      end
    end

    # Check if action tags match any, all, and none criteria
    #
    # @param any [Array] Tags to match any
    # @param all [Array] Tags to match all
    # @param none [Array] Tags to match none
    # @return [Boolean]
    def tags_match?(any: [], all: [], none: [])
      tag_matches_any(any) && tag_matches_all(all) && tag_matches_none(none)
    end

    # Check if action or note matches any, all, and none search criteria
    #
    # @param any [Array] Regexes to match any
    # @param all [Array] Regexes to match all
    # @param none [Array] Regexes to match none
    # @param include_note [Boolean] Include note in search
    # @return [Boolean]
    def search_match?(any: [], all: [], none: [], include_note: true)
      search_matches_any(any, include_note: include_note) &&
        search_matches_all(all, include_note: include_note) &&
        search_matches_none(none, include_note: include_note)
    end

    private

    # Check if action and note do not match any regexes
    #
    # @param regexes [Array] Regexes to check
    # @param include_note [Boolean] Include note in search
    # @return [Boolean]
    def search_matches_none(regexes, include_note: true)
      regexes.each do |rx|
        regex = rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE)
        note_matches = include_note && @note.join(' ').match(regex)
        return false if @action.match(regex) || note_matches
      end
      true
    end

    # Check if action or note matches any regexes
    #
    # @param regexes [Array] Regexes to check
    # @param include_note [Boolean] Include note in search
    # @return [Boolean]
    def search_matches_any(regexes, include_note: true)
      return true if regexes.empty?

      regexes.each do |rx|
        regex = rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE)
        note_matches = include_note && @note.join(' ').match(regex)
        return true if @action.match(regex) || note_matches
      end
      false
    end

    # Check if action or note matches all regexes
    #
    # @param regexes [Array] Regexes to check
    # @param include_note [Boolean] Include note in search
    # @return [Boolean]
    def search_matches_all(regexes, include_note: true)
      regexes.each do |rx|
        regex = rx.is_a?(Regexp) ? rx : Regexp.new(rx, Regexp::IGNORECASE)
        note_matches = include_note && @note.join(' ').match(regex)
        return false unless @action.match(regex) || note_matches
      end
      true
    end

    # Check if none of the tags match
    #
    # @param tags [Array] Tags to check
    # @return [Boolean]
    def tag_matches_none(tags)
      tags.each do |tag|
        return false if compare_tag(tag)
      end
      true
    end

    # Check if any of the tags match
    #
    # @param tags [Array] Tags to check
    # @return [Boolean]
    def tag_matches_any(tags)
      return true if tags.empty?

      tags.each do |tag|
        return true if compare_tag(tag)
      end
      false
    end

    # Check if all of the tags match
    #
    # @param tags [Array] Tags to check
    # @return [Boolean]
    def tag_matches_all(tags)
      tags.each do |tag|
        return false unless compare_tag(tag)
      end
      true
    end

    # Compare a tag against the action's tags with optional value comparison
    #
    # @param tag [Hash] Tag criteria
    # @return [Boolean]
    def compare_tag(tag)
      tag_regex = tag[:tag].is_a?(Regexp) ? tag[:tag] : Regexp.new(tag[:tag], Regexp::IGNORECASE)
      keys = @tags.keys.delete_if { |k| k !~ tag_regex }
      return false if keys.empty?

      key = keys[0]
      return true if tag[:comp].nil?

      tag_val = @tags[key]
      val = tag[:value]

      return false if tag_val.nil?

      begin
        tag_date = Time.parse(tag_val)
        require 'chronic' unless defined?(Chronic)
        date = Chronic.parse(val)

        raise ArgumentError if date.nil?

        unless val =~ /(\d:\d|a[mp]|now)/i
          tag_date = Time.parse(tag_date.strftime('%Y-%m-%d 12:00'))
          date = Time.parse(date.strftime('%Y-%m-%d 12:00'))
        end

        case tag[:comp]
        when /^>$/
          tag_date > date
        when /^<$/
          tag_date < date
        when /^<=$/
          tag_date <= date
        when /^>=$/
          tag_date >= date
        when /^==?$/
          tag_date == date
        when /^\$=$/
          tag_val =~ /#{val.wildcard_to_rx}/i
        when /^\*=$/
          tag_val =~ /#{val.wildcard_to_rx}/i
        when /^\^=$/
          tag_val =~ /^#{val.wildcard_to_rx}/
        else
          false
        end
      rescue ArgumentError
        case tag[:comp]
        when /^>$/
          tag_val.to_f > val.to_f
        when /^<$/
          tag_val.to_f < val.to_f
        when /^<=$/
          tag_val.to_f <= val.to_f
        when /^>=$/
          tag_val.to_f >= val.to_f
        when /^==?$/
          tag_val =~ /^#{val.wildcard_to_rx}$/
        when /^=~$/
          tag_val =~ Regexp.new(val, Regexp::IGNORECASE)
        when /^\$=$/
          tag_val =~ /#{val.wildcard_to_rx}$/i
        when /^\*=$/
          tag_val =~ /.*?#{val.wildcard_to_rx}.*?/i
        when /^\^=$/
          tag_val =~ /^#{val.wildcard_to_rx}/i
        else
          false
        end
      end
    end

    def scan_tags
      tags = {}
      rx = /(?<= |^)@(?<tag>\S+?)(?:\((?<value>.*?)\))?(?= |$)/
      all_tags = []
      @action.scan(rx) { all_tags << Regexp.last_match }
      all_tags.each do |m|
        tag = m.named_captures.symbolize_keys
        tags[tag[:tag]] = tag[:value]
      end

      tags
    end
  end
end
