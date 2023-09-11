# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Add tags to matching action(s)'
  long_desc 'Provides an easy way to tag existing actions.

  Use !tag to remove a tag, use ~tag(new value) to change a tag or add a value.

  If multiple todo files are found in the current directory, a menu will
  allow you to pick which file to act on, or use --all to apply to all matches.'
  arg_name 'TAG', mutliple: true
  command %i[tag] do |c|
    c.example 'na tag "project(warpspeed)" --search "An existing task"',
              desc: 'Find "An existing task" action and add @project(warpspeed) to it'
    c.example 'na tag "!project1" --tagged project2 --all',
              desc: 'Find all actions tagged @project2 and remove @project1 from them'
    c.example 'na tag "!project2" --all',
              desc: 'Remove @project2 from all actions'
    c.example 'na tag "~project(dirt nap)" --search "An existing task"',
              desc: 'Find "An existing task" and change (or add) its @project tag value to "dirt nap"'

    c.desc 'Use a known todo file, partial matches allowed'
    c.arg_name 'TODO_FILE'
    c.flag %i[in todo]

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Act on all matches immediately (no menu)'
    c.switch %i[all], negatable: false

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

    c.desc 'Interpret search pattern as regular expression'
    c.switch %i[e regex], negatable: false

    c.desc 'Match pattern exactly'
    c.switch %i[x exact], negatable: false

    c.action do |global_options, options, args|
      tags = args.join(',').split(/ *, */)
      options[:remove] = []
      options[:tag] = []
      tags.each do |tag|
        if tag =~ /^[!-]/
          options[:remove] << tag.sub(/^[!-]/, '').sub(/^@/, '')
        elsif tag =~ /^~/
          options[:remove] << tag.sub(/^~/, '').sub(/\(.*?\)$/, '').sub(/^@/, '')
          options[:tag] << tag.sub(/^~/, '').sub(/^@/, '')
        else
          options[:tag] << tag.sub(/^@/, '')
        end
      end

      if options[:search]
        tokens = nil
        if options[:exact]
          tokens = options[:search]
        elsif options[:regex]
          tokens = Regexp.new(options[:search], Regexp::IGNORECASE)
        else
          action = options[:search].join(' ')
          tokens = []
          all_req = action !~ /[+!-]/ && !options[:or]

          action.split(/ /).each do |arg|
            m = arg.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                        })
          end
        end
      end

      all_req = options[:tagged].join(' ') !~ /[+!-]/ && !options[:or]
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

      add_tags = options[:tag] ? options[:tag].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').wildcard_to_rx } : []
      remove_tags = options[:remove] ? options[:remove].join(',').split(/ *, */).map { |t| t.sub(/^@/, '').wildcard_to_rx } : []

      if options[:file]
        file = File.expand_path(options[:file])
        NA.notify("#{NA.theme[:error]}File not found", exit_code: 1) unless File.exist?(file)

        targets = [file]
      elsif options[:todo]
        todo = []
        options[:todo].split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          todo.push({
                      token: m['tok'],
                      required: all_req || (!m['req'].nil? && m['req'] == '+'),
                      negate: !m['req'].nil? && m['req'] =~ /[!-]/ ? true : false
                    })
        end
        dirs = NA.match_working_dir(todo)

        if dirs.count == 1
          targets = [dirs[0]]
        elsif dirs.count.positive?
          targets = NA.select_file(dirs, multiple: true)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless targets && targets.count.positive?
        else
          NA.notify("#{NA.theme[:error]}Todo not found", exit_code: 1) unless targets && targets.count.positive?

        end
      else
        files = NA.find_files_matching({
                                         depth: options[:depth],
                                         done: options[:done],
                                         regex: options[:regex],
                                         require_na: false,
                                         search: tokens,
                                         tag: tags
                                       })
        NA.notify("#{NA.theme[:error]}No todo file found", exit_code: 1) if files.count.zero?

        targets = files.count > 1 ? NA.select_file(files, multiple: true) : [files[0]]
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless files.count.positive?

      end

      NA.notify("#{NA.theme[:error]}No search terms provided", exit_code: 1) if tokens.nil? && options[:tagged].empty?

      targets.each do |target|
        NA.update_action(target, tokens,
                         add_tag: add_tags,
                         all: options[:all],
                         done: options[:done],
                         remove_tag: remove_tags,
                         tagged: tags)
      end
    end
  end
end
