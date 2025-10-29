# frozen_string_literal: true

require 'json'
require 'yaml'
require 'csv'

module NA
  # Plugins module for NA
  module Plugins
    module_function

    def plugins_home
      File.expand_path('~/.local/share/na/plugins')
    end

    def plugins_disabled_home
      File.expand_path('~/.local/share/na/plugins_disabled')
    end

    def samples_generated_flag
      File.expand_path('~/.local/share/na/.samples_generated')
    end

    def samples_generated?
      File.exist?(samples_generated_flag)
    end

    def mark_samples_generated
      FileUtils.mkdir_p(File.dirname(samples_generated_flag))
      File.write(samples_generated_flag, Time.now.iso8601) unless File.exist?(samples_generated_flag)
    end

    def ensure_plugins_home(force_samples: false)
      dir = plugins_home
      dis = plugins_disabled_home
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      FileUtils.mkdir_p(dis) unless File.directory?(dis)

      readme = File.join(dir, 'README.md')
      File.write(readme, default_readme_contents) unless File.exist?(readme)

      return if samples_generated? || force_samples

      create_sample_plugins(dis)
      mark_samples_generated
    end

    def generate_sample_plugins
      dis = plugins_disabled_home
      FileUtils.mkdir_p(dis) unless File.directory?(dis)
      create_sample_plugins(dis, force: true)
      mark_samples_generated
    end

    def list_plugins
      dir = plugins_home
      return {} unless File.directory?(dir)

      Dir.children(dir).each_with_object({}) do |entry, acc|
        path = File.join(dir, entry)
        next unless File.file?(path)
        next if entry =~ /\.(md|bak)$/i
        next unless shebang?(path)

        base = File.basename(entry, File.extname(entry))
        key = base.gsub(/[\s_]/, '')
        acc[key.downcase] = path
      end
    end

    def list_plugins_disabled
      dir = plugins_disabled_home
      return {} unless File.directory?(dir)

      Dir.children(dir).each_with_object({}) do |entry, acc|
        path = File.join(dir, entry)
        next unless File.file?(path)
        next if entry =~ /\.(md|bak)$/i
        next unless shebang?(path)

        base = File.basename(entry, File.extname(entry))
        key = base.gsub(/[\s_]/, '')
        acc[key.downcase] = path
      end
    end

    def resolve_plugin(name)
      return nil unless name && !name.to_s.strip.empty?

      normalized = name.to_s.strip.gsub(/[\s_]/, '').downcase
      candidates = list_plugins
      return candidates[normalized] if candidates.key?(normalized)

      # Fallback: try exact filename match in dir
      path = File.join(plugins_home, name)
      return path if File.file?(path)

      # Also check disabled folder
      path = File.join(plugins_disabled_home, name)
      File.file?(path) ? path : nil
    end

    def shebang_for(file)
      first = begin
        File.open(file, 'r', &:readline)
      rescue StandardError
        ''
      end
      first.start_with?('#!') ? first.sub('#!', '').strip : nil
    end

    def infer_shebang_for_extension(ext)
      case ext.downcase
      when '.rb' then '#!/usr/bin/env ruby'
      when '.py' then '#!/usr/bin/env python3'
      when '.zsh' then '#!/usr/bin/env zsh'
      when '.fish' then '#!/usr/bin/env fish'
      when '.js', '.mjs' then '#!/usr/bin/env node'
      else '#!/usr/bin/env bash'
      end
    end

    def parse_plugin_metadata(file)
      meta = { 'input' => nil, 'output' => nil, 'name' => nil }
      lines = File.readlines(file, chomp: true)
      return meta if lines.empty?

      # skip shebang
      i = 0
      i += 1 if lines[0].to_s.start_with?('#!')
      # skip leading blanks
      i += 1 while i < lines.length && lines[i].strip.empty?
      while i < lines.length
        line = lines[i]
        break if line.strip.empty?

        # strip common comment leaders
        stripped = line.sub(%r{^\s*(#|//)}, '').strip
        if (m = stripped.match(/^([A-Za-z]+)\s*:\s*(.+)$/))
          key = m[1].downcase
          val = m[2].strip
          case key
          when 'input', 'output'
            meta[key] = val.downcase
          when 'name', 'title'
            meta['name'] = val
          end
        end
        break if meta.values_at('input', 'output', 'name').compact.size == 3

        i += 1
      end
      meta
    end

    def run_plugin(file, stdin_str)
      interp = shebang_for(file)
      cmd = interp ? %(#{interp} #{Shellwords.escape(file)}) : %(sh #{Shellwords.escape(file)})
      IO.popen(cmd, 'r+', err: %i[child out]) do |io|
        io.write(stdin_str.to_s)
        io.close_write
        io.read
      end
    end

    def enable_plugin(name)
      # Try by resolved path; if already enabled, return
      path = resolve_plugin(name)
      return path if path && File.dirname(path) == plugins_home

      # Find in disabled by normalized name
      disabled_map = Dir.exist?(plugins_disabled_home) ? Dir.children(plugins_disabled_home) : []
      from = disabled_map.map { |e| File.join(plugins_disabled_home, e) }
                         .find { |p| File.basename(p).downcase.start_with?(name.to_s.downcase) }
      from ||= File.join(plugins_disabled_home, name)
      to = File.join(plugins_home, File.basename(from))
      FileUtils.mv(from, to)
      to
    end

    def disable_plugin(name)
      path = resolve_plugin(name)
      return path if path && File.dirname(path) == plugins_disabled_home

      enabled_map = Dir.exist?(plugins_home) ? Dir.children(plugins_home) : []
      from = enabled_map.map { |e| File.join(plugins_home, e) }
                        .find { |p| File.basename(p).downcase.start_with?(name.to_s.downcase) }
      from ||= File.join(plugins_home, name)
      to = File.join(plugins_disabled_home, File.basename(from))
      FileUtils.mv(from, to)
      to
    end

    def create_plugin(name, language: nil)
      base = File.basename(name)
      ext = File.extname(base)
      if ext.empty? && language
        ext = language.start_with?('.') ? language : ".#{language.split('/').last}"
      end
      ext = '.sh' if ext.empty?
      she = language&.start_with?('/') ? language : infer_shebang_for_extension(ext)
      file = File.join(plugins_home, base.sub(File.extname(base), '') + ext)
      content = []
      content << she
      content << "# name: #{base.sub(File.extname(base), '')}"
      content << '# input: json'
      content << '# output: json'
      content << '# New plugin template'
      content << ''
      content << '# Read STDIN and echo back unchanged'
      content << 'if command -v python3 >/dev/null 2>&1; then'
      content << "  python3 - \"$@\" <<'PY'"
      content << 'import sys, json'
      content << 'data = json.load(sys.stdin)'
      content << 'json.dump(data, sys.stdout)'
      content << 'PY'
      content << 'else'
      content << '  cat'
      content << 'fi'
      File.write(file, content.join("\n"))
      file
    end

    def serialize_actions(actions, format: 'json', divider: '||')
      case format.to_s.downcase
      when 'json'
        JSON.pretty_generate(actions)
      when 'yaml', 'yml'
        YAML.dump(actions)
      when 'csv'
        CSV.generate(force_quotes: true) do |csv|
          csv << %w[action arguments file_path line parents text note tags]
          actions.each do |a|
            csv << [
              (a['action'] && a['action']['action']) || 'UPDATE',
              Array(a['action'] && a['action']['arguments']).join(','),
              a['file_path'],
              a['line'],
              Array(a['parents']).join('>'),
              a['text'] || '',
              a['note'] || '',
              serialize_tags(a['tags'])
            ]
          end
        end
      when 'text', 'txt'
        actions.map { |a| serialize_text(a, divider: divider) }.join("\n")
      else
        JSON.generate(actions)
      end
    end

    def parse_actions(str, format: 'json', divider: '||')
      case format.to_s.downcase
      when 'json'
        JSON.parse(str)
      when 'yaml', 'yml'
        YAML.safe_load(str, permitted_classes: [Time], aliases: true)
      when 'csv'
        rows = CSV.parse(str.to_s, headers: true)
        rows = CSV.parse(str.to_s) if rows.nil? || rows.empty?
        rows.map do |row|
          r = if row.is_a?(CSV::Row)
                row.to_h
              else
                {
                  'action' => row[0], 'arguments' => row[1], 'file_path' => row[2], 'line' => row[3],
                  'parents' => row[4], 'text' => row[5], 'note' => row[6], 'tags' => row[7]
                }
              end
          {
            'file_path' => r['file_path'].to_s,
            'line' => r['line'].to_i,
            'parents' => (r['parents'].to_s.empty? ? [] : r['parents'].split('>').map(&:strip)),
            'text' => r['text'].to_s,
            'note' => r['note'].to_s,
            'tags' => parse_tags(r['tags']),
            'action' => normalize_action_block(r['action'], r['arguments'])
          }
        end
      when 'text', 'txt'
        str.to_s.split(/\r?\n/).reject(&:empty?).map { |line| parse_text(line, divider: divider) }
      end
    end

    def serialize_text(action, divider: '||')
      parts = []
      act = action['action'] && action['action']['action']
      args = Array(action['action'] && action['action']['arguments']).join(',')
      parts << (act || 'UPDATE')
      parts << args
      parts << "#{action['file_path']}:#{action['line']}"
      parts << Array(action['parents']).join('>')
      parts << (action['text'] || '')
      parts << (action['note'] || '').gsub("\n", '\\n')
      parts << serialize_tags(action['tags'])
      parts.join(divider)
    end

    def parse_text(line, divider: '||')
      tokens = line.split(divider, 7)
      action_token = tokens[0].to_s.strip
      if action_name?(action_token)
        act = action_token
        args = tokens[1]
        fileline = tokens[2]
        parents = tokens[3]
        text = tokens[4]
        note = tokens[5]
        tags = tokens[6]
      else
        act = 'UPDATE'
        args = ''
        fileline = tokens[0]
        parents = tokens[1]
        text = tokens[2]
        note = tokens[3]
        tags = tokens[4]
      end
      fp, ln = (fileline || '').split(':', 2)
      {
        'file_path' => fp.to_s,
        'line' => ln.to_i,
        'parents' => (parents.to_s.empty? ? [] : parents.split('>').map(&:strip)),
        'text' => text.to_s,
        'note' => note.to_s.gsub('\\n', "\n"),
        'tags' => parse_tags(tags),
        'action' => normalize_action_block(act, args)
      }
    end

    def serialize_tags(tags)
      Array(tags).map { |t| t['value'].to_s.empty? ? t['name'].to_s : %(#{t['name']}(#{t['value']})) }.join(';')
    end

    def parse_tags(str)
      return [] if str.to_s.strip.empty?

      str.split(';').map do |part|
        if (m = part.match(/^([^()]+)\((.*)\)$/))
          { 'name' => m[1].strip, 'value' => m[2].to_s }
        else
          { 'name' => part.strip, 'value' => '' }
        end
      end
    end

    def shebang?(file)
      first = begin
        File.open(file, 'r', &:readline)
      rescue StandardError
        ''
      end
      first.start_with?('#!')
    end

    def action_name?(name)
      return false if name.to_s.strip.empty?

      %w[update delete complete finish restore unfinish archive add_tag delete_tag remove_tag move].include?(name.to_s.downcase)
    end

    def normalize_action_block(action_name, args)
      name = (action_name || 'UPDATE').to_s.upcase
      name = 'DELETE_TAG' if name == 'REMOVE_TAG'
      name = 'COMPLETE' if name == 'FINISH'
      name = 'RESTORE' if name == 'UNFINISH'
      {
        'action' => name,
        'arguments' => args.is_a?(Array) ? args : args.to_s.split(/[,;]/).map(&:strip).reject(&:empty?)
      }
    end

    def default_readme_contents
      <<~MD
        # NA Plugins

        Put your scripts in this folder. Each plugin must start with a shebang (#!) so NA knows how to execute it.

        - Plugins receive input on STDIN and must write output to STDOUT
        - Do not modify the original files; NA applies changes based on your output
        - Do not change `file_path` or `line` in your output
        - You may change `parents` (to move), `text`, `note`, and `tags`

        ## Metadata (optional)
        Add a comment block (after the shebang) with key: value pairs to declare defaults. Keys are case-insensitive.

        ```
        # input: json
        # output: json
        # name: My Fancy Plugin
        ```

        CLI flags `--input/--output/--divider` override metadata when provided.

        ## Formats
        Valid input/output formats: `json`, `yaml`, `csv`, `text`.

        Text format line:
        ```
        ACTION||ARGS||file_path:line||parents||text||note||tags
        ```
        - If the first token isn’t a known ACTION, it’s treated as `file_path:line` and ACTION defaults to `UPDATE`.
        - `parents`: `Parent>Child>Leaf`
        - `tags`: `name(value);name;other(value)`

        JSON/YAML object schema per action:
        ```json
        {
          "action": { "action": "UPDATE", "arguments": ["arg1"] },
          "file_path": "/path/to/todo.taskpaper",
          "line": 15,
          "parents": ["Project", "Subproject"],
          "text": "- Do something @tag(value)",
          "note": "Notes can\nspan lines",
          "tags": [ { "name": "tag", "value": "value" } ]
        }
        ```

        ACTION values (case-insensitive): `UPDATE` (default), `DELETE`, `COMPLETE`/`FINISH`, `RESTORE`/`UNFINISH`, `ARCHIVE`, `ADD_TAG`, `DELETE_TAG`/`REMOVE_TAG`, `MOVE`.
        - For `ADD_TAG`, `DELETE_TAG`/`REMOVE_TAG`, and `MOVE`, provide arguments (e.g., tags or target project).

        ## Examples

        JSON input example (2 actions):
        ```json
        [
          {
            "file_path": "/projects/todo.taskpaper",
            "line": 21,
            "parents": ["Inbox"],
            "text": "- Example action",
            "note": "",
            "tags": []
          },
          {
            "file_path": "/projects/todo.taskpaper",
            "line": 42,
            "parents": ["Work", "Feature"],
            "text": "- Add feature @na",
            "note": "Spec TKT-123",
            "tags": [{"name":"na","value":""}]
          }
        ]
        ```

        Text input example (2 actions):
        ```
        UPDATE||||/projects/todo.taskpaper:21||Inbox||- Example action||||
        MOVE||Work:NewFeature||/projects/todo.taskpaper:42||Work>Feature||- Add feature @na||Spec TKT-123||na
        ```

        A plugin would read from STDIN, transform, and write the same shape to STDOUT. For example, a shell plugin that adds `@bar`:
        ```bash
        #!/usr/bin/env bash
        # input: text
        # output: text
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          IFS='||' read -r a1 a2 a3 a4 a5 a6 a7 <<<"$line"
          # If first token is not an action, treat it as file:line
          case "${a1^^}" in
            UPDATE|DELETE|COMPLETE|FINISH|RESTORE|UNFINISH|ARCHIVE|ADD_TAG|DELETE_TAG|REMOVE_TAG|MOVE) : ;;
            *) a7="$a6"; a6="$a5"; a5="$a4"; a4="$a3"; a3="$a2"; a2=""; a1="UPDATE";;
          esac
          tags="$a7"; tags=${tags:+"$tags;bar"}; tags=${tags:-bar}
          echo "$a1||$a2||$a3||$a4||$a5||$a6||$tags"
        done
        ```

        Python example (JSON):
        ```python
        #!/usr/bin/env python3
        # input: json
        # output: json
        import sys, json, time
        data = json.load(sys.stdin)
        for a in data:
            act = a.get('action') or {'action':'UPDATE','arguments':[]}
            a['action'] = act
            tags = a.get('tags', [])
            tags.append({'name':'foo','value':time.strftime('%Y-%m-%d %H:%M:%S')})
            a['tags'] = tags
        json.dump(data, sys.stdout)
        ```

        Tips:
        - Always preserve `file_path` and `line`
        - Return only actions you want changed; others can be omitted
        - For text IO, the field divider defaults to `||` and can be overridden with `--divider`
      MD
    end

    def create_sample_plugins(dir, force: false)
      py = File.join(dir, 'Add Foo.py')
      sh = File.join(dir, 'Add Bar.sh')

      if force || !File.exist?(py)
        File.delete(py) if File.exist?(py)
        File.write(py, <<~PY)
          #!/usr/bin/env python3
          # name: Add Foo
          # input: json
          # output: json
          import sys, json, time
          data = json.load(sys.stdin)
          now = time.strftime('%Y-%m-%d %H:%M:%S')
          for a in data:
              tags = a.get('tags', [])
              tags.append({'name':'foo','value':now})
              a['tags'] = tags
          json.dump(data, sys.stdout)
        PY
      end
      unless File.exist?(sh)
        File.write(sh, <<~SH)
          #!/usr/bin/env bash
          # name: Add Bar
          # input: text
          # output: text
          while IFS= read -r line; do
            if [[ -z "$line" ]]; then continue; fi
            if [[ "$line" == *"||"* ]]; then
              fileline=${line%%||*}
              rest=${line#*||}
              parents=${rest%%||*}; rest=${rest#*||}
              text=${rest%%||*}; rest=${rest#*||}
              note=${rest%%||*}; tags=${rest#*||}
              if [[ -z "$tags" ]]; then tags="bar"; else tags="$tags;bar"; fi
              echo "$fileline||$parents||$text||$note||$tags"
            else
              echo "$line"
            fi
          done
        SH
      end

      return unless force || !File.exist?(sh)

      File.delete(sh) if File.exist?(sh)
      File.write(sh, <<~SH)
        #!/usr/bin/env bash
        # name: Add Bar
        # input: text
        # output: text
        while IFS= read -r line; do
          if [[ -z "$line" ]]; then continue; fi
          if [[ "$line" == *"||"* ]]; then
            fileline=${line%%||*}
            rest=${line#*||}
            parents=${rest%%||*}; rest=${rest#*||}
            text=${rest%%||*}; rest=${rest#*||}
            note=${rest%%||*}; tags=${rest#*||}
            if [[ -z "$tags" ]]; then tags="bar"; else tags="$tags;bar"; fi
            echo "$fileline||$parents||$text||$note||$tags"
          else
            echo "$line"
          fi
        done
      SH
      File.chmod(0o755, sh)
    end
  end
end
