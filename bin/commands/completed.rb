# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Display completed actions'
  long_desc 'Search tokens are separated by spaces. Actions matching all tokens in the pattern will be shown
    (partial matches allowed). Add a + before a token to make it required, e.g. `na completed +feature +maybe`,
    add a - or ! to ignore matches containing that token.'
  arg_name 'PATTERN', optional: true, multiple: true
  command %i[completed finished] do |c|
    c.example 'na completed', desc: 'display completed actions'
    c.example 'na completed --before "2 days ago"',
              desc: 'display actions completed more than two days ago'
    c.example 'na completed --on yesterday',
              desc: 'display actions completed yesterday'
    c.example 'na completed --after "1 week ago"',
              desc: 'display actions completed in the last week'
    c.example 'na completed feature',
              desc: 'display completed actions matcning "feature"'

    c.desc 'Display actions completed before (natural language) date string'
    c.arg_name 'DATE_STRING'
    c.flag %i[b before]

    c.desc 'Display actions completed on (natural language) date string'
    c.arg_name 'DATE_STRING'
    c.flag %i[on]

    c.desc 'Display actions completed after (natural language) date string'
    c.arg_name 'DATE_STRING'
    c.flag %i[a after]

    c.desc 'Combine before, on, and/or after with OR, displaying actions matching ANY of the ranges'
    c.switch %i[o or], negatable: false

    c.desc 'Recurse to depth'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], type: :integer, must_match: /^\d+$/

    c.desc 'Show actions from a specific todo file in history. May use wildcards (* and ?)'
    c.arg_name 'TODO_PATH'
    c.flag %i[in]

    c.desc 'Include notes in output'
    c.switch %i[notes], negatable: true, default_value: false

    c.desc 'Include notes in search'
    c.switch %i[search_notes], negatable: true, default_value: true

    c.desc 'Show actions from a specific project'
    c.arg_name 'PROJECT[/SUBPROJECT]'
    c.flag %i[proj project]

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.desc 'Output actions nested by file'
    c.switch %[nest], negatable: false

    c.desc 'Output actions nested by file and project'
    c.switch %[omnifocus], negatable: false

    c.desc 'Save this search for future use'
    c.arg_name 'TITLE'
    c.flag %i[save]

    c.action do |_global_options, options, args|
      tag_string = []
      if options[:before] || options[:on] || options[:after]
        tag_string << "done<#{options[:before]}" if options[:before]
        tag_string << "done=#{options[:on]}" if options[:on]
        tag_string << "done>#{options[:after]}" if options[:after]
      else
        tag_string << 'done'
      end

      tag_string.concat(options[:tagged]) if options[:tagged]

      if args.empty?
        cmd_string = %(tagged --done)
      else
        cmd_string = %(find --tagged "#{tag_string.join(',')}" --done)
      end

      cmd_string += ' --or' if options[:or]
      cmd_string += %( --in "#{options[:in]}") if options[:in]
      cmd_string += %( --project "#{options[:project]}") if options[:project]
      cmd_string += %( --depth #{options[:depth]}) if options[:depth]
      cmd_string += ' --nest' if options[:nest]
      cmd_string += ' --omnifocus' if options[:omnifocus]
      cmd_string += " --#{options[:search_notes] ? 'search_notes' : 'no-search_notes'}"
      cmd_string += " --#{options[:notes] ? 'notes' : 'no-notes' }"

      if args.empty?
        cmd_string += " #{tag_string.join(',')}"
      else
        cmd_string += " #{args.join(' ')}"
      end

      if options[:save]
        title = options[:save].gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_')
        NA.save_search(title, cmd_string)
      end
      puts cmd_string
      exit run(Shellwords.shellsplit(cmd_string))
    end
  end
end
