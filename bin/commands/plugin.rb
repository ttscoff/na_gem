# frozen_string_literal: true

class App
  extend GLI::App

  desc 'Manage and run plugins'
  command %i[plugin] do |c|
    c.desc 'Create a new plugin'
    c.arg_name 'NAME'
    c.command %i[new n] do |cc|
      cc.desc 'Language/ext (e.g. rb, py, /usr/bin/env bash)'
      cc.arg_name 'LANG'
      cc.flag %i[language lang]
      cc.action do |_g, opts, args|
        NA::Plugins.ensure_plugins_home
        name = args.first
        NA.notify("#{NA.theme[:error]}Plugin name required", exit_code: 1) unless name
        file = NA::Plugins.create_plugin(name, language: opts[:language])
        NA.notify("#{NA.theme[:success]}Created #{NA.theme[:filename]}#{file}")
        NA.os_open(file)
      end
    end

    c.desc 'Edit an existing plugin'
    c.arg_name 'NAME'
    c.command %i[edit] do |cc|
      cc.action do |_g, _o, args|
        NA::Plugins.ensure_plugins_home
        target = args.first
        unless target
          all = NA::Plugins.list_plugins.merge(NA::Plugins.list_plugins_disabled)
          names = all.values.map { |p| File.basename(p) }
          chosen = NA.choose_from(names, prompt: 'Select plugin to edit', multiple: false)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless chosen
          target = chosen
        end
        path = NA::Plugins.resolve_plugin(target) || File.join(NA::Plugins.plugins_home, target)
        NA.notify("#{NA.theme[:error]}Plugin not found: #{target}", exit_code: 1) unless File.exist?(path)
        NA.os_open(path)
      end
    end

    c.desc 'Run a plugin on selected actions'
    c.arg_name 'NAME'
    c.command %i[run x] do |cc|
      cc.desc 'Input format (json|yaml|csv|text)'
      cc.arg_name 'TYPE'
      cc.flag %i[input]

      cc.desc 'Output format (json|yaml|csv|text)'
      cc.arg_name 'TYPE'
      cc.flag %i[output]

      cc.desc 'Text divider when using --input/--output text'
      cc.arg_name 'STRING'
      cc.flag %i[divider]

      cc.desc 'Specify the file to search for the task'
      cc.arg_name 'PATH'
      cc.flag %i[file in]

      cc.desc 'Search for files X directories deep'
      cc.arg_name 'DEPTH'
      cc.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

      cc.desc 'Filter results using search terms'
      cc.arg_name 'QUERY'
      cc.flag %i[search find grep], multiple: true

      cc.desc 'Include @done actions'
      cc.switch %i[done]

      cc.desc 'Match actions containing tag. Allows value comparisons'
      cc.arg_name 'TAG'
      cc.flag %i[tagged], multiple: true

      cc.action do |_global, options, args|
        NA::Plugins.ensure_plugins_home
        plugin_name = args.first
        unless plugin_name
          names = NA::Plugins.list_plugins.values.map { |p| File.basename(p) }
          plugin_name = NA.choose_from(names, prompt: 'Select plugin to run', multiple: false)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless plugin_name
        end
        path = NA::Plugins.resolve_plugin(plugin_name)
        NA.notify("#{NA.theme[:error]}Plugin not found: #{plugin_name}", exit_code: 1) unless path

        meta = NA::Plugins.parse_plugin_metadata(path)
        input_fmt = (options[:input] || meta['input'] || 'json').to_s
        output_fmt = (options[:output] || meta['output'] || input_fmt).to_s
        divider = (options[:divider] || '||')

        # Normalize empty arrays to nil for proper "no filter" detection
        search_filter = (options[:search] && !options[:search].empty?) ? options[:search] : nil
        tagged_filter = (options[:tagged] && !options[:tagged].empty?) ? options[:tagged] : nil
        file_filter = options[:file]

        # If no filters provided, show menu immediately
        if !file_filter && !search_filter && !tagged_filter
          files = NA.find_files(depth: options[:depth] || 1)
          options_list = []
          selection = []
          files.each do |f|
            todo = NA::Todo.new(file_path: f, done: options[:done], require_na: false)
            todo.actions.each do |a|
              options_list << "#{File.basename(a.file_path)}:#{a.file_line}:#{a.parent.join('>')} | #{a.action}"
              selection << a
            end
          end
          NA.notify("#{NA.theme[:error]}No actions found", exit_code: 1) if options_list.empty?
          chosen = NA.choose_from(options_list, prompt: 'Select actions to run plugin on', multiple: true)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless chosen && !chosen.empty?
          idxs = Array(chosen).map { |label| options_list.index(label) }.compact
          actions = idxs.map { |i| selection[i] }
        else
          # Use filters to find actions
          actions = NA.select_actions(
            file: file_filter,
            depth: options[:depth],
            search: search_filter,
            tagged: tagged_filter,
            include_done: options[:done]
          )
          NA.notify("#{NA.theme[:error]}No matching actions found", exit_code: 1) if actions.empty?
        end

        io_actions = actions.map(&:to_plugin_io_hash)
        stdin_str = NA::Plugins.serialize_actions(io_actions, format: input_fmt, divider: divider)
        stdout = NA::Plugins.run_plugin(path, stdin_str)
        returned = NA::Plugins.parse_actions(stdout, format: output_fmt, divider: divider)
        Array(returned).each { |h| NA.apply_plugin_result(h) }
      end
    end

    c.desc 'Enable a disabled plugin'
    c.arg_name 'NAME'
    c.command %i[enable e] do |cc|
      cc.action do |_g, _o, args|
        NA::Plugins.ensure_plugins_home
        name = args.first
        unless name
          names = NA::Plugins.list_plugins_disabled.values.map { |p| File.basename(p) }
          name = NA.choose_from(names, prompt: 'Enable which plugin?', multiple: false)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless name
        end
        path = NA::Plugins.enable_plugin(name)
        NA.notify("#{NA.theme[:success]}Enabled #{NA.theme[:filename]}#{File.basename(path)}")
      end
    end

    c.desc 'Disable an enabled plugin'
    c.arg_name 'NAME'
    c.command %i[disable d] do |cc|
      cc.action do |_g, _o, args|
        NA::Plugins.ensure_plugins_home
        name = args.first
        unless name
          names = NA::Plugins.list_plugins.values.map { |p| File.basename(p) }
          name = NA.choose_from(names, prompt: 'Disable which plugin?', multiple: false)
          NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless name
        end
        path = NA::Plugins.disable_plugin(name)
        NA.notify("#{NA.theme[:warning]}Disabled #{NA.theme[:filename]}#{File.basename(path)}")
      end
    end
  end
end


