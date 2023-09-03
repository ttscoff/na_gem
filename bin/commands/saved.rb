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

    c.action do |_global_options, options, args|
      NA.edit_searches if options[:edit]

      if args.empty?
        searches = NA.load_searches
        NA.notify("#{NA.theme[:success]}Saved searches stored in #{NA.database_path(file: 'saved_searches.yml').highlight_filename}")
        NA.notify(searches.map { |k, v| "#{NA.theme[:filename]}#{k}: #{NA.theme[:values]}#{v}" }.join("\n"))
      else
        NA.delete_search(args.join(',').split(/[ ,]/)) if options[:delete]

        args.each do |arg|
          searches = NA.load_searches

          keys = searches.keys.delete_if { |k| k !~ /#{arg}/ }
          NA.notify("#{NA.theme[:error]}Search #{arg} not found", exit_code: 1) if keys.empty?

          key = keys[0]
          cmd = Shellwords.shellsplit(searches[key])
          run(cmd)
        end
      end
    end
  end
end
