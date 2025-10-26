# frozen_string_literal: true

module NA
  # Represents a project section in a todo file, with indentation and line tracking.
  #
  # @example Create a new project
  #   project = NA::Project.new('Inbox', 0, 1, 5)
  class Project < Hash
    attr_accessor :project, :indent, :line, :last_line

    # Initialize a Project object
    #
    # @param project [String] Project name
    # @param indent [Integer] Indentation level
    # @param line [Integer] Starting line number
    # @param last_line [Integer] Ending line number
    # @return [void]
    # @example
    #   project = NA::Project.new('Inbox', 0, 1, 5)
    def initialize(project, indent = 0, line = 0, last_line = 0)
      super()
      @project = project
      @indent = indent
      @line = line
      @last_line = last_line
    end

    # String representation of the project
    #
    # @return [String]
    # @example
    #   project.to_s #=> "{ project: 'Inbox', ... }"
    def to_s
      { project: @project, indent: @indent, line: @line, last_line: @last_line }.to_s
    end

    # Inspect the project object
    #
    # @return [String]
    def inspect
      [
        "@project: #{@project}",
        "@indent: #{@indent}",
        "@line: #{@line}",
        "@last_line: #{@last_line}"
      ].join(' ')
    end
  end
end
