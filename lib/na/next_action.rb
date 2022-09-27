# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    def find_files(depth: 1, extension: 'taskpaper')
      `find . -name "*.#{extension}" -maxdepth #{depth}`.strip.split("\n")
    end

    def select_file(files)
      if TTY::Which.exist?('gum')
        args = [
          '--cursor.foreground="151"',
          '--item.foreground=""'
        ]
        `echo #{Shellwords.escape(files.join("\n"))}|#{TTY::Which.which('gum')} choose #{args.join(' ')}`.strip
      elsif TTY::Which.exist?('fzf')
        res = choose_from(files, prompt: 'Use which file?')
        unless res
          puts 'No file selected, cancelled'
          Process.exit 1
        end

        res.strip
      else
        reader = TTY::Reader.new
        puts
        files.each.with_index do |f, i|
          puts NA::Color.template(format("{bw}%<idx> 2d{xw}) {y}%<file>s{x}\n", idx: i + 1, file: f))
        end
        res = reader.read_line(NA::Color.template('{bw}Use which file? {x}')).strip.to_i
        files[res - 1]
      end
    end

    def add_action(file, action, note = nil)
      content = IO.read(file)
      unless content =~ /^[ \t]*Inbox:/i
        content = "Inbox: @inbox\n#{content}"
      end

      content.sub!(/^([ \t]*)Inbox:(.*?)$/) do
        m = Regexp.last_match
        note = note.nil? ? '' : "\n#{m[1]}\t\t#{note.join('').strip}"
        "#{m[1]}Inbox:#{m[2]}\n#{m[1]}\t- #{action}#{note}"
      end

      File.open(file, 'w') { |f| f.puts content }

      puts NA::Color.template("{by}Task added to {bw}#{file}{x}")
    end

    def parse_actions(depth: 1, extension: 'taskpaper', na_tag: 'na', tag: nil, value: nil)
      actions = []
      na_tag = "@#{na_tag.sub(/^@/, '')}"
      if tag
        tag = "@#{tag.sub(/^@/, '')}"
        tag = if value.nil?
                "#{tag}(\\((.*?)\\))?"
              else
                "#{tag}\\(#{value}\\)"
              end
      end

      files = find_files(depth: depth, extension: extension)
      files.each do |file|
        content = IO.read(file)
        indent_level = 0
        parent = []
        content.split("\n").each do |line|
          if line =~ /([ \t]*)(\S+.*?):/
            proj = Regexp.last_match(2)
            indent = line.indent_level

            if indent.zero?
              parent = [proj]
            elsif indent <= indent_level
              parent.slice!(indent_level, parent.count - indent_level)
              parent.push(proj)
            elsif indent > indent_level
              parent.push(proj)
              indent_level = indent
            end
          elsif line =~ /^[ \t]*- / && line =~ / #{na_tag}/ && line !~ / @done/
            next if !tag.nil? && line !~ / #{tag}/

            action = line.sub(/^[ \t]*- /, '').sub(/ #{na_tag}/, '')
            actions.push(NA::Action.new(file, File.basename(file, ".#{extension}"), parent, action))
          end
        end
      end
      actions
    end

    ##
    ## Generate a menu of options and allow user selection
    ##
    ## @return     [String] The selected option
    ##
    ## @param      options   [Array] The options from which to choose
    ## @param      prompt    [String] The prompt
    ## @param      multiple  [Boolean] If true, allow multiple selections
    ## @param      sorted    [Boolean] If true, sort selections alphanumerically
    ## @param      fzf_args  [Array] Additional fzf arguments
    ##
    def choose_from(options, prompt: 'Make a selection: ', multiple: false, sorted: true, fzf_args: [])
      return nil unless $stdout.isatty

      # fzf_args << '-1' # User is expecting a menu, and even if only one it seves as confirmation
      default_args = []
      default_args << %(--prompt="#{prompt}")
      default_args << "--height=#{options.count + 2}"
      default_args << '--info=inline'
      default_args << '--multi' if multiple
      header = "esc: cancel,#{multiple ? ' tab: multi-select, ctrl-a: select all,' : ''} return: confirm"
      default_args << %(--header="#{header}")
      default_args.concat(fzf_args)
      options.sort! if sorted

      res = `echo #{Shellwords.escape(options.join("\n"))}|#{TTY::Which.which('fzf')} #{default_args.join(' ')}`
      return false if res.strip.size.zero?

      res
    end
  end
end
