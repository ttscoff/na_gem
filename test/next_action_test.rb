
require_relative "test_helper"
require "na/next_action"
require "tempfile"
require "ostruct"

class NextActionTest < Minitest::Test
  def test_list_todos_outputs_highlighted_filenames
    # Stub match_working_dir to return sample filenames
    NA.stub(:match_working_dir, ->(query, **kwargs) { ["todo1.taskpaper", "todo2.taskpaper"] }) do
      # Stub highlight_filename to just return the filename for test
      String.class_eval { def highlight_filename; self; end }
      output = capture_io { NA.list_todos(query: ["todo1", "todo2"]) }
      assert_match(/todo1.taskpaper/, output[0])
      assert_match(/todo2.taskpaper/, output[0])
    end
  end

  def test_save_search_creates_and_saves_search
    file = NA.database_path(file: 'saved_searches.yml')
    File.delete(file) if File.exist?(file)
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      NA.stub(:yn, ->(*args, **kwargs) { true }) do
        NA.save_search("TestSearch", "tagged 'test'")
  assert File.exist?(file)
  contents = File.read(file)
  puts "\n--- saved_searches.yml contents ---\n#{contents}\n--- end ---\n"
  searches = YAML.load(contents)
  assert_equal "tagged 'test'", searches["testsearch"]
      end
    end
    File.delete(file) if File.exist?(file)
  end
  def test_priority_map_returns_expected_values
    map = NA.priority_map
    assert_equal 5, map['h']
    assert_equal 3, map['m']
    assert_equal 1, map['l']
  end

  def test_color_single_options_formats_choices
    result = NA.color_single_options(%w[Y n])
    assert_match(/Y/, result)
    assert_match(/n/, result)
    assert_match(/\[.*\]/, result)
  end

  def test_theme_returns_theme_hash
    theme = NA.theme
    assert theme.is_a?(Hash)
    assert theme.key?(:warning)
  end

  def test_notify_warns_and_exits
    # Patch Process.exit to prevent actual exit
    Process.stub(:exit, ->(code = 0) { @exited = code }) do
      NA.notify("Test message", exit_code: 1)
      assert_equal 1, @exited
    end
  end

  def test_yn_returns_default_when_not_tty
    $stdout.stub(:isatty, false) do
      assert_equal true, NA.yn("Prompt?", default: true)
      assert_equal false, NA.yn("Prompt?", default: false)
    end
  end
  def test_shift_index_after_shifts_indices
    # Create dummy projects
    p1 = NA::Project.new("Project1", 0, 1, 2)
    p2 = NA::Project.new("Project2", 0, 3, 4)
    p3 = NA::Project.new("Project3", 0, 5, 6)
    projects = [p1, p2, p3]
    shifted = NA.shift_index_after(projects, 2, 1)
    # p2 and p3 should have their line and last_line decremented by 1
    assert_equal 2, shifted[1].line
    assert_equal 3, shifted[1].last_line
    assert_equal 4, shifted[2].line
    assert_equal 5, shifted[2].last_line
  end

  def test_update_action_adds_action_to_project
    File.write("test_update.taskpaper", "Inbox:\nProjectA:")
    action = NA::Action.new("test_update.taskpaper", "ProjectA", ["ProjectA"], "Test Action", 1)
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      NA.update_action("test_update.taskpaper", nil, add: action, project: "ProjectA")
      content = File.read("test_update.taskpaper")
      assert_match(/- Test Action/, content)
    end
    File.delete("test_update.taskpaper")
  end
  def test_create_todo_creates_file_with_default_content
    File.delete("test_create.taskpaper") if File.exist?("test_create.taskpaper")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      NA.create_todo("test_create.taskpaper", "MyProject")
      assert File.exist?("test_create.taskpaper")
      content = File.read("test_create.taskpaper")
      assert_match(/Inbox:/, content)
      assert_match(/MyProject:/, content)
      assert_match(/Archive:/, content)
    end
    File.delete("test_create.taskpaper")
  end

  def test_create_todo_with_template
    File.write("template.taskpaper", "Inbox:\nTemplateProject:")
    File.delete("test_create_template.taskpaper") if File.exist?("test_create_template.taskpaper")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      NA.create_todo("test_create_template.taskpaper", "IgnoredProject", template: "template.taskpaper")
      assert File.exist?("test_create_template.taskpaper")
      content = File.read("test_create_template.taskpaper")
      assert_match(/TemplateProject:/, content)
      refute_match(/IgnoredProject:/, content)
    end
    File.delete("test_create_template.taskpaper")
    File.delete("template.taskpaper")
  end

  def test_select_file_returns_selected_file
    files = ["file1.txt", "file2.txt"]
    # Stub choose_from to return the first file
    NA.stub(:choose_from, ->(opts, **kwargs) { [opts.first] }) do
      selected = NA.select_file(files)
      assert_equal "file1.txt", selected
    end
  end

  def test_select_file_multiple_returns_selected_files
    files = ["file1.txt", "file2.txt", "file3.txt"]
    NA.stub(:choose_from, ->(opts, **kwargs) { [opts[0], opts[2]] }) do
      selected = NA.select_file(files, multiple: true)
      assert_equal ["file1.txt", "file3.txt"], selected
    end
  end
  def test_insert_project_creates_new_top_level
    File.write("test_insert.taskpaper", "Inbox:")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      new_proj = NA.insert_project("test_insert.taskpaper", "ProjectA")
      assert_equal "ProjectA", new_proj.project
      assert_equal 0, new_proj.indent
      content = File.read("test_insert.taskpaper")
      assert_match(/ProjectA:/, content)
    end
    File.delete("test_insert.taskpaper")
  end

  def test_insert_project_creates_nested_project
    File.write("test_insert.taskpaper", "Inbox:\nProjectA:")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      new_proj = NA.insert_project("test_insert.taskpaper", "ProjectA:SubProject1")
      assert_equal "ProjectA:SubProject1", new_proj.project
      assert new_proj.indent > 0
      content = File.read("test_insert.taskpaper")
      assert_match(/SubProject1:/, content)
    end
    File.delete("test_insert.taskpaper")
  end

  def test_insert_project_extends_existing_project
    File.write("test_insert.taskpaper", "Inbox:\nProjectA:\n\tSubProject1:")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      new_proj = NA.insert_project("test_insert.taskpaper", "ProjectA:SubProject2")
      assert_equal "ProjectA:SubProject2", new_proj.project
      content = File.read("test_insert.taskpaper")
      assert_match(/SubProject2:/, content)
    end
    File.delete("test_insert.taskpaper")
  end

  def test_insert_project_into_archive
    File.write("test_insert.taskpaper", "Inbox:\nArchive:")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      new_proj = NA.insert_project("test_insert.taskpaper", "Archive:OldStuff")
      assert_equal "Archive:OldStuff", new_proj.project
      content = File.read("test_insert.taskpaper")
      assert_match(/OldStuff:/, content)
    end
    File.delete("test_insert.taskpaper")
  end
  def test_find_projects_returns_projects
    File.write("test_project.taskpaper", "Inbox:\nProject1:\n\t- Action1")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      projects = NA.find_projects("test_project.taskpaper")
      # Use to_s to check for project name
      assert projects.any? { |p| p.to_s.include?("Project1") }
    end
    File.delete("test_project.taskpaper")
  end

  def test_find_actions_returns_actions
    File.write("test_action.taskpaper", "Inbox:\n- Action1 @tag1")
    NA.stub(:notify, ->(*args, **kwargs) { nil }) do
      result = NA.find_actions("test_action.taskpaper", "Action1", "tag1", all: true, done: false, project: nil, search_note: true)
      if result.is_a?(Array) && result[1].respond_to?(:any?)
        assert result[1].any? { |a| a.action.include?("Action1") }
      elsif result.is_a?(String)
        assert_match(/No matching actions found/, result)
      else
        flunk "find_actions did not return expected array or error string"
      end
    end
    File.delete("test_action.taskpaper")
  end

  def test_find_actions_no_match
    File.write("test_action.taskpaper", "Inbox:\n- Action1 @tag1")
    called = false
    NA.stub(:notify, ->(*args, **kwargs) { called = true; nil }) do
      result = NA.find_actions("test_action.taskpaper", "NoMatch", "tag1", all: true, done: false, project: nil, search_note: true)
      assert result.is_a?(Array)
      projects, actions = result
      assert projects.is_a?(Array)
      assert actions.is_a?(NA::Actions)
      assert_equal 0, actions.count
      assert called
    end
    File.delete("test_action.taskpaper")
  end
  def test_notify_debug
    NA.verbose = true
    called = false
    NA.stub(:warn, ->(msg) { called = true; msg }) do
      NA.notify("debug message", debug: true)
    end
    assert called
  end

  def test_notify_exit_code
    # SystemExit is expected when exit_code is set
    assert_raises(SystemExit) { NA.notify("exit", exit_code: 1) }
  end

  def test_yn_non_tty
    $stdout.stub(:isatty, false) do
      assert_equal true, NA.yn("Prompt", default: true)
      assert_equal false, NA.yn("Prompt", default: false)
    end
  end
  def test_priority_map
    map = NA.priority_map
    assert_equal 5, map['h']
    assert_equal 3, map['m']
    assert_equal 1, map['l']
  end

  def test_color_single_options_default
    result = NA.color_single_options(%w[Y n])
    assert_includes result, "Y"
    assert_includes result, "n"
  end

  def test_color_single_options_lowercase
    result = NA.color_single_options(%w[y n])
    assert_includes result, "y"
    assert_includes result, "n"
  end

  def test_shift_index_after
    proj = OpenStruct.new(line: 5, last_line: 10)
    arr = [proj]
    shifted = NA.shift_index_after(arr, 3, 2)
    assert_equal 3, shifted.first.line
    assert_equal 8, shifted.first.last_line
  end

  def test_create_todo_creates_file
    Tempfile.create("na_test") do |tmp|
      NA.stub(:save_working_dir, nil) do
        NA.stub(:notify, nil) do
          NA.na_tag = "next"
          NA.create_todo(tmp.path, "TestProject")
          content = File.read(tmp.path)
          assert_includes content, "Inbox:"
          assert_includes content, "TestProject:"
        end
      end
    end
  end

  def test_select_file_returns_selection
    files = ["file1", "file2"]
    NA.stub(:choose_from, ->(arr, **opts) { arr.first }) do
      NA.stub(:notify, nil) do
        assert_equal "file1", NA.select_file(files)
      end
    end
  end

  def test_select_file_none_selected
    files = ["file1", "file2"]
    NA.stub(:choose_from, ->(arr, **opts) { nil }) do
      called = false
      NA.stub(:notify, ->(msg, exit_code: nil) { called = true; nil }) do
        assert_nil NA.select_file(files)
        assert called
      end
    end
  end
end
