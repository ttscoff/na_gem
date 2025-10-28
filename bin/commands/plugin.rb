# frozen_string_literal: true

class App
  extend GLI::App

  desc 'Run a plugin on selected actions'
  arg_name 'NAME'
  command %i[plugin] do |c|
    c.desc 'Input format (json|yaml|text)'
    c.arg_name 'TYPE'
    c.flag %i[input]

    c.desc 'Output format (json|yaml|text)'
    c.arg_name 'TYPE'
    c.flag %i[output]

    c.desc 'Text divider when using --input/--output text'
    c.arg_name 'STRING'
    c.flag %i[divider]

    c.desc 'Specify the file to search for the task'
    c.arg_name 'PATH'
    c.flag %i[file in]

    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Filter results using search terms'
    c.arg_name 'QUERY'
    c.flag %i[search find grep], multiple: true

    c.desc 'Include @done actions'
    c.switch %i[done]

    c.desc 'Match actions containing tag. Allows value comparisons'
    c.arg_name 'TAG'
    c.flag %i[tagged], multiple: true

    c.action do |_global, options, args|
      plugin_name = args.first
      NA.notify("#{NA.theme[:error]}Plugin name required", exit_code: 1) unless plugin_name

      NA::Plugins.ensure_plugins_home
      path = NA::Plugins.resolve_plugin(plugin_name)
      NA.notify("#{NA.theme[:error]}Plugin not found: #{plugin_name}", exit_code: 1) unless path

      meta = NA::Plugins.parse_plugin_metadata(path)
      input_fmt = (options[:input] || meta['input'] || 'json').to_s
      output_fmt = (options[:output] || meta['output'] || input_fmt).to_s
      divider = (options[:divider] || '||')

      # Build selection using the same plumbing as update/find
      actions = NA.select_actions(
        file: options[:file],
        depth: options[:depth],
        search: options[:search],
        tagged: options[:tagged],
        include_done: options[:done]
      )

      io_actions = actions.map(&:to_plugin_io_hash)
      stdin_str = NA::Plugins.serialize_actions(io_actions, format: input_fmt, divider: divider)
      stdout = NA::Plugins.run_plugin(path, stdin_str)
      returned = NA::Plugins.parse_actions(stdout, format: output_fmt, divider: divider)

      # Apply updates
      returned.each do |h|
        NA.apply_plugin_result(h)
      end
    end
  end
end


