require_relative "test_helper"

class DefaultTest < Minitest::Test
  def setup
    create_temp_files
  end

  def teardown
    clean_up_temp_files
  end

  # def test_add
  #   NA.add_action('test.taskpaper', 'Inbox', 'Test Action @testing', [], finish: false, append: false)
  #   files, actions, = NA.parse_actions(depth: 1,
  #                                      done: false,
  #                                      query: [],
  #                                      tag: [{ tag: 'testing', value: nil }],
  #                                      search: [],
  #                                      project: 'Inbox',
  #                                      require_na: false)

  #   assert actions.count == 1
  # end

  # def test_update
  #   NA.add_action('test.taskpaper', 'Inbox', 'Test Action @testing')

  #   tags = []
  #   all_req = true
  #   ['testing'].join(',').split(/ *, */).each do |arg|
  #     m = arg.match(/^(?<req>[+\-!])?(?<tag>[^ =<>$\^]+?)(?:(?<op>[=<>]{1,2}|[*$\^]=)(?<val>.*?))?$/)

  #     tags.push({
  #                 tag: m['tag'].wildcard_to_rx,
  #                 comp: m['op'],
  #                 value: m['val'],
  #                 required: all_req || (!m['req'].nil? && m['req'] == '+'),
  #                 negate: !m['req'].nil? && m['req'] =~ /[!\-]/
  #               })
  #   end

  #   NA.update_action('test.taskpaper', nil,
  #                    priority: 5,
  #                    add_tag: ['testing2'],
  #                    remove_tag: ['testing'],
  #                    finish: false,
  #                    project: nil,
  #                    delete: false,
  #                    note: [],
  #                    overwrite: false,
  #                    tagged: tags,
  #                    all: true,
  #                    done: true,
  #                    append: false)

  #   files, actions, = NA.parse_actions(file_path: 'test.taskpaper',
  #                                      done: false,
  #                                      tag: [{ tag: 'testing2', value: nil }],
  #                                      project: 'Inbox')
  #   assert actions.count == 1
  # end
end
