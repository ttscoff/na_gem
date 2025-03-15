# frozen_string_literal: true

module NA
  # Actions controller
  class Actions < Array
    def initialize(actions = [])
      super
      concat(actions)
    end

    ##
    ## Pretty print a list of actions
    ##
    ## @param      actions  [Array] The actions
    ## @param      depth    [Number] The depth
    ## @param      files    [Array] The files actions originally came from
    ## @param      regexes  [Array] The regexes used to gather actions
    ##
    def output(depth, files: nil, regexes: [], notes: false, nest: false, nest_projects: false, no_files: false)
      return if files.nil?

      if nest
        template = NA.theme[:templates][:default]
        template = NA.theme[:templates][:no_file] if no_files

        parent_files = {}
        out = []

        if nest_projects
          each do |action|
            if parent_files.key?(action.file)
              parent_files[action.file].push(action)
            else
              parent_files[action.file] = [action]
            end
          end

          parent_files.each do |file, acts|
            projects = NA.project_hierarchy(acts)
            out.push("#{file.sub(%r{^./}, '').shorten_path}:")
            out.concat(NA.output_children(projects, 0))
          end
        else
          template = NA.theme[:templates][:default]
          template = NA.theme[:templates][:no_file] if no_files

          each do |action|
            if parent_files.key?(action.file)
              parent_files[action.file].push(action)
            else
              parent_files[action.file] = [action]
            end
          end

          parent_files.each do |k, v|
            out.push("#{k.sub(%r{^\./}, '')}:")
            v.each do |a|
              out.push("\t- [#{a.parent.join('/')}] #{a.action}")
              out.push("\t\t#{a.note.join("\n\t\t")}") unless a.note.empty?
            end
          end
        end
        NA::Pager.page out.join("\n")
      else
        template =
                    if no_files
                      NA.theme[:templates][:no_file]
                    elsif files.count.positive?
                     if files.count == 1
                       NA.theme[:templates][:single_file]
                     else
                       NA.theme[:templates][:multi_file]
                     end
                   elsif NA.find_files(depth: depth).count > 1
                     if depth > 1
                       NA.theme[:templates][:multi_file]
                     else
                       NA.theme[:templates][:single_file]
                     end
                   else
                     NA.theme[:templates][:default]
                   end
        template += '%note' if notes

        files.map { |f| NA.notify(f, debug: true) } if files

        output = map { |action| action.pretty(template: { templates: { output: template } }, regexes: regexes, notes: notes) }
        NA::Pager.page(output.join("\n"))
      end
    end
  end
end
