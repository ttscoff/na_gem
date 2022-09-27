# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    def create_todo(target, basename)
      File.open(target, 'w') do |f|
        content = <<~ENDCONTENT
        Inbox: @inbox
        #{basename}:
        \tNew Features:
        \tIdeas:
        \tBugs:
        Archive:
        Search Definitions:
        \tTop Priority @search(@priority = 5 and not @done)
        \tHigh Priority @search(@priority > 3 and not @done)
        \tMaybe @search(@maybe)
        \tNext @search(@na and not @done and not project = \"Archive\")
        ENDCONTENT
        f.puts(content)
      end
      puts NA::Color.template("{y}Created {bw}#{target}{x}")
    end

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

    def output_actions(actions, depth, extension)
      template = if NA.find_files(depth: depth, extension: extension).count > 1
                   if depth > 1
                     '%filename%parent%action'
                   else
                     '%project%parent%action'
                   end
                 else
                   '%parent%action'
                 end
      puts actions.map { |action| action.pretty(template: { output: template }) }
    end

    def parse_actions(depth: 1, extension: 'taskpaper', na_tag: 'na', query: nil, tag: nil, search: nil)
      actions = []
      required = []
      optional = []

      tag&.each do |t|
        new_rx = " @#{t[:tag]}"
        new_rx = "#{new_rx}\\(#{t[:value]}\\)" if t[:value]

        optional.push(new_rx)
        required.push(new_rx) if t[:required]
      end

      unless search.nil?
        if search.is_a?(String)
          optional.push(search)
          required.push(search)
        else
          search.each do |t|
            new_rx = t[:token].to_s

            optional.push(new_rx)
            required.push(new_rx) if t[:required]
          end
        end
      end

      na_tag = "@#{na_tag.sub(/^@/, '')}"

      if query.nil?
        files = find_files(depth: depth, extension: extension)
      else
        files = match_working_dir(query)
      end

      files.each do |file|
        save_working_dir(File.expand_path(file))
        content = IO.read(file)
        indent_level = 0
        parent = []
        content.split("\n").each do |line|
          new_action = nil
          if line =~ /([ \t]*)([^\-]+.*?):/
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
          elsif line =~ /^[ \t]*- / && line !~ / @done/
            unless optional.empty? && required.empty?
              next unless line.matches(any: optional, all: required)

            end

            action = line.sub(/^[ \t]*- /, '').sub(/ #{na_tag}/, '')
            new_action = NA::Action.new(file, File.basename(file, ".#{extension}"), parent.dup, action)
            actions.push(new_action)
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

    def match_working_dir(search)
      optional = []
      required = []

      search&.each do |t|
        new_rx = t[:token].to_s

        optional.push(new_rx)
        required.push(new_rx) if t[:required]
      end

      db_dir = File.expand_path('~/.local/share/na')
      db_file = 'tdlist.txt'
      file = File.join(db_dir, db_file)
      if File.exist?(file)
        dirs = IO.read(file).split("\n")
        dirs.delete_if { |d| !d.matches(any: optional, all: required) }
        dirs.sort.uniq
      else
        puts NA::Color.template('{r}No na database found{x}')
        Process.exit 1
      end
    end

    def save_working_dir(todo_file)
      db_dir = File.expand_path('~/.local/share/na')
      FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      db_file = 'tdlist.txt'
      file = File.join(db_dir, db_file)
      content = File.exist?(file) ? IO.read(file) : ''
      dirs = content.split(/\n/)
      dirs.push(File.expand_path(todo_file))
      dirs.sort!.uniq!
      File.open(file, 'w') { |f| f.puts dirs.join("\n") }
    end

    def weed_cache_file
      db_dir = File.expand_path('~/.local/share/na')
      db_file = 'tdlist.txt'
      file = File.join(db_dir, db_file)
      if File.exist?(file)
        dirs = IO.read(file).split("\n")
        dirs.delete_if { |f| !File.exist?(f) }
        File.open(file, 'w') { |f| f.puts dirs.join("\n") }
      end
    end
  end
end
