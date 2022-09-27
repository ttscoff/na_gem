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

    def pretty(extension: 'taskpaper', template: {})
      default_template = {
        file: '{xbk}',
        parent: '{c}',
        parent_divider: '{xw}/',
        action: '{g}',
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
        parents = "#{parents} "
      else
        parents = ''
      end

      project = NA::Color.template("#{template[:project]}#{@project}{x} ")

      filename = NA::Color.template("#{template[:file]}#{@file.sub(/^\.\//, '').sub(/\.#{extension}$/, '')} {x}")

      action = NA::Color.template("#{template[:action]}#{@action}{x}")
      action = action.highlight_tags(color: template[:tags], parens: template[:value_parens], value: template[:values])

      NA::Color.template(template[:output].gsub(/%filename/, filename)
                          .gsub(/%project/, project)
                          .gsub(/%parents?/, parents)
                          .gsub(/%action/, action))
    end
  end
end
