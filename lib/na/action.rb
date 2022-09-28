# frozen_string_literal: true

module NA
  class Action < Hash
    attr_reader :file, :project, :parent, :action

    def initialize(file, project, parent, action)
      super()

      @file = file
      @project = project
      @parent = parent
      @action = action
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

    def pretty(extension: 'taskpaper', template: {})
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
                          .gsub(/%action/, action))
    end
  end
end
