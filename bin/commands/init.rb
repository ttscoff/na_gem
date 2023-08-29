# frozen_string_literal: true

desc 'Create a new todo file in the current directory'
arg_name 'PROJECT', optional: true
command %i[init create] do |c|
  c.example 'na init', desc: 'Generate a new todo file, prompting for project name'
  c.example 'na init warpspeed', desc: 'Generate a new todo for a project called warpspeed'

  c.action do |global_options, _options, args|
    reader = TTY::Reader.new
    if args.count.positive?
      project = args.join(' ')
    elsif
      project = File.expand_path('.').split('/').last
      project = reader.read_line(NA::Color.template('{y}Project name {bw}> {x}'), value: project).strip if $stdin.isatty
    end

    target = "#{project}.#{NA.extension}"

    if File.exist?(target)
      res = NA.yn(NA::Color.template("{r}File {bw}#{target}{r} already exists, overwrite it"), default: false)
      Process.exit 1 unless res

    end

    NA.create_todo(target, project, template: global_options[:template])
  end
end
