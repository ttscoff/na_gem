# frozen_string_literal: true

desc 'Open a todo file in the default editor'
long_desc 'Let the system choose the defualt, (e.g. TaskPaper), or specify a command line utility (e.g. vim).
           If more than one todo file is found, a menu is displayed.'
command %i[edit] do |c|
  c.example 'na edit', desc: 'Open the main todo file in the default editor'
  c.example 'na edit -d 3 -a vim', desc: 'Display a menu of all todo files three levels deep from the
             current directory, open selection in vim.'

  c.desc 'Recurse to depth'
  c.arg_name 'DEPTH'
  c.default_value 1
  c.flag %i[d depth], type: :integer, must_match: /^\d+$/

  c.desc 'Specify an editor CLI'
  c.arg_name 'EDITOR'
  c.flag %i[e editor]

  c.desc 'Specify a Mac app'
  c.arg_name 'EDITOR'
  c.flag %i[a app]

  c.action do |global_options, options, args|
    depth = if global_options[:recurse] && options[:depth].nil? && global_options[:depth] == 1
              3
            else
              options[:depth].nil? ? global_options[:depth].to_i : options[:depth].to_i
            end
    files = NA.find_files(depth: depth)
    files.delete_if { |f| f !~ /.*?(#{args.join('|')}).*?.#{NA.extension}/ } if args.count.positive?

    file = if files.count > 1
             NA.select_file(files)
           else
             files[0]
           end

    if options[:editor]
      system options[:editor], file
    else
      NA.edit_file(file: file, app: options[:app])
    end
  end
end
