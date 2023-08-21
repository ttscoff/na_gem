# frozen_string_literal: true

desc 'Execute a saved search'
long_desc 'Run without argument to list saved searches'
arg_name 'SEARCH_TITLE', optional: true
command %i[saved] do |c|
  c.example 'na tagged "+maybe,+priority<=3" --save maybelater', description: 'save a search called "maybelater"'
  c.example 'na saved maybelater', description: 'perform the search named "maybelater"'
  c.example 'na saved maybe',
            description: 'perform the search named "maybelater", assuming no other searches match "maybe"'
  c.example 'na maybe',
            description: 'na run with no command and a single argument automatically performs a matching saved search'
  c.example 'na saved', description: 'list available searches'

  c.desc 'Open the saved search file in $EDITOR'
  c.switch %i[e edit], negatable: false

  c.desc 'Delete the specified search definition'
  c.switch %i[d delete], negatable: false

  c.action do |_global_options, options, args|
    NA.edit_searches if options[:edit]

    searches = NA.load_searches
    if args.empty?
      NA.notify("{bg}Saved searches stored in {bw}#{NA.database_path(file: 'saved_searches.yml')}")
      NA.notify(searches.map { |k, v| "{y}#{k}: {w}#{v}" }.join("\n"), exit_code: 0)
    else
      NA.delete_search(args) if options[:delete]

      keys = searches.keys.delete_if { |k| k !~ /#{args[0]}/ }
      NA.notify("{r}Search #{args[0]} not found", exit_code: 1) if keys.empty?

      key = keys[0]
      cmd = Shellwords.shellsplit(searches[key])
      exit run(cmd)
    end
  end
end
