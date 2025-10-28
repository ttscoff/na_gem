# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Find actions matching a tag'
  long_desc 'Finds actions with tags matching the arguments. An action is shown if it
  contains all of the tags listed. Add a + before a tag to make it required
  and others optional. You can specify values using TAG=VALUE pairs.
  Use <, >, and = for numeric comparisons, and *=, ^=, $=, or =~ (regex) for text comparisons.
  Date comparisons use natural language (`na tagged "due<=today"`) and
  are detected automatically.'
  arg_name 'TAG[=VALUE]'
  command %i[tagged] do |c|
    c.example 'na tagged maybe', desc: 'Show all actions tagged @maybe'
    c.example 'na tagged -d 3 "feature, idea"', desc: 'Show all actions tagged @feature AND @idea, recurse 3 levels'
    c.example 'na tagged --or "feature, idea"', desc: 'Show all actions tagged @feature OR @idea'
    c.example 'na tagged "priority>=4"', desc: 'Show actions with @priority(4) or @priority(5)'
    c.example 'na tagged "due<in 2 days"', desc: 'Show actions with a due date coming up in the next 2 days'

    c.desc 'Recurse to depth'
    c.arg_name 'DEPTH'
    c.default_value 1
    c.flag %i[d depth], type: :integer, must_match: /^\d+$/

    c.desc 'Show actions from a specific todo file in history. May use wildcards (* and ?)'
    c.arg_name 'TODO_PATH'
    c.flag %i[in]

    c.desc 'Include notes in output'
    c.switch %i[notes], negatable: true, default_value: false

    c.desc 'Show per-action durations and total'
    c.switch %i[times], negatable: false

    c.desc 'Format durations in human-friendly form'
    c.switch %i[human], negatable: false

    c.desc 'Show only actions that have a duration (@started and @done)'
    c.switch %i[only_timed], negatable: false

    c.desc 'Output times as JSON object (implies --times and --done)'
    c.switch %i[json_times], negatable: false

    c.desc 'Output only elapsed time totals (implies --times and --done)'
    c.switch %i[only_times], negatable: false

    c.desc 'Combine tags with OR, displaying actions matching ANY of the tags'
    c.switch %i[o or], negatable: false

    c.desc 'Show actions from a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[proj project]

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

    c.desc 'Include notes in search'
    c.switch %i[search_notes], negatable: true, default_value: true

    c.desc 'Search query is regular expression'
    c.switch %i[regex], negatable: false

    c.desc 'Search query is exact text match (not tokens)'
    c.switch %i[exact], negatable: false

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Show actions not matching tags'
    c.switch %i[v invert], negatable: false

    c.desc 'Save this search for future use'
    c.arg_name 'TITLE'
    c.flag %i[save]

    c.desc 'Output actions nested by file'
    c.switch %i[nest], negatable: false

    c.desc 'No filename in output'
    c.switch %i[no_file], negatable: false

    c.desc 'Output actions nested by file and project'
    c.switch %i[omnifocus], negatable: false

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
        title = options[:save].gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
        cmd = NA.command_line.join(' ').sub(/ --save[= ]*\S+/, '').split.map { |t| %("#{t}") }.join(' ')
        NA.save_search(title, cmd)
      end

      depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
                3
              else
                options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
              end

      tags = []

      all_req = args.join(' ') !~ /(?<=[, ])[+!-]/ && !options[:or]
      args.join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)
        next if m.nil?

        tags.push({
                    tag: m['tag'].sub(/^@/, '').wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!-]/
                  })
      end

      search_for_done = false
      tags.each { |tag| search_for_done = true if tag[:tag] =~ /done/ }
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
        tags.push({ tag: 'done', value: nil, negate: true }) unless search_for_done || options[:done]
        options[:done] = true if search_for_done
      end

      tokens = nil
      if options[:search]
        if options[:exact]
          tokens = options[:search].join(' ')
        elsif options[:regex]
          tokens = Regexp.new(options[:search].join(' '), Regexp::IGNORECASE)
        else
          tokens = []
          all_req = options[:search].join(' ') !~ /(?<=[, ])[+!-]/ && !options[:or]

          options[:search].join(' ').split(/ /).each do |arg|
            m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/
                        })
          end
        end
      end

      todos = nil
      if options[:in]
        todos = []
        all_req = options[:in] !~ /(?<=[, ])[+!-]/ && !options[:or]
        options[:in].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todos.push({
                       token: m['tok'],
                       required: all_req || (!m['req'].nil? && m['req'] == '+'),
                       negate: !m['req'].nil? && m['req'] =~ /[!-]/
                     })
        end
      end

      NA.notify("#{NA.theme[:error]}No actions matched search", exit_code: 1) if tags.empty? && tokens.empty?

      todo = NA::Todo.new({ depth: depth,
                            done: options[:done],
                            query: todos,
                            search: tokens,
                            search_note: options[:search_notes],
                            tag: tags,
                            negate: options[:invert],
                            project: options[:project],
                            require_na: false })

      regexes = if tokens.is_a?(Array)
                  tokens.delete_if { |token| token[:negate] }.map { |token| token[:token] }
                else
                  [tokens]
                end

      # Plugin piping (display only)
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
                            human: options[:human],
                            only_timed: options[:only_timed],
                            json_times: options[:json_times],
                            only_times: options[:only_times] })
    end
  end
end
