# frozen_string_literal: true

class App
  extend GLI::App
  desc "Show next actions"
  long_desc 'Next actions are actions which contain the next action tag (default @na),
  do not contain @done, and are not in the Archive project.

  Arguments will target a todo file from history, whether it\'s in the current
  directory or not. Todo file queries can include path components separated by /
  or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma).'
  arg_name "QUERY", optional: true
  command %i[next show] do |c|
    c.example "na next", desc: "display the next actions from any todo files in the current directory"
    c.example "na next -d 3", desc: "display the next actions from the current directory, traversing 3 levels deep"
    c.example "na next marked", desc: "display next actions for a project you visited in the past"

    c.desc "Recurse to depth"
    c.arg_name "DEPTH"
  c.flag %i[d depth], type: :integer, must_match: /^[1-9][0-9]*$/

    c.desc "Include hidden directories while traversing"
    c.switch %i[hidden], negatable: false, default_value: false

    c.desc "Show next actions from all known todo files (in any directory)"
    c.switch %i[all], negatable: false, default_value: false

    c.desc "Display matches from a known todo file anywhere in history (short name)"
    c.arg_name "TODO"
    c.flag %i[in todo], multiple: true

    c.desc "Display matches from specific todo file ([relative] path)"
    c.arg_name "TODO_FILE"
    c.flag %i[file]

    c.desc "Alternate tag to search for"
    c.arg_name "TAG"
    c.flag %i[t tag]

    c.desc "Show actions from a specific project"
    c.arg_name "PROJECT[/SUBPROJECT]"
    c.flag %i[proj project]

    c.desc "Match actions containing tag. Allows value comparisons"
    c.arg_name "TAG"
    c.flag %i[tagged], multiple: true

    c.desc "Match actions with priority, allows <>= comparison"
    c.arg_name "PRIORITY"
    c.flag %i[p prio priority], multiple: true

    c.desc "Filter results using search terms"
    c.arg_name "QUERY"
    c.flag %i[search find grep], multiple: true

    c.desc "Include notes in search"
    c.switch %i[search_notes], negatable: true, default_value: true

    c.desc "Search query is regular expression"
    c.switch %i[regex], negatable: false

    c.desc "Search query is exact text match (not tokens)"
    c.switch %i[exact], negatable: false

    c.desc "Include notes in output"
    c.switch %i[notes], negatable: true, default_value: false

    c.desc "Show per-action durations and total"
    c.switch %i[times], negatable: false

    c.desc "Format durations in human-friendly form"
    c.switch %i[human], negatable: false

    c.desc "Show only actions that have a duration (@started and @done)"
    c.switch %i[only_timed], negatable: false

    c.desc "Output times as JSON object (implies --times and --done)"
    c.switch %i[json_times], negatable: false

    c.desc "Output only elapsed time totals (implies --times and --done)"
    c.switch %i[only_times], negatable: false

    c.desc "Include @done actions"
    c.switch %i[done]

    c.desc "Run a plugin on results (STDOUT only; no file writes)"
    c.arg_name 'NAME'
    c.flag %i[plugin]

    c.desc 'Plugin input format (json|yaml|csv|text)'
    c.arg_name 'TYPE'
    c.flag %i[input]

    c.desc 'Plugin output format (json|yaml|csv|text)'
    c.arg_name 'TYPE'
    c.flag %i[output]

    c.desc 'Divider string for text IO'
    c.arg_name 'STRING'
    c.flag %i[divider]

    c.desc "Output actions nested by file"
    c.switch %i[nest], negatable: false

    c.desc "No filename in output"
    c.switch %i[no_file], negatable: false

    c.desc "Output actions nested by file and project"
    c.switch %i[omnifocus], negatable: false

    c.desc "Save this search for future use"
    c.arg_name "TITLE"
    c.flag %i[save]

    c.action do |global_options, options, args|
      # For backward compatibility with na -a
      if global_options[:add]
        cmd = ["add"]
        cmd.push("--note") if global_options[:note]
        cmd.concat(["--priority", global_options[:priority]]) if global_options[:priority]
        cmd.push(NA.command_line) if NA.command_line.count > 1
        cmd.unshift(*NA.globals)
        exit run(cmd)
      end

      if options[:save]
        title = options[:save].gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_")
        NA.save_search(title, "#{NA.command_line.join(" ").sub(/ --save[= ]*\S+/, "").split(" ").map { |t| %("#{t}") }.join(" ")}")
      end

      options[:nest] = true if options[:omnifocus]

      depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
          3
        else
          options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
        end

      # Detect TaskPaper-style @search() syntax in QUERY arguments and delegate
      # directly to the TaskPaper search runner (supports item paths and
      # advanced TaskPaper predicates).
      joined_args = args.join(' ')
      if joined_args =~ /@search\((.+)\)/
        inner = Regexp.last_match(1)
        expr = "@search(#{inner})"

        file_path = options[:file] ? File.expand_path(options[:file]) : nil
        NA::Pager.paginate = false if options[:omnifocus]

        NA.run_taskpaper_search(
          expr,
          file: file_path,
          options: {
            depth: depth,
            notes: options[:notes],
            nest: options[:nest],
            omnifocus: options[:omnifocus],
            no_file: options[:no_file],
            times: options[:times],
            human: options[:human],
            search_notes: options[:search_notes],
            invert: false,
            regex: options[:regex],
            project: options[:project],
            done: options[:done],
            require_na: true
          }
        )
        next
      end

      if options[:exact] || options[:regex]
        search = options[:search].join(" ")
      else
        #  This regex matches the following:
        #  @tag(value)
        #  @tag=value (or > < >= <=)
        #  @tag=~value
        #  @tag ^= value (or *=, $=)
        rx = [
          '(?<=\A|[ ,])(?<req>[+!-])?@(?<tag>[^ *=<>$~\^,@(]+)',
          '(?:\((?<value>.*?)\)| *(?<op>=~|[=<>~]{1,2}|[*$\^]=) *',
          '(?<val>.*?(?=\Z|[,@])))?',
        ].join("")
        # convert tag(value) to tag=value
        search = options[:search].join(" ").gsub(Regexp.new(rx)) do
          m = Regexp.last_match
          string = if m["value"]
              "#{m["req"]}#{m["tag"]}=#{m["value"]}"
            else
              m[0]
            end
          options[:tagged] << string.sub(/@/, "")
          ""
        end
      end

      search = search.gsub(/,/, "").gsub(/ +/, " ") unless search.nil?

      if options[:priority].count.positive?
        prios = options[:priority].join(",").split(/,/)
        options[:or] = true if prios.count > 1
        prios.map! do |p|
          p.sub(/([hml])$/) do
            case Regexp.last_match[1]
            when "h"
              NA.priority_map["h"]
            when "m"
              NA.priority_map["m"]
            when "l"
              NA.priority_map["l"]
            end
          end
        end
        prios.each do |p|
          options[:tagged] << if p =~ /^[<>=]{1,2}/
            "priority#{p}"
          else
            "priority=#{p}"
          end
        end
      end

      all_req = options[:tagged].join(" ") !~ /(?<=[, ])[+!-]/ && !options[:or]
      tags = []
      options[:tagged].join(",").split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)

        tags.push({
                    tag: m["tag"].wildcard_to_rx,
                    comp: m["op"],
                    value: m["val"],
                    required: all_req || (!m["req"].nil? && m["req"] == "+"),
                    negate: !m["req"].nil? && m["req"] =~ /[!-]/ ? true : false,
                  })
      end

      args.concat(options[:in])
      args << "*" if options[:all]
      if args.count.positive?
        all_req = args.join(" ") !~ /(?<=[, ])[+!-]/

        tokens = []
        args.each do |arg|
          arg.split(/ *, */).each do |a|
            m = a.match(/^(?<req>[+!-])?(?<tok>.*?)$/)
            tokens.push({
                          token: m["tok"],
                          required: !m["req"].nil? && m["req"] == "+",
                          negate: !m["req"].nil? && m["req"] =~ /[!-]/ ? true : false,
                        })
          end
        end
      end

      if options[:json_times]
        options[:times] = true
        options[:done] = true
      elsif options[:only_times]
        options[:times] = true
        options[:done] = true
      elsif options[:only_timed]
        options[:times] = true
        options[:done] = true
      elsif options[:times]
        options[:done] = true
      else
        options[:done] = true if tags.any? { |tag| tag[:tag] =~ /done/ }
      end

      search_tokens = nil
      if options[:exact]
        search_tokens = search
      elsif options[:regex]
        search_tokens = Regexp.new(search, Regexp::IGNORECASE)
      else
        search_tokens = []
        all_req = search !~ /(?<=[, ])[+!-]/ && !options[:or]

        search.split(/ /).each do |arg|
          m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          search_tokens.push({
                               token: m["tok"],
                               required: all_req || (!m["req"].nil? && m["req"] == "+"),
                               negate: !m["req"].nil? && m["req"] =~ /[!-]/ ? true : false,
                             })
        end
      end

      NA.na_tag = options[:tag] unless options[:tag].nil?
      require_na = true

      tag = [{ tag: NA.na_tag, value: nil, required: true, negate: false }]
      tag << { tag: "done", value: nil, negate: true } unless options[:done]
      tag.concat(tags)

      file_path = options[:file] ? File.expand_path(options[:file]) : nil

      # Support TaskPaper-style item paths in --project when value starts with '/'
      project_filter_paths = nil
      if options[:project]&.start_with?('/')
        project_filter_paths = NA.resolve_item_path(path: options[:project], file: file_path, depth: depth)
        options[:project] = nil
      end

      todo = NA::Todo.new({ depth: depth,
                            hidden: options[:hidden],
                            done: options[:done],
                            file_path: file_path,
                            project: options[:project],
                            query: tokens,
                            require_na: require_na,
                            search: search_tokens,
                            search_note: options[:search_notes],
                            tag: tag })
      if todo.files.empty? && tokens
        NA.notify("#{NA.theme[:error]}No matches found for #{tokens[0][:token]}.
                  Run `na todos` to see available todo files.")
      end
      NA::Pager.paginate = false if options[:omnifocus]

      # Apply item-path project filters, if any
      if project_filter_paths && project_filter_paths.any?
        todo.actions.delete_if do |a|
          parents = Array(a.parent)
          path = parents.join(':')
          project_filter_paths.none? do |p|
            path =~ /\A#{Regexp.escape(p)}(?::|\z)/i
          end
        end
      end

      # If a plugin is specified, transform actions in memory for display only
      if options[:plugin]
        NA::Plugins.ensure_plugins_home
        plugin_path = options[:plugin]
        unless File.exist?(plugin_path)
          resolved = NA::Plugins.resolve_plugin(plugin_path)
          plugin_path = resolved if resolved
        end
        if plugin_path && File.exist?(plugin_path)
          meta = NA::Plugins.parse_plugin_metadata(plugin_path)
          input_fmt = (options[:input] || meta['input'] || 'json').to_s
          output_fmt = (options[:output] || meta['output'] || input_fmt).to_s
          divider = (options[:divider] || '||')

          io_actions = todo.actions.map(&:to_plugin_io_hash)
          stdin_str = NA::Plugins.serialize_actions(io_actions, format: input_fmt, divider: divider)
          stdout = NA::Plugins.run_plugin(plugin_path, stdin_str)
          returned = Array(NA::Plugins.parse_actions(stdout, format: output_fmt, divider: divider))
          index = {}
          todo.actions.each { |a| index["#{a.file_path}:#{a.file_line}"] = a }
          returned.each do |h|
            key = "#{h['file_path']}:#{h['line'].to_i}"
            a = index[key]
            next unless a
            # Update for display: text, note, tags
            new_text = h['text'].to_s
            new_note = h['note'].to_s
            new_tags = Array(h['tags']).map { |t| [t['name'].to_s, t['value'].to_s] }
            # replace tags in text
            new_text = new_text.gsub(/(?<=\A| )@\S+(?:\(.*?\))?/, '')
            unless new_tags.empty?
              tag_str = new_tags.map { |k, v| v.to_s.empty? ? "@#{k}" : "@#{k}(#{v})" }.join(' ')
              new_text = new_text.strip + (tag_str.empty? ? '' : " #{tag_str}")
            end
            a.action = new_text
            a.note = new_note.empty? ? [] : new_note.split("\n")
            a.instance_variable_set(:@tags, a.scan_tags)
            # parents -> possibly change project and parent chain for display
            parents = Array(h['parents']).map(&:to_s)
            if parents.any?
              new_proj = parents.first.to_s
              new_chain = parents[1..] || []
              a.instance_variable_set(:@project, new_proj)
              a.parent = new_chain
            end
          end
        end
      end
      todo.actions.output(depth,
                          { files: todo.files,
                            nest: options[:nest],
                            nest_projects: options[:omnifocus],
                            notes: options[:notes],
                            no_files: options[:no_file],
                            times: options[:times],
                            human: options[:human],
                            only_timed: options[:only_timed],
                            json_times: options[:json_times],
                            only_times: options[:only_times] })
    end
  end
end
