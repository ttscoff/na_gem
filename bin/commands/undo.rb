# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Undo the last change'
  long_desc 'Run without argument to undo most recent change'
  arg_name 'FILE', optional: true, multiple: true
  command %i[undo] do |c|
    c.desc 'Select from available undo files'
    c.switch %i[s select choose]

    c.example 'na undo', desc: 'Undo the last change'
    c.example 'na undo myproject', desc: 'Undo the last change to a file matching "myproject"'

    c.action do |_global_options, options, args|
      if options[:select]
        options = IO.read(NA.database_path(file: 'last_modified.txt')).strip.split(/\n/)
        res = NA.choose_from(options, sorted: false)
        NA.notify("#{NA.theme[:error]}Cancelled", exit_code: 1) unless res

        NA.restore_modified_file(res)
      elsif args.empty?
        NA.restore_last_modified_file
      else
        args.each do |arg|
          NA.restore_last_modified_file(search: arg)
        end
      end
    end
  end
end
