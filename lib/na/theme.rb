# frozen_string_literal: true

module NA
  module Theme
    class << self
      def template_help
        <<~EOHELP
          Use {X} placeholders to apply colors. Available colors are:

          w: white, k: black, g: green, l: blue,
          y: yellow, c: cyan, m: magenta, r: red,
          W: bgwhite, K: bgblack, G: bggreen, L: bgblue,
          Y: bgyellow, C: bgcyan, M: bgmagenta, R: bgred,
          d: dark, b: bold, u: underline, i: italic, x: reset

          Multiple placeholders can be combined in a single {} pair.

          You can also use {#RGB} and {#RRGGBB} to specify hex colors.
          Add a b before the # to make the hex a background color ({b#fa0}).


        EOHELP
      end

      def load_theme(template: {})
        # Default colorization, can be overridden with full or partial template variable
        default_template = {
          file: '{xbk}',
          parent: '{c}',
          bracket: '{dc}',
          parent_divider: '{xw}/',
          action: '{bg}',
          project: '{xbk}',
          tags: '{m}',
          value_parens: '{m}',
          values: '{c}',
          output: '%filename%parents| %action',
          search_highlight: '{y}',
          note: '{dw}',
          dirname: '{dw}',
          filename: '{xb}{#eccc87}',
          prompt: '{m}',
          success: '{bg}',
          error: '{b}{#b61d2a}',
          warning: '{by}',
          debug: '{dw}'
        }

        # Load custom theme
        theme_file = NA.database_path(file: 'theme.yaml')
        theme = if File.exist?(theme_file)
                  YAML.load(IO.read(theme_file)) || {}
                else
                  {}
                end
        theme = default_template.merge(theme)

        File.open(theme_file, 'w') do |f|
          f.puts template_help.comment
          f.puts YAML.dump(theme)
        end

        theme.merge(template)
      end
    end
  end
end
