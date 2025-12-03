# frozen_string_literal: true

class App
  extend GLI::App
  desc "Find actions matching a search pattern"
  long_desc "Search tokens are separated by spaces. Actions matching all tokens in the pattern will be shown
  (partial matches allowed). Add a + before a token to make it required, e.g. `na find +feature +maybe`,
  add a - or ! to ignore matches containing that token."
  arg_name "PATTERN"
  command %i[find grep search] do |c|
    c.example "na find feature idea swift", desc: "Find all actions containing feature, idea, and swift"
    c.example "na find feature idea -swift", desc: "Find all actions containing feature and idea but NOT swift"
    c.example "na find -x feature idea", desc: 'Find all actions containing the exact text "feature idea"'

    c.desc "Interpret search pattern as regular expression"
    c.switch %i[e regex], negatable: false

    c.desc "Match pattern exactly"
    c.switch %i[x exact], negatable: false

    c.desc "Recurse to depth"
    c.arg_name "DEPTH"
    c.flag %i[d depth], type: :integer, must_match: /^\d+$/

    c.desc "Show actions from a specific todo file in history. May use wildcards (* and ?)"
    c.arg_name "TODO_PATH"
    c.flag %i[in]

    c.desc "Include notes in output"
    c.switch %i[notes], negatable: true, default_value: false

    c.desc "Show per-action durations and total"
    c.switch %i[times], negatable: false

    c.desc "Format durations in human-friendly form"
    c.switch %i[human], negatable: false

    c.desc "Include notes in search"
    c.switch %i[search_notes], negatable: true, default_value: true

    c.desc "Combine search tokens with OR, displaying actions matching ANY of the terms"
    c.switch %i[o or], negatable: false

    c.desc "Show actions from a specific project"
    c.arg_name "PROJECT[/SUBPROJECT]"
    c.flag %i[proj project]

    c.desc "Match actions containing tag. Allows value comparisons"
    c.arg_name "TAG"
    c.flag %i[tagged], multiple: true

    c.desc "Include @done actions"
    c.switch %i[done]

    c.desc "Show actions not matching search pattern"
    c.switch %i[v invert], negatable: false

    c.desc "Save this search for future use"
    c.arg_name "TITLE"
    c.flag %i[save]

    c.desc "Output actions nested by file"
    c.switch %[nest], negatable: false

    c.desc "No filename in output"
    c.switch %i[no_file], negatable: false

    c.desc "Output actions nested by file and project"
    c.switch %[omnifocus], negatable: false

    c.desc 'Run a plugin on results (STDOUT only; no file writes)'
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

    c.action do |global_options, options, args|
      options[:nest] = true if options[:omnifocus]

      if options[:save]
        title = options[:save].gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_")
        cmd = NA.command_line.join(" ").sub(/ --save[= ]*\S+/, "").split(" ").map { |t| %("#{t}") }.join(" ")
        NA.save_search(title, cmd)
      end

      depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
          3
        else
          options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
        end

      # Detect TaskPaper-style @search() syntax in arguments and delegate
      # directly to the TaskPaper search runner (supports OR and extended
      # TaskPaper syntax).
      joined_args = args.join(' ')
      if joined_args =~ /@search\((.+)\)/
        inner = Regexp.last_match(1)
        expr = "@search(#{inner})"
        NA.run_taskpaper_search(
          expr,
          file: nil,
          options: {
            depth: depth,
            notes: options[:notes],
            nest: options[:nest],
            omnifocus: options[:omnifocus],
            no_file: options[:no_file],
            times: options[:times],
            human: options[:human],
            search_notes: options[:search_notes],
            invert: options[:invert],
            regex: options[:regex],
            project: options[:project],
            done: options[:done],
            require_na: false
          }
        )
        next
      end

      tokens = nil
      tags = []

      if options[:exact] || options[:regex]
        search = args.join(" ")
      else
        rx = [
          '(?<=\A|[ ,])(?<req>[+!-])?@(?<tag>[^ *=<>$*\^,@(]+)',
          '(?:\((?<value>.*?)\)| *(?<op>[=<>~]{1,2}|[*$\^]=) *',
          '(?<val>.*?(?=\Z|[,@])))?',
        ].join("")
        search = args.join(" ").gsub(Regexp.new(rx)) do
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

      search = search.gsub(/ +/, " ").strip

      all_req = options[:tagged].join(" ") !~ /(?<=[, ])[+!-]/ && !options[:or]
      options_tags = []
      options[:tagged].join(",").split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)

        options_tags.push({
                            tag: m["tag"].wildcard_to_rx,
                            comp: m["op"],
                            value: m["val"],
                            required: all_req || (!m["req"].nil? && m["req"] == "+"),
                            negate: !m["req"].nil? && m["req"] =~ /[!-]/ ? true : false,
                          })
      end

      search_for_done = false
      options_tags.each { |tag| search_for_done = true if tag[:tag] =~ /done/ }
      options[:done] = true if search_for_done

      tags = options_tags

      if options[:exact]
        tokens = search
      elsif options[:regex]
        tokens = Regexp.new(search, Regexp::IGNORECASE)
      else
        tokens = []
        all_req = search !~ /(?<=[, ])[+!-]/ && !options[:or]

        search.split(/ /).each do |arg|
          m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)

          tokens.push({
                        token: m["tok"],
                        required: all_req || (!m["req"].nil? && m["req"] == "+"),
                        negate: !m["req"].nil? && m["req"] =~ /[!-]/ ? true : false,
                      })
        end
      end

      todos = nil
      if options[:in]
        todos = []
        options[:in].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todos.push({
                       token: m["tok"],
                       required: all_req || (!m["req"].nil? && m["req"] == "+"),
                       negate: !m["req"].nil? && m["req"] =~ /[!-]/,
                     })
        end
      end

      # Support TaskPaper-style item paths in --project when value starts with '/'
      project_filter_paths = nil
      if options[:project]&.start_with?('/')
        project_filter_paths = NA.resolve_item_path(path: options[:project], depth: depth)
        options[:project] = nil
      end

      todo = NA::Todo.new({
                            depth: depth,
                            done: options[:done],
                            query: todos,
                            search: tokens,
                            search_note: options[:search_notes],
                            tag: tags,
                            negate: options[:invert],
                            regex: options[:regex],
                            project: options[:project],
                            require_na: false,
                          })

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

      regexes = if tokens.is_a?(Array)
          tokens.delete_if { |token| token[:negate] }.map { |token| token[:token].wildcard_to_rx }
        else
          [tokens]
        end

      # Plugin piping (display-only)
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
            new_text = h['text'].to_s
            new_note = h['note'].to_s
            new_tags = Array(h['tags']).map { |t| [t['name'].to_s, t['value'].to_s] }
            new_text = new_text.gsub(/(?<=\A| )@\S+(?:\(.*?\))?/, '')
            unless new_tags.empty?
              tag_str = new_tags.map { |k, v| v.to_s.empty? ? "@#{k}" : "@#{k}(#{v})" }.join(' ')
              new_text = new_text.strip + (tag_str.empty? ? '' : " #{tag_str}")
            end
            a.action = new_text
            a.note = new_note.empty? ? [] : new_note.split("\n")
            a.instance_variable_set(:@tags, a.scan_tags)
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
                            regexes: regexes,
                            notes: options[:notes],
                            nest: options[:nest],
                            nest_projects: options[:omnifocus],
                            no_files: options[:no_file],
                            times: options[:times],
                            human: options[:human] })
    end
  end
end
