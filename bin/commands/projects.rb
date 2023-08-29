# frozen_string_literal: true

class App
  extend GLI::App
  desc 'Show list of projects for a file'
  long_desc 'Arguments will be interpreted as a query for a known todo file,
  fuzzy matched. Separate directories with /, :, or a space, e.g. `na projects code/marked`'
  arg_name 'QUERY', optional: true
  command %i[projects] do |c|
    c.desc 'Search for files X directories deep'
    c.arg_name 'DEPTH'
    c.flag %i[d depth], must_match: /^[1-9]$/, type: :integer, default_value: 1

    c.desc 'Output projects as paths instead of hierarchy'
    c.switch %i[p paths], negatable: false

    c.action do |_global_options, options, args|
      if args.count.positive?
        all_req = args.join(' ') !~ /[+!-]/

        tokens = [{ token: '*', required: all_req, negate: false }]
        args.each do |arg|
          arg.split(/ *, */).each do |a|
            m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
            tokens.push({
                          token: m['tok'],
                          required: all_req || (!m['req'].nil? && m['req'] == '+'),
                          negate: !m['req'].nil? && m['req'] =~ /[!-]/
                        })
          end
        end
      end

      NA.list_projects(query: tokens, depth: options[:depth], paths: options[:paths])
    end
  end
end
