# frozen_string_literal: true

module NA
  # Provides theme and color template helpers for todo CLI output.
  #
  # @example Get theme help text
  #   NA::Theme.template_help
  module Theme
    class << self
      # Returns a help string describing available color placeholders for themes.
      # @return [String] Help text for theme placeholders
      # @example
      #   NA::Theme.template_help
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

      # Loads the theme configuration, merging defaults with any custom theme file and the provided template.
      # Writes the help text and theme YAML to the theme file.
      # @param template [Hash] Additional theme settings to merge
      # @return [Hash] The merged theme configuration
      # @example
      #   NA::Theme.load_theme(template: { action: '{r}' })
      def load_theme(template: {})
        if defined?(NA::Benchmark) && NA::Benchmark
          NA::Benchmark.measure('Theme.load_theme') do
            load_theme_internal(template: template)
          end
        else
          load_theme_internal(template: template)
        end
      end

      def load_theme_internal(template: {})
        # Default colorization, can be overridden with full or partial template variable
        default_template = {
          parent: '{c}',
          bracket: '{dc}',
          parent_divider: '{xw}/',
          action: '{bg}',
          project: '{xbk}',
          tags: '{m}',
          value_parens: '{m}',
          values: '{c}',
          duration: '{y}',
          search_highlight: '{y}',
          note: '{dw}',
          dirname: '{xdw}',
          filename: '{xb}{#eccc87}',
          line: '{dw}',
          prompt: '{m}',
          success: '{bg}',
          error: '{b}{#b61d2a}',
          warning: '{by}',
          debug: '{dw}',
          templates: {
            output: '%filename%line%parents| %action',
            default: '%parents %line %action',
            single_file: '%parents %line %action',
            multi_file: '%filename%line%parents %action',
            no_file: '%parents %line %action'
          }
        }

        # Load custom theme
        theme_file = NA.database_path(file: 'theme.yaml')
        theme = if File.exist?(theme_file)
                  YAML.load(File.read(theme_file)) || {}
                else
                  {}
                end
        theme = default_template.deep_merge(theme)

        File.open(theme_file, 'w') do |f|
          f.puts template_help.comment
          f.puts YAML.dump(theme)
        end

        theme.merge(template)
      end
    end
  end
end
