# frozen_string_literal: true

module NA
  class Action < Hash
    attr_reader :file, :project, :parent, :action, :tags

    def initialize(file, project, parent, action)
      super()

      @file = file
      @project = project
      @parent = parent
      @action = action
      @tags = scan_tags
    end

    def to_s
      "(#{@file}) #{@project}:#{@parent.join('>')} | #{@action}"
    end

    def inspect
      <<~EOINSPECT
      @file: #{@file}
      @project: #{@project}
      @parent: #{@parent.join('>')}
      @action: #{@action}
      EOINSPECT
    end

    def pretty(extension: 'taskpaper', template: {}, regexes: [])
      default_template = {
        file: '{xbk}',
        parent: '{c}',
        parent_divider: '{xw}/',
        action: '{bg}',
        project: '{xbk}',
        tags: '{m}',
        value_parens: '{m}',
        values: '{y}',
        output: '%filename%parents| %action'
      }
      template = default_template.merge(template)

      if @parent != ['Inbox']
        parents = @parent.map do |par|
          NA::Color.template("#{template[:parent]}#{par}")
        end.join(NA::Color.template(template[:parent_divider]))
        parents = "{dc}[{x}#{parents}{dc}]{x} "
      else
        parents = ''
      end

      project = NA::Color.template("#{template[:project]}#{@project}{x} ")

      file = @file.sub(%r{^\./}, '').sub(/#{ENV['HOME']}/, '~')
      file = file.sub(/\.#{extension}$/, '')
      file = file.sub(/#{File.basename(@file, ".#{extension}")}$/, "{dw}#{File.basename(@file, ".#{extension}")}{x}")
      file_tpl = "#{template[:file]}#{file} {x}"
      filename = NA::Color.template(file_tpl)

      action = NA::Color.template("#{template[:action]}#{@action}{x}")
      action = action.highlight_tags(color: template[:tags],
                                     parens: template[:value_parens],
                                     value: template[:values],
                                     last_color: template[:action])

      NA::Color.template(template[:output].gsub(/%filename/, filename)
                          .gsub(/%project/, project)
                          .gsub(/%parents?/, parents)
                          .gsub(/%action/, action.highlight_search(regexes)))
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
      return false unless @tags.key?(tag[:tag])

      return true if tag[:comp].nil?

      tag_val = @tags[tag[:tag]]
      val = tag[:value]

      return false if tag_val.nil?

      return case tag[:comp]
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
             when /^\$=$/
               tag_val =~ /#{val.wildcard_to_rx}$/i
             when /^\*=$/
               tag_val =~ /#{val.wildcard_to_rx}/i
             when /^\^=$/
               tag_val =~ /^#{val.wildcard_to_rx}/
             else
               false
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
