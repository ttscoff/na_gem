# frozen_string_literal: true

# Next Action methods
module NA
  class << self
    attr_accessor :verbose, :extension, :na_tag

    def notify(msg, exit_code: false)
      $stderr.puts NA::Color.template("{x}#{msg}{x}")
      if exit_code && exit_code.is_a?(Number)
        Process.exit exit_code
      end
    end

    def create_todo(target, basename)
      File.open(target, 'w') do |f|
        content = <<~ENDCONTENT
          Inbox:
          #{basename}:
          \tFeature Requests:
          \tIdeas:
          \tBugs:
          Archive:
          Search Definitions:
          \tTop Priority @search(@priority = 5 and not @done)
          \tHigh Priority @search(@priority > 3 and not @done)
          \tMaybe @search(@maybe)
          \tNext @search(@#{NA.na_tag} and not @done and not project = \"Archive\")
        ENDCONTENT
        f.puts(content)
      end
      notify("{y}Created {bw}#{target}")
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
          notify('{r}No file selected, cancelled', exit_code: 1)
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

      notify("{by}Task added to {bw}#{file}")
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
        files.map { |f| notify("{dw}#{f}") }
      end

      puts actions.map { |action| action.pretty(template: { output: template }) }
    end

    def parse_actions(depth: 1, query: nil, tag: nil, search: nil, negate: false, regex: false, project: nil, require_na: true)
      actions = []
      required = []
      optional = []
      negated = []
      required_tag = []
      optional_tag = []
      negated_tag = []

      tag&.each do |t|
        unless t[:tag].nil?
          if negate
            optional_tag.push(t) if t[:negate]
            required_tag.push(t) if t[:required] && t[:negate]
            negated_tag.push(t) unless t[:negate]
          else
            optional_tag.push(t) unless t[:negate]
            required_tag.push(t) if t[:required] && !t[:negate]
            negated_tag.push(t) if t[:negate]
          end
        end
      end

      unless search.nil?
        if regex || search.is_a?(String)
          if negate
            negated.push(search)
          else
            optional.push(search)
            required.push(search)
          end
        else
          search.each do |t|
            optional, required, negated = parse_search(t, negate)
          end
        end
      end

      files = if query.nil?
                find_files(depth: depth)
              else
                match_working_dir(query)
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

            action = line.sub(/^[ \t]*- /, '').sub(/ @#{NA.na_tag}\b/, '')
            new_action = NA::Action.new(file, File.basename(file, ".#{NA.extension}"), parent.dup, action)

            has_search = !optional.empty? || !required.empty? || !negated.empty?
            next if has_search && !new_action.search_match?(any: optional,
                                                            all: required,
                                                            none: negated)

            if project
              rx = project.split(%r{[/:]}).join('.*?/.*?')
              next unless parent.join('/') =~ Regexp.new(rx, Regexp::IGNORECASE)
            end

            has_tag = !optional_tag.empty? || !required_tag.empty? || !negated_tag.empty?
            next if has_tag && !new_action.tags_match?(any: optional_tag,
                                                       all: required_tag,
                                                       none: negated_tag)

            actions.push(new_action)
          end
        end
      end
      [files, actions]
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
        darwin_open(file, app: app)
      when /mingw|mswin/i
        win_open(file)
      else
        linux_open(file)
      end
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

    private

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

      default_args = [%(--prompt="#{prompt}"), "--height=#{options.count + 2}", '--info=inline']
      default_args << '--multi' if multiple
      header = "esc: cancel,#{multiple ? ' tab: multi-select, ctrl-a: select all,' : ''} return: confirm"
      default_args << %(--header="#{header}")
      default_args.concat(fzf_args)
      options.sort! if sorted

      res = `echo #{Shellwords.escape(options.join("\n"))}|#{TTY::Which.which('fzf')} #{default_args.join(' ')}`
      return false if res.strip.size.zero?

      res
    end

    def parse_search(tag, negate)
      required = []
      optional = []
      negated = []
      new_rx = tag[:token].to_s.wildcard_to_rx

      if negate
        optional.push(new_rx) if tag[:negate]
        required.push(new_rx) if tag[:required] && tag[:negate]
        negated.push(new_rx) unless tag[:negate]
      else
        optional.push(new_rx) unless tag[:negate]
        required.push(new_rx) if tag[:required] && !tag[:negate]
        negated.push(new_rx) if tag[:negate]
      end

      [optional, required, negated]
    end

    ##
    ## Get path to database of known todo files
    ##
    ## @return     [String] File path
    ##
    def database_path
      db_dir = File.expand_path('~/.local/share/na')
      # Create directory if needed
      FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      db_file = 'tdlist.txt'
      File.join(db_dir, db_file)
    end

    ##
    ## Find a matching path using semi-fuzzy matching.
    ## Search tokens can include ! and + to negate or make
    ## required.
    ##
    ## @param      search    [Array] search tokens to match
    ## @param      distance  [Integer] allowed distance
    ##                       between characters
    ##
    def match_working_dir(search, distance: 1)
      optional = []
      required = []

      search&.each do |t|
        # Make "search" into "s.{0,1}e.{0,1}a.{0,1}r.{0,1}c.{0,1}h"
        new_rx = t[:token].to_s.split('').join(".{0,#{distance}}")

        optional.push(new_rx)
        required.push(new_rx) if t[:required]
      end

      match_dir(optional, required)
    end

    def match_dir(optional, required)
      file = database_path
      notify('{r}No na database found', exit_code: 1) unless File.exist?(file)

      dirs = IO.read(file).split("\n")
      dirs.delete_if { |d| !d.dir_matches(any: optional, all: required) }
      dirs.sort.uniq
    end

    def save_working_dir(todo_file)
      file = database_path
      content = File.exist?(file) ? IO.read(file) : ''
      dirs = content.split(/\n/)
      dirs.push(File.expand_path(todo_file))
      dirs.sort!.uniq!
      File.open(file, 'w') { |f| f.puts dirs.join("\n") }
    end

    def darwin_open(file, app: nil)
      if app
        `open -a "#{app}" #{Shellwords.escape(file)}`
      else
        `open #{Shellwords.escape(file)}`
      end
    end

    def win_open(file)
      `start #{Shellwords.escape(file)}`
    end

    def linux_open(file)
      if TTY::Which.exist?('xdg-open')
        `xdg-open #{Shellwords.escape(file)}`
      else
        notify('{r}Unable to determine executable for `xdg-open`.')
      end
    end
  end
end
