# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    attr_accessor :verbose, :extension, :na_tag

    def create_todo(target, basename)
      File.open(target, 'w') do |f|
        content = <<~ENDCONTENT
          Inbox: @inbox
          #{basename}:
          \tFeature Requests:
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
      $stderr.puts NA::Color.template("{y}Created {bw}#{target}{x}")
    end

    def find_files(depth: 1)
      files = `find . -name "*.#{NA.extension}" -maxdepth #{depth}`.strip.split("\n")
      files.each { |f| save_working_dir(File.expand_path(f)) }
      files
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
          $stderr.puts 'No file selected, cancelled'
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

    def add_action(file, project, action, note = nil)
      content = IO.read(file)
      unless content =~ /^[ \t]*#{project}:/i
        content = "#{project.cap_first}:\n#{content}"
      end

      content.sub!(/^([ \t]*)#{project}:(.*?)$/i) do
        m = Regexp.last_match
        note = note.nil? ? '' : "\n#{m[1]}\t\t#{note.join('').strip}"
        "#{m[1]}#{project.cap_first}:#{m[2]}\n#{m[1]}\t- #{action}#{note}"
      end

      File.open(file, 'w') { |f| f.puts content }

      $stderr.puts NA::Color.template("{by}Task added to {bw}#{file}{x}")
    end

    def output_actions(actions, depth, files: nil)
      template = if files&.count.positive?
                   if files.count == 1
                     '%parent%action'
                   else
                     '%filename%parent%action'
                   end
                 elsif find_files(depth: depth).count > 1
                   if depth > 1
                     '%filename%parent%action'
                   else
                     '%project%parent%action'
                   end
                 else
                   '%parent%action'
                 end
      if files && @verbose
        $stderr.puts files.map { |f| NA::Color.template("{dw}#{f}{x}") }
      end

      puts actions.map { |action| action.pretty(template: { output: template }) }
    end

    def parse_actions(depth: 1, query: nil, tag: nil, search: nil, require_na: true)
      actions = []
      required = []
      optional = []
      negated = []

      tag&.each do |t|
        unless t[:tag].nil?
          new_rx = " @#{t[:tag]}\\b"
          new_rx = "#{new_rx}\\(#{t[:value]}\\)" if t[:value]

          optional.push(new_rx) unless t[:negate]
          required.push(new_rx) if t[:required] && !t[:negate]
          negated.push(new_rx) if t[:negate]
        end
      end

      unless search.nil?
        if search.is_a?(String)
          optional.push(search)
          required.push(search)
        else
          search.each do |t|
            new_rx = t[:token].to_s

            optional.push(new_rx) unless t[:negate]
            required.push(new_rx) if t[:required] && !t[:negate]
            negated.push(new_rx) if t[:negate]
          end
        end
      end

      na_tag = "@#{NA.na_tag.sub(/^@/, '')}"

      if query.nil?
        files = find_files(depth: depth)
      else
        files = match_working_dir(query)
      end

      files.each do |file|
        save_working_dir(File.expand_path(file))
        content = IO.read(file)
        indent_level = 0
        parent = []
        content.split("\n").each do |line|
          if line =~ /([ \t]*)([^\-]+.*?): *(@\S+ *)*$/
            proj = Regexp.last_match(2)
            indent = line.indent_level

            if indent.zero?
              parent = [proj]
            elsif indent <= indent_level
              parent.slice!(indent, parent.count - indent)
              parent.push(proj)
            elsif indent > indent_level
              parent.push(proj)
            end

            indent_level = indent
          elsif line =~ /^[ \t]*- / && line !~ / @done/
            next if require_na && line !~ /@#{NA.na_tag}\b/

            unless optional.empty? && required.empty? && negated.empty?
              next unless line.matches(any: optional, all: required, none: negated)

            end

            action = line.sub(/^[ \t]*- /, '').sub(/ @#{NA.na_tag}\b/, '')
            new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action)
            actions.push(new_action)
          end
        end
      end
      [files, actions]
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

    def database_path
      db_dir = File.expand_path('~/.local/share/na')
      FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      db_file = 'tdlist.txt'
      File.join(db_dir, db_file)
    end

    def match_working_dir(search)
      optional = []
      required = []

      search&.each do |t|
        new_rx = t[:token].to_s.split('').join('.{0,1}')

        optional.push(new_rx)
        required.push(new_rx) if t[:required]
      end

      file = database_path
      if File.exist?(file)
        dirs = IO.read(file).split("\n")
        dirs.delete_if { |d| !d.matches(any: optional, all: required) }
        dirs.sort.uniq
      else
        $stderr.puts NA::Color.template('{r}No na database found{x}')
        Process.exit 1
      end
    end

    def save_working_dir(todo_file)
      file = database_path
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

    def edit_file(file: nil, app: nil)
      os_open(file, app: app) if file && File.exist?(file)
    end

    ##
    ## Platform-agnostic open command
    ##
    ## @param      file  [String] The file to open
    ##
    def os_open(file, app: nil)
      os = RbConfig::CONFIG['target_os']
      case os
      when /darwin.*/i
        if app
          `open -a "#{app}" #{Shellwords.escape(file)}`
        else
          `open #{Shellwords.escape(file)}`
        end
      when /mingw|mswin/i
        `start #{Shellwords.escape(file)}`
      else
        if 'xdg-open'.available?
          `xdg-open #{Shellwords.escape(file)}`
        else
          $stderr.puts NA::Color.template('{r}Unable to determine executable for `open`.{x}')
        end
      end
    end
  end
end
