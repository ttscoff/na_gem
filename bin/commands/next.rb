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

    c.desc 'Display matches from a known todo file'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo], multiple: true

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
    c.flag %i[search], multiple: true

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

    c.action do |global_options, options, args|
      if global_options[:add]
        cmd = ['add']
        cmd.push('--note') if global_options[:note]
        cmd.concat(['--priority', global_options[:priority]]) if global_options[:priority]
        cmd.push(NA.command_line) if NA.command_line.count > 1
        cmd.unshift(*NA.globals)
        exit run(cmd)
      end

      options[:nest] = true if options[:omnifocus]

      depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
                3
              else
                options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
              end

      all_req = options[:tagged].join(' ') !~ /[+!-]/ && !options[:or]
      tags = []
      options[:tagged].join(',').split(/ *, */).each do |arg|
        m = arg.match(/^(?<req>[+!-])?(?<tag>[^ =<>$\^]+?)(?:(?<op>[=<>]{1,2}|[*$\^]=)(?<val>.*?))?$/)

        tags.push({
                    tag: m['tag'].wildcard_to_rx,
                    comp: m['op'],
                    value: m['val'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!-]/
                  })
      end

      args.concat(options[:in])
      if args.count.positive?
        all_req = args.join(' ') !~ /[+!-]/

        tokens = []
        args.each do |arg|
          arg.split(/ *, */).each do |a|
            m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: !m['req'].nil? && m['req'] == '+',
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/
                        })
          end
        end
      end

      search = nil
      if options[:search]
        if options[:exact]
          search = options[:search].join(' ')
        elsif options[:regex]
          search = Regexp.new(options[:search].join(' '), Regexp::IGNORECASE)
        else
          search = []
          all_req = options[:search].join(' ') !~ /[+!-]/ && !options[:or]

          options[:search].join(' ').split(/ /).each do |arg|
            m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            search.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/
                        })
          end
        end
      end

      NA.na_tag = options[:tag] unless options[:tag].nil?
      require_na = true

      tag = [{ tag: NA.na_tag, value: nil }]
      tag << { tag: 'done', value: nil, negate: true } unless options[:done]
      tag.concat(tags)
      todo = NA::Todo.new({ depth: depth,
                            done: options[:done],
                            query: tokens,
                            tag: tag,
                            search: search,
                            project: options[:project],
                            require_na: require_na })
      NA::Pager.paginate = false if options[:omnifocus]
      todo.actions.output(depth,
                          files: todo.files,
                          notes: options[:notes],
                          nest: options[:nest],
                          nest_projects: options[:omnifocus])
    end
  end
end
