# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Execute a saved search'
  long_desc 'Run without argument to list saved searches'
  arg_name 'SEARCH_TITLE', optional: true, multiple: true
  command %i[saved] do |c|
    c.example 'na tagged "+maybe,+priority<=3" --save maybelater', desc: 'save a search called "maybelater"'
    c.example 'na saved maybelater', desc: 'perform the search named "maybelater"'
    c.example 'na saved maybe',
              desc: 'perform the search named "maybelater", assuming no other searches match "maybe"'
    c.example 'na maybe',
              desc: 'na run with no command and a single argument automatically performs a matching saved search'
    c.example 'na saved', desc: 'list available searches'

    c.desc 'Open the saved search file in $EDITOR'
    c.switch %i[e edit], negatable: false

    c.desc 'Delete the specified search definition'
    c.switch %i[d delete], negatable: false

    c.desc 'Interactively select a saved search to run'
    c.switch %i[s select], negatable: false

    c.action do |_global_options, options, args|
      NA.edit_searches if options[:edit]

      if args.empty? && !options[:select]
        yaml_searches = NA.load_searches
        taskpaper_searches = NA.load_taskpaper_searches(depth: 1)
        NA.notify("#{NA.theme[:success]}Saved searches stored in #{NA.database_path(file: 'saved_searches.yml').highlight_filename}")
        lines = yaml_searches.map do |k, v|
          "#{NA.theme[:filename]}#{k}: #{NA.theme[:values]}#{v}"
        end
        unless taskpaper_searches.empty?
          lines << "#{NA.theme[:prompt]}TaskPaper saved searches:"
          lines.concat(
            taskpaper_searches.map do |k, v|
              "#{NA.theme[:filename]}#{k}: #{NA.theme[:values]}#{v[:expr]} #{NA.theme[:note]}(#{File.basename(v[:file])})"
            end
          )
        end
        NA.notify(lines.join("\n"))
      else
        NA.delete_search(args.join(',').split(/[ ,]/)) if options[:delete]

        if options[:select]
          yaml_searches = NA.load_searches
          taskpaper_searches = NA.load_taskpaper_searches(depth: 1)
          combined = {}
          yaml_searches.each { |k, v| combined[k] = { source: :yaml, value: v } }
          taskpaper_searches.each { |k, v| combined[k] ||= { source: :taskpaper, value: v } }

          res = NA.choose_from(
            combined.map do |k, info|
              val = info[:source] == :yaml ? info[:value] : info[:value][:expr]
              "#{NA.theme[:filename]}#{k} #{NA.theme[:value]}(#{val})"
            end,
            multiple: true
          )
          NA.notify("#{NA.theme[:error]}Nothing selected", exit_code: 0) if res&.empty?
          args = res.map { |r| r.match(/(\S+)(?= \()/)[1] }
        end

        args.each do |arg|
          yaml_searches = NA.load_searches
          taskpaper_searches = NA.load_taskpaper_searches(depth: 1)
          all_keys = (yaml_searches.keys + taskpaper_searches.keys).uniq

          keys = all_keys.delete_if { |k| k !~ /#{arg.wildcard_to_rx}/ }
          NA.notify("#{NA.theme[:error]}Search #{arg} not found", exit_code: 1) if keys.empty?

          keys.each do |key|
            NA.notify("#{NA.theme[:prompt]}Saved search #{NA.theme[:filename]}#{key}#{NA.theme[:warning]}:")
            if yaml_searches.key?(key)
              value = yaml_searches[key]
              if value.to_s.strip =~ /\A@search\(.+\)\s*\z/
                NA.run_taskpaper_search(value)
              else
                cmd = Shellwords.shellsplit(value)
                run(cmd)
              end
            elsif taskpaper_searches.key?(key)
              info = taskpaper_searches[key]
              NA.run_taskpaper_search(info[:expr], file: info[:file])
            end
          end
        end
      end
    end
  end
end
