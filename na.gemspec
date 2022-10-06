# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','na','version.rb'])
spec = Gem::Specification.new do |s|
  s.name = 'na'
  s.version = Na::VERSION
  s.author = 'Brett Terpstra'
  s.email = 'me@brettterpstra.com'
  s.homepage = 'https://brettterpstra.com/projects/na/'
  s.platform = Gem::Platform::RUBY
  s.summary = 'A command line tool for adding and listing project todos'
  s.description = [
    'A tool for managing a TaskPaper file of project todos for the current directory.',
    'Easily create "next actions" to come back to, add tags and priorities, and notes.',
    'Add prompt hooks to display your next actions automatically when cd\'ing into a directory.'
  ].join(' ')
  s.license = 'MIT'
  s.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.strip =~ %r{^((test|spec|features)/|\.git|buildnotes|.*\.taskpaper)} }
  end
  s.require_paths << 'lib'
  s.extra_rdoc_files = ['README.md','na.rdoc']
  s.rdoc_options << '--title' << 'na' << '--main' << 'README.md' << '--markup' << 'markdown'
  s.bindir = 'bin'
  s.executables << 'na'
  s.add_development_dependency('rake','~> 0.9.2')
  s.add_development_dependency('rdoc', '~> 4.3')
  s.add_development_dependency('minitest', '~> 5.14')
  s.add_development_dependency('yard', '~> 0.9', '>= 0.9.26')
  s.add_runtime_dependency('gli','~> 2.21.0')
  s.add_runtime_dependency('tty-reader', '~> 0.9', '>= 0.9.0')
  s.add_runtime_dependency('tty-screen', '~> 0.8', '>= 0.8.1')
  s.add_runtime_dependency('tty-which', '~> 0.5', '>= 0.5.0')
  s.add_runtime_dependency('chronic', '~> 0.10', '>= 0.10.2')
end
