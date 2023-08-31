# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Display the changelog'
  command %i[changes changelog] do |c|
    c.action do |_, _, _|
      changelog = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'CHANGELOG.md'))
      pagers = [
        'mdless',
        'mdcat',
        'bat',
        ENV['PAGER'],
        'less -FXr',
        ENV['GIT_PAGER'],
        'more -r'
      ]
      pager = pagers.find { |cmd| TTY::Which.exist?(cmd.split.first) }
      system %(#{pager} "#{changelog}")
    end
  end
end
