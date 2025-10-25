# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Scan a directory tree for todo files and cache them'
  long_desc 'Searches PATH (default: current directory) for files matching the current NA.extension
and adds their absolute paths to the tdlist.txt cache. Avoids duplicates. Optionally prunes
non-existent entries from the cache.'
  arg_name 'PATH', optional: true
  command %i[scan] do |c|
    c.example 'na scan', desc: 'Scan current directory up to default depth (5)'
    c.example 'na scan -d 3 ~/Projects', desc: 'Scan a specific path up to depth 3'
    c.example 'na scan -d inf', desc: 'Scan current directory recursively with no depth limit'
    c.example 'na scan --prune', desc: 'Prune non-existent entries from the cache (in addition to scanning)'

    c.desc 'Recurse to depth (1..N or i/inf for infinite)'
    c.arg_name 'DEPTH'
    c.default_value '5'
    c.flag %i[d depth], must_match: /^(\d+|i\w*)$/i

    c.desc 'Prune removed files from cache after scan'
    c.switch %i[p prune], negatable: false, default_value: false

    c.desc 'Include hidden directories and files while scanning'
    c.switch %i[hidden], negatable: false, default_value: false

    c.desc 'Show what would be added/pruned, but do not write tdlist.txt'
    c.switch %i[n dry-run], negatable: false, default_value: false

    c.action do |_global_options, options, args|
      base = args.first || Dir.pwd
      ext = NA.extension

      # Parse depth: numeric or starts-with-i for infinite
      depth_arg = (options[:depth] || '5').to_s
      infinite = depth_arg =~ /^i/i ? true : false
      depth = infinite ? nil : depth_arg.to_i
      depth = 5 if depth.nil? && !infinite

      # Prepare existing cache
      db = NA.database_path
      existing = if File.exist?(db)
                   File.read(db).split(/\n/).map(&:strip)
                 else
                   []
                 end

      found = []
      Dir.chdir(base) do
        patterns = if infinite
                     ["*.#{ext}", "**/*.#{ext}"]
                   else
                     (1..[depth, 1].max).map { |d| (d > 1 ? ('*/' * (d - 1)) : '') + "*.#{ext}" }
                   end
        pattern = patterns.length == 1 ? patterns.first : "{#{patterns.join(',')}}"
        files = Dir.glob(pattern, File::FNM_DOTMATCH)
        # Exclude hidden dirs/files (any segment starting with '.') unless --hidden
        files.reject! { |f| f.split('/').any? { |seg| seg.start_with?('.') && seg !~ /^\.\.?$/ } } unless options[:hidden]
        found = files.map { |f| File.expand_path(f) }
      end

      merged = (existing + found).map(&:strip).uniq.sort
      merged.select! { |f| File.exist?(f) } if options[:prune]

      added_files = (merged - existing)
      pruned_files = options[:prune] ? (existing - merged) : []
      added = added_files.count
      pruned = pruned_files.count

      if options[:dry_run]
        msg = "#{NA.theme[:success]}Dry run: would add #{added} file#{added == 1 ? '' : 's'}"
        msg << ", prune #{pruned} file#{pruned == 1 ? '' : 's'}" if options[:prune]
        NA.notify(msg)
        NA.notify("{bw}Would add:{x}\n#{added_files.join("\n")}") if added_files.any?
        NA.notify("{bw}Would prune:{x}\n#{pruned_files.join("\n")}") if options[:prune] && pruned_files.any?
      else
        File.open(db, 'w') { |f| f.puts merged.join("\n") }
        msg = "#{NA.theme[:success]}Scan complete: #{NA.theme[:filename]}#{added}{x}#{NA.theme[:success]} added"
        msg << ", #{NA.theme[:filename]}#{pruned}{x}#{NA.theme[:success]} pruned" if options[:prune]
        NA.notify(msg)
      end
    end
  end
end
