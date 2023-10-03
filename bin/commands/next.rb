# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Show next actions'
  long_desc 'Next actions are actions which contain the next action tag (default @na),
  do not contain @done, and are not in the Archive project.

  Arguments will target a todo file from history, whether it\'s in the current
  directory or not. Todo file queries can include path components separated by /
  or :, and may use wildcards (`*` to match any text, `?` to match a single character). Multiple queries allowed (separate arguments or separated by comma).'
  arg_name 'QUERY', optional: true
  command %i[next show] do |c|
    c.example 'na next', desc: 'display the next actions from any todo files in the current directory'
    c.example 'na next -d 3', desc: 'display the next actions from the current directory, traversing 3 levels deep'
    c.example 'na next marked', desc: 'display next actions for a project you visited in the past'

    c.desc 'Recurse to depth'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], type: :integer, must_match: /^[1-9]$/

    c.desc 'Show next actions from all known todo files (in any directory)'
    c.switch %i[all], negatable: false, default_value: false

    c.desc 'Display matches from a known todo file anywhere in history (short name)'
    c.arg_name 'TODO'
    c.flag %i[in todo], multiple: true

    c.desc 'Display matches from specific todo file ([relative] path)'
    c.arg_name 'TODO_FILE'
    c.flag %i[file]

    c.desc 'Alternate tag to search for'
    c.arg_name 'TAG'
    c.flag %i[t tag]

    c.desc 'Show actions from a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[proj project]

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

    c.desc 'Include notes in search'
    c.switch %i[search_notes], negatable: true, default_value: true

    c.desc 'Search query is regular expression'
    c.switch %i[regex], negatable: false

    c.desc 'Search query is exact text match (not tokens)'
    c.switch %i[exact], negatable: false

    c.desc 'Include notes in output'
    c.switch %i[notes], negatable: true, default_value: false

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Output actions nested by file'
    c.switch %i[nest], negatable: false

    c.desc 'Output actions nested by file and project'
    c.switch %i[omnifocus], negatable: false

    c.desc 'Save this search for future use'
    c.arg_name 'TITLE'
    c.flag %i[save]

    c.action do |global_options, options, args|
      if global_options[:add]
        cmd = ['add']
        cmd.push('--note') if global_options[:note]
        cmd.concat(['--priority', global_options[:priority]]) if global_options[:priority]
        cmd.push(NA.command_line) if NA.command_line.count > 1
        cmd.unshift(*NA.globals)
        exit run(cmd)
      end

      if options[:save]
        title = options[:save].gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
        NA.save_search(title, "#{NA.command_line.join(' ').sub(/ --save[= ]*\S+/, '').split(' ').map { |t| %("#{t}") }.join(' ')}")
      end

      options[:nest] = true if options[:omnifocus]

      depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
                3
              else
                options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
              end

      if options[:exact] || options[:regex]
        search = options[:search].join(' ')
      else
        rx = [
          '(?<=\A|[ ,])(?<req>[+!-])?@(?<tag>[^ *=<>$~\^,@(]+)',
          '(?:\((?<value>.*?)\)| *(?<op>=~|[=<>~]{1,2}|[*$\^]=) *',
          '(?<val>.*?(?=\Z|[,@])))?'
        ].join('')
        search = options[:search].join(' ').gsub(Regexp.new(rx)) do
          m = Regexp.last_match
          string = if m['value']
                     "#{m['req']}#{m['tag']}=#{m['value']}"
                   else
                     m[0]
                   end
          options[:tagged] << string.sub(/@/, '')
          ''
        end
      end

      search = search.gsub(/,/, '').gsub(/ +/, ' ') unless search.nil?

      all_req = options[:tagged].join(' ') !~ /(?<=[, ])[+!-]/ && !options[:or]
      tags = []
      options[:tagged].join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$~\^]+?) *(?:(?<op>[=<>~]{1,2}|[*$\^]=) *(?<val>.*?))?$/)

        tags.push({
                    tag: m['tag'].wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                  })
      end

      args.concat(options[:in])
      args << '*' if options[:all]
      if args.count.positive?
        all_req = args.join(' ') !~ /(?<=[, ])[+!-]/

        tokens = []
        args.each do |arg|
          arg.split(/ *, */).each do |a|
            m = a.match(/^(?<req>[+!-])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: !m['req'].nil? && m['req'] == '+',
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                        })
          end
        end
      end

      options[:done] = true if tags.any? { |tag| tag[:tag] =~ /done/ }

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
                               token: m['tok'],
                               required: all_req || (!m['req'].nil? && m['req'] == '+'),
                               negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                             })
        end
      end

      NA.na_tag = options[:tag] unless options[:tag].nil?
      require_na = true

      tag = [{ tag: NA.na_tag, value: nil, required: true, negate: false }]
      tag << { tag: 'done', value: nil, negate: true } unless options[:done]
      tag.concat(tags)

      file_path = options[:file] ? File.expand_path(options[:file]) : nil

      todo = NA::Todo.new({ depth: depth,
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
      todo.actions.output(depth,
                          files: todo.files,
                          nest: options[:nest],
                          nest_projects: options[:omnifocus],
                          notes: options[:notes])
    end
  end
end
