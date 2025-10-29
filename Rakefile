require 'rake/clean'
require 'rubygems'
require 'rubygems/package_task'
require 'rdoc/task'
require 'bump/tasks'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'
require 'tty-spinner'
require 'English'

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/na/*.rb']
  t.options = ['--markup-provider=redcarpet', '--markup=markdown', '--no-private', '-p', 'yard_templates']
  t.stats_options = ['--list-undoc'] # Uncommented this line for stats options
end

## Docker error class
class DockerError < StandardError
  def initialize(msg = nil)
    msg = msg ? "Docker error: #{msg}" : 'Docker error'
    super
  end
end

task default: %i[test yard]

desc 'Run test suite'
task test: %i[rubocop spec]

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = '--format documentation'
end

RuboCop::RakeTask.new do |t|
  t.formatters = ['progress']
end

task :doc, [*Rake.application[:yard].arg_names] => [:yard]

Rake::RDocTask.new do |rd|
  rd.main = 'README.rdoc'
  rd.rdoc_files.include('README.rdoc', 'lib/**/*.rb', 'bin/**/*')
  rd.title = 'na'
end

spec = eval(File.read('na.gemspec'))

Gem::PackageTask.new(spec) do |pkg|
end
require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb', 'bin/commands/*.rb', 'bin/na']
end

desc 'Install current gem in all versions of asdf-controlled ruby'
task :install do
  Rake::Task['clobber'].invoke
  Rake::Task['package'].invoke
  Dir.chdir 'pkg'
  file = Dir.glob('*.gem').last

  current_ruby = `asdf current ruby`.match(/(\d.\d+.\d+)/)[1]

  `asdf list ruby`.split.map { |ruby| ruby.strip.sub(/^*/, '') }.each do |ruby|
    `asdf shell ruby #{ruby}`
    puts `gem install #{file}`
  end

  `asdf shell ruby #{current_ruby}`
end

desc 'Development version check'
task :ver do
  gver = `git ver`
  cver = IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
  res = `grep VERSION lib/na/version.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  puts "git tag: #{gver}"
  puts "version.rb: #{version}"
  puts "changelog: #{cver}"
end

desc 'Changelog version check'
task :cver do
  puts IO.read(File.join(File.dirname(__FILE__), 'CHANGELOG.md')).match(/^#+ (\d+\.\d+\.\d+(\w+)?)/)[1]
end

desc 'Bump incremental version number'
task :bump, :type do |_, args|
  args.with_defaults(type: 'inc')
  version_file = 'lib/na/version.rb'
  content = IO.read(version_file)
  content.sub!(/VERSION = '(?<major>\d+)\.(?<minor>\d+)\.(?<inc>\d+)(?<pre>\S+)?'/) do
    m = Regexp.last_match
    major = m['major'].to_i
    minor = m['minor'].to_i
    inc = m['inc'].to_i
    pre = m['pre']

    case args[:type]
    when /^maj/
      major += 1
      minor = 0
      inc = 0
    when /^min/
      minor += 1
      inc = 0
    else
      inc += 1
    end

    $stdout.puts "At version #{major}.#{minor}.#{inc}#{pre}"
    "VERSION = '#{major}.#{minor}.#{inc}#{pre}'"
  end
  File.open(version_file, 'w+') { |f| f.puts content }
end

# task default: %i[test clobber package]

desc 'Remove packages'
task :clobber_packages do
  FileUtils.rm_f 'pkg/*'
end
# Make a prerequisite of the preexisting clobber task
desc 'Clobber files'
task clobber: :clobber_packages

desc 'Get Script Version'
task :sver do
  res = `grep VERSION lib/na/version.rb`
  version = res.match(/VERSION *= *['"](\d+\.\d+\.\d+(\w+)?)/)[1]
  print version
end

desc 'Run tests in Docker'
task :dockertest, :version, :login, :attempt do |_, args|
  args.with_defaults(version: 'all', login: false, attempt: 1)
  `open -a Docker`

  Rake::Task['clobber'].reenable
  Rake::Task['clobber'].invoke
  Rake::Task['build'].reenable
  Rake::Task['build'].invoke

  case args[:version]
  when /^a/
    %w[6 7 3].each do |v|
      Rake::Task['dockertest'].reenable
      Rake::Task['dockertest'].invoke(v, false)
    end
    Process.exit 0
  when /^3\.?3/
    img = 'natest33'
    file = 'docker/Dockerfile-3.3'
  when /^3/
    version = '3.0'
    img = 'natest3'
    file = 'docker/Dockerfile-3.0'
  when /6$/
    version = '2.6'
    img = 'natest26'
    file = 'docker/Dockerfile-2.6'
  when /(^2|7$)/
    version = '2.7'
    img = 'natest27'
    file = 'docker/Dockerfile-2.7'
  else
    version = '3.0.1'
    img = 'natest'
    file = 'docker/Dockerfile'
  end

  puts `docker build . --file #{file} -t #{img}`

  raise DockerError, 'Error building docker image' unless $CHILD_STATUS.success?

  dirs = {
    File.dirname(__FILE__) => '/na',
    File.expand_path('~/.config') => '/root/.config'
  }
  dir_args = dirs.map { |s, d| " -v '#{s}:#{d}'" }.join(' ')
  exec "docker run #{dir_args} -it #{img} /bin/bash -l" if args[:login]

  spinner = TTY::Spinner.new("[:spinner] Running tests (#{version})...", hide_cursor: true)

  spinner.auto_spin
  `docker run --rm #{dir_args} -it #{img}`
  # raise DockerError.new("Error running docker image") unless $CHILD_STATUS.success?

  # commit = puts `bash -c "docker commit $(docker ps -a|grep #{img}|awk '{print $1}'|head -n 1) #{img}"`.strip
  $CHILD_STATUS.success? ? spinner.success : spinner.error
  spinner.stop

  # puts res
  # puts commit&.empty? ? "Error commiting Docker tag #{img}" : "Committed Docker tag #{img}"
rescue DockerError
  raise StandardError.new('Docker not responding') if args[:attempt] > 3

  `open -a Docker`
  sleep 3
  Rake::Task['dockertest'].reenable
  Rake::Task['dockertest'].invoke(args[:version], args[:login], args[:attempt] + 1)
end

desc 'alias for build'
task package: :build

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:test].invoke
end
