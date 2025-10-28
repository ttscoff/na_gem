# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/na'

class PluginsTest < Minitest::Test
  def with_tmp_plugins
    Dir.mktmpdir do |dir|
      orig = NA::Plugins.method(:plugins_home)
      NA::Plugins.define_singleton_method(:plugins_home) { dir }
      begin
        yield dir
      ensure
        NA::Plugins.define_singleton_method(:plugins_home, &orig)
      end
    end
  end

  def test_metadata_parsing_from_comment_block
    with_tmp_plugins do |dir|
      path = File.join(dir, 'Meta.sh')
      File.write(path, <<~SH)
        #!/usr/bin/env bash
        # NAME: Test Meta
        # INPUT: YAML
        # Output: json
        echo
      SH
      meta = NA::Plugins.parse_plugin_metadata(path)
      assert_equal 'Test Meta', meta['name']
      assert_equal 'yaml', meta['input']
      assert_equal 'json', meta['output']
    end
  end

  def test_text_roundtrip_with_action_and_args
    action = {
      'action' => { 'action' => 'MOVE', 'arguments' => ['Work:Feature'] },
      'file_path' => '/t/todo.taskpaper',
      'line' => 5,
      'parents' => %w[Work Backlog],
      'text' => '- Example',
      'note' => 'Line1\\nLine2',
      'tags' => [{ 'name' => 'na', 'value' => '' }]
    }
    txt = NA::Plugins.serialize_actions([action], format: 'text', divider: '||')
    parsed = NA::Plugins.parse_actions(txt, format: 'text', divider: '||')
    assert_equal 1, parsed.size
    p1 = parsed.first
    assert_equal '/t/todo.taskpaper', p1['file_path']
    assert_equal 5, p1['line']
    assert_equal %w[Work Backlog], p1['parents']
    assert_equal '- Example', p1['text']
    assert_equal "Line1\nLine2", p1['note']
    assert_equal({ 'action' => 'MOVE', 'arguments' => ['Work:Feature'] }, p1['action'])
  end

  def test_csv_roundtrip
    action = {
      'action' => { 'action' => 'ADD_TAG', 'arguments' => ['bar'] },
      'file_path' => '/t/todo.taskpaper',
      'line' => 7,
      'parents' => ['Inbox'],
      'text' => '- Add tag',
      'note' => '',
      'tags' => []
    }
    csv = NA::Plugins.serialize_actions([action], format: 'csv')
    parsed = NA::Plugins.parse_actions(csv, format: 'csv')
    p1 = parsed.first
    assert_equal 'ADD_TAG', p1['action']['action']
    assert_equal ['bar'], p1['action']['arguments']
    assert_equal 7, p1['line']
  end

  def test_run_plugin_echo_json
    with_tmp_plugins do |dir|
      path = File.join(dir, 'Echo.py')
      File.write(path, <<~PY)
        #!/usr/bin/env python3
        # input: json
        # output: json
        import sys, json
        data = json.load(sys.stdin)
        # mutate: add @foo
        for a in data:
            tags = a.get('tags', [])
            tags.append({'name':'foo','value':''})
            a['tags'] = tags
        json.dump(data, sys.stdout)
      PY
      File.chmod(0o755, path)
      input = [{ 'file_path' => '/t/t.todo', 'line' => 1, 'parents' => [], 'text' => '- T', 'note' => '', 'tags' => [] }]
      stdin = NA::Plugins.serialize_actions(input, format: 'json')
      out = NA::Plugins.run_plugin(path, stdin)
      parsed = NA::Plugins.parse_actions(out, format: 'json')
      assert_equal 'foo', parsed.first['tags'].last['name']
    end
  end
end


