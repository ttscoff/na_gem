# frozen_string_literal: true

module NA
  class Action < Hash
    attr_reader :file, :project, :parent, :tags, :line

    attr_accessor :action, :note

    def initialize(file, project, parent, action, idx, note = [])
      super()

      @file = file
      @project = project
      @parent = parent
      @action = action.gsub(/\{/, '\\{')
      @tags = scan_tags
      @line = idx
      @note = note
    end

    def process(priority: 0, finish: false, add_tag: [], remove_tag: [], note: [])
      string = @action.dup

      if priority&.positive?
        string.gsub!(/(?<=\A| )@priority\(\d+\)/, '').strip!
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

      @action = string
      @action.expand_date_tags
      @note = note unless note.empty?
    end

    def to_s
      note = if @note.count.positive?
               "\n#{@note.join("\n")}"
             else
               ''
             end
      "(#{@file}:#{@line}) #{@project}:#{@parent.join('>')} | #{@action}#{note}"
    end

    def inspect
      <<~EOINSPECT
      @file: #{@file}
      @project: #{@project}
      @parent: #{@parent.join('>')}
      @action: #{@action}
      @note: #{@note}
      EOINSPECT
    end

    ##
    ## Pretty print an action
    ##
    ## @param      extension  [String] The file extension
    ## @param      template   [Hash] The template to use for
    ##                        colorization
    ## @param      regexes    [Array] The regexes to
    ##                        highlight (searches)
    ## @param      notes      [Boolean] Include notes
    ##
    def pretty(extension: 'taskpaper', template: {}, regexes: [], notes: false, detect_width: true)
      theme = NA::Theme.load_theme
      template = theme.merge(template)

      # Create the hierarchical parent string
      parents = @parent.map do |par|
        NA::Color.template("{x}#{template[:parent]}#{par}")
      end.join(NA::Color.template(template[:parent_divider]))
      parents = "#{NA.theme[:bracket]}[#{NA.theme[:error]}#{parents}#{NA.theme[:bracket]}]{x} "

      # Create the project string
      project = NA::Color.template("#{template[:project]}#{@project}{x} ")

      # Create the source filename string, substituting ~ for HOME and removing extension
      file = @file.sub(%r{^\./}, '').sub(/#{ENV['HOME']}/, '~')
      file = file.sub(/\.#{extension}$/, '')
      # colorize the basename
      file = file.highlight_filename
      file_tpl = "#{template[:file]}#{file} {x}"
      filename = NA::Color.template(file_tpl)

      # Add notes if needed
      note = if notes && @note.count.positive?
               NA::Color.template("\n#{@note.map { |l| "  #{template[:note]}• #{l}{x}" }.join("\n")}")
             else
               ''
             end

      # colorize the action and highlight tags
      action = NA::Color.template("#{template[:action]}#{@action.sub(/ @#{NA.na_tag}\b/, '')}{x}")
      action = action.highlight_tags(color: template[:tags],
                                     parens: template[:value_parens],
                                     value: template[:values],
                                     last_color: template[:action])

      if detect_width
        width = TTY::Screen.columns
        prefix = NA::Color.uncolor(pretty(template: { output: template[:templates][:output].sub(/%action/, '') }, detect_width: false))
        indent = prefix.length
        action = action.wrap(width, indent)
      end

      # Replace variables in template string and output colorized
      NA::Color.template(template[:output].gsub(/%filename/, filename)
                          .gsub(/%project/, project)
                          .gsub(/%parents?/, parents)
                          .gsub(/%action/, action.highlight_search(regexes))
                          .gsub(/%note/, note)).gsub(/\\\{/, '{')
    end

    def tags_match?(any: [], all: [], none: [])
      tag_matches_any(any) && tag_matches_all(all) && tag_matches_none(none)
    end

    def search_match?(any: [], all: [], none: [])
      search_matches_any(any) && search_matches_all(all) && search_matches_none(none)
    end

    private

    def search_matches_none(regexes)
      regexes.each do |rx|
        return false if @action.match(Regexp.new(rx, Regexp::IGNORECASE))
      end
      true
    end

    def search_matches_any(regexes)
      return true if regexes.empty?

      regexes.each do |rx|
        return true if @action.match(Regexp.new(rx, Regexp::IGNORECASE))
      end
      false
    end

    def search_matches_all(regexes)
      regexes.each do |rx|
        return false unless @action.match(Regexp.new(rx, Regexp::IGNORECASE))
      end
      true
    end

    def tag_matches_none(tags)
      tags.each do |tag|
        return false if compare_tag(tag)
      end
      true
    end

    def tag_matches_any(tags)
      return true if tags.empty?

      tags.each do |tag|
        return true if compare_tag(tag)
      end
      false
    end

    def tag_matches_all(tags)
      tags.each do |tag|
        return false unless compare_tag(tag)
      end
      true
    end

    def compare_tag(tag)
      keys = @tags.keys.delete_if { |k| k !~ Regexp.new(tag[:tag], Regexp::IGNORECASE) }
      return false if keys.empty?

      key = keys[0]

      return true if tag[:comp].nil?

      tag_val = @tags[key]
      val = tag[:value]

      return false if tag_val.nil?

      begin
        tag_date = Time.parse(tag_val)
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
