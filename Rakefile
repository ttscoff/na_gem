require 'rake/clean'
require 'rubygems'
require 'rubygems/package_task'
require 'rdoc/task'
require 'yard'

YARD::Rake::YardocTask.new do |t|
 t.files = ['lib/na/*.rb']
 t.options = ['--markup-provider=redcarpet', '--markup=markdown', '--no-private', '-p', 'yard_templates']
 # t.stats_options = ['--list-undoc']
end

task :doc, [*Rake.application[:yard].arg_names] => [:yard]

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc","lib/**/*.rb","bin/**/*")
  rd.title = 'na'
end

spec = eval(File.read('na.gemspec'))

Gem::PackageTask.new(spec) do |pkg|
end
require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
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

task default: %i[test clobber package]
