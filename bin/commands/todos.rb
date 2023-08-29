# frozen_string_literal: true

desc 'Show list of known todo files'
long_desc 'Arguments will be interpreted as a query against which the
list of todos will be fuzzy matched. Separate directories with
/, :, or a space, e.g. `na todos code/marked`'
arg_name 'QUERY', optional: true
command %i[todos] do |c|
  c.action do |_global_options, _options, args|
    if args.count.positive?
      all_req = args.join(' ') !~ /[+!\-]/

      tokens = [{ token: '*', required: all_req, negate: false }]
      args.each do |arg|
        arg.split(/ *, */).each do |a|
          m = a.match(/^(?<req>[+\-!])?(?<tok>.*?)$/)
          tokens.push({
                        token: m['tok'],
                        required: all_req || (!m['req'].nil? && m['req'] == '+'),
                        negate: !m['req'].nil? && m['req'] =~ /[!\-]/
                      })
        end
      end
    end

    NA.list_todos(query: tokens)
  end
end
