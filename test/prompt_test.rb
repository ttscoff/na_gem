require_relative "test_helper"
require "na/prompt"

class PromptTest < Minitest::Test
  def setup
    @orig_global_file = NA.global_file
    @orig_cwd_is = NA.cwd_is
    @orig_extension = NA.extension
    NA.extension = "taskpaper"
    @theme = { error: "[ERROR]", warning: "[WARN]", filename: "[FILE]", success: "[SUCCESS]" }
    NA.stub(:theme, @theme) do; end
  end

  def teardown
    NA.global_file = @orig_global_file
    NA.cwd_is = @orig_cwd_is
    NA.extension = @orig_extension
  end

  def test_prompt_hook_zsh_project
  NA.global_file = true
  NA.cwd_is = :project
    result = NA::Prompt.prompt_hook(:zsh)
    assert_includes result, 'na next --proj $(basename "$PWD")'
  end

  def test_prompt_hook_zsh_tag
  NA.global_file = true
  NA.cwd_is = :tag
    result = NA::Prompt.prompt_hook(:zsh)
    assert_includes result, 'na tagged $(basename "$PWD")'
  end

  def test_prompt_hook_zsh_default
  NA.global_file = false
    result = NA::Prompt.prompt_hook(:zsh)
    assert_includes result, 'na next'
  end

  def test_prompt_hook_zsh_error
  NA.global_file = true
  NA.cwd_is = :other
    called = false
    NA.stub(:notify, ->(msg, exit_code: nil) { called = true; msg }) do
      NA::Prompt.prompt_hook(:zsh)
    end
    assert called
  end

  def test_prompt_hook_fish_project
  NA.global_file = true
  NA.cwd_is = :project
    result = NA::Prompt.prompt_hook(:fish)
    assert_includes result, 'na next --proj (basename "$PWD")'
  end

  def test_prompt_hook_fish_tag
  NA.global_file = true
  NA.cwd_is = :tag
    result = NA::Prompt.prompt_hook(:fish)
    assert_includes result, 'na tagged (basename "$PWD")'
  end

  def test_prompt_hook_fish_default
  NA.global_file = false
    result = NA::Prompt.prompt_hook(:fish)
    assert_includes result, 'na next'
  end

  def test_prompt_hook_fish_error
  NA.global_file = true
  NA.cwd_is = :other
    called = false
    NA.stub(:notify, ->(msg, exit_code: nil) { called = true; msg }) do
      NA::Prompt.prompt_hook(:fish)
    end
    assert called
  end

  def test_prompt_hook_bash_project
  NA.global_file = true
  NA.cwd_is = :project
    result = NA::Prompt.prompt_hook(:bash)
    assert_includes result, 'na next --proj $(basename "$PWD")'
  end

  def test_prompt_hook_bash_tag
  NA.global_file = true
  NA.cwd_is = :tag
    result = NA::Prompt.prompt_hook(:bash)
    assert_includes result, 'na tagged $(basename "$PWD")'
  end

  def test_prompt_hook_bash_default
  NA.global_file = false
    result = NA::Prompt.prompt_hook(:bash)
    assert_includes result, 'na next'
  end

  def test_prompt_hook_bash_error
  NA.global_file = true
  NA.cwd_is = :other
    called = false
    NA.stub(:notify, ->(msg, exit_code: nil) { called = true; msg }) do
      NA::Prompt.prompt_hook(:bash)
    end
    assert called
  end

  def test_prompt_file
    assert_equal '~/.zshrc', NA::Prompt.prompt_file(:zsh)
    assert_equal '~/.config/fish/conf.d/na.fish', NA::Prompt.prompt_file(:fish)
    assert_equal '~/.bash_profile', NA::Prompt.prompt_file(:bash)
  end

  def test_show_prompt_hook
    called = false
    NA.stub(:notify, ->(msg) { called = true; msg }) do
      NA::Prompt.show_prompt_hook(:zsh)
    end
    assert called
  end

  def test_install_prompt_hook
    file = File.expand_path('~/.zshrc')
    mock_file = Object.new
    def mock_file.puts(*args); end
    File.stub(:open, ->(f, mode, &block) { assert_equal file, f; block&.call(mock_file) if block }) do
      called = false
      NA.stub(:notify, ->(msg) { called = true; msg }) do
        NA::Prompt.install_prompt_hook(:zsh)
      end
      assert called
    end
  end
end
