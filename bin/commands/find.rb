# frozen_string_literal: true

desc 'Find actions matching a search pattern'
long_desc 'Search tokens are separated by spaces. Actions matching all tokens in the pattern will be shown
(partial matches allowed). Add a + before a token to make it required, e.g. `na find +feature +maybe`,
add a - or ! to ignore matches containing that token.'
arg_name 'PATTERN'
command %i[find grep] do |c|
  c.example 'na find feature idea swift', desc: 'Find all actions containing feature, idea, and swift'
  c.example 'na find feature idea -swift', desc: 'Find all actions containing feature and idea but NOT swift'
  c.example 'na find -x feature idea', desc: 'Find all actions containing the exact text "feature idea"'

  c.desc 'Interpret search pattern as regular expression'
  c.switch %i[e regex], negatable: false

  c.desc 'Match pattern exactly'
  c.switch %i[x exact], negatable: false

  c.desc 'Recurse to depth'
  c.arg_name 'DEPTH'
  c.flag %i[d depth], type: :integer, must_match: /^\d+$/

  c.desc 'Show actions from a specific todo file in history. May use wildcards (* and ?)'
  c.arg_name 'TODO_PATH'
  c.flag %i[in]

  c.desc 'Include notes in output'
  c.switch %i[notes], negatable: true, default_value: false

  c.desc 'Combine search tokens with OR, displaying actions matching ANY of the terms'
  c.switch %i[o or], negatable: false

  c.desc 'Show actions from a specific project'
  c.arg_name 'PROJECT[/SUBPROJECT]'
  c.flag %i[proj project]

  c.desc 'Match actions containing tag. Allows value comparisons'
  c.arg_name 'TAG'
  c.flag %i[tagged], multiple: true

  c.desc 'Include @done actions'
  c.switch %i[done]

  c.desc 'Show actions not matching search pattern'
  c.switch %i[v invert], negatable: false

  c.desc 'Save this search for future use'
  c.arg_name 'TITLE'
  c.flag %i[save]

  c.desc 'Output actions nested by file'
  c.switch %[nest], negatable: false

  c.desc 'Output actions nested by file and project'
  c.switch %[omnifocus], negatable: false

  c.action do |global_options, options, args|
    options[:nest] = true if options[:omnifocus]

    if options[:save]
      title = options[:save].gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
      NA.save_search(title, "#{NA.command_line.join(' ').sub(/ --save[= ]*\S+/, '').split(' ').map { |t| %("#{t}") }.join(' ')}")
    end


    depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
              3
            else
              options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
            end

    all_req = options[:tagged].join(' ') !~ /[+!\-]/ && !options[:or]
    tags = []
    options[:tagged].join(',').split(/ *, */).each do |arg|
      m = arg.match(/^(?<req>[+\-!])?(?<tag>[^ =<>$\^]+?)(?:(?<op>[=<>]{1,2}|[*$\^]=)(?<val>.*?))?$/)

      tags.push({
                  tag: m['tag'].wildcard_to_rx,
                  comp: m['op'],
                  value: m['val'],
                  required: all_req || (!m['req'].nil? && m['req'] == '+'),
                  negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                })
    end

    tokens = nil
    if options[:exact]
      tokens = args.join(' ')
    elsif options[:regex]
      tokens = Regexp.new(args.join(' '), Regexp::IGNORECASE)
    else
      tokens = []
      all_req = args.join(' ') !~ /[+!\-]/ && !options[:or]

      args.join(' ').split(/ /).each do |arg|
        m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
        tokens.push({
                      token: m['tok'],
                      required: all_req || (!m['req'].nil? && m['req'] == '+'),
                      negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                    })
      end
    end

    todo = nil
    if options[:in]
      todo = []
      options[:in].split(/ *, */).each do |a|
        m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
        todo.push({
                    token: m['tok'],
                    required: all_req || (!m['req'].nil? && m['req'] == '+'),
                    negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                  })
      end
    end

    files, actions, = NA.parse_actions(depth: depth,
                                       done: options[:done],
                                       query: todo,
                                       search: tokens,
                                       tag: tags,
                                       negate: options[:invert],
                                       regex: options[:regex],
                                       project: options[:project],
                                       require_na: false)
    regexes = if tokens.is_a?(Array)
                tokens.delete_if { |token| token[:negate] }.map { |token| token[:token] }
              else
                [tokens]
              end

    NA.output_actions(actions, depth, files: files, regexes: regexes, notes: options[:notes], nest: options[:nest], nest_projects: options[:omnifocus])
  end
end
