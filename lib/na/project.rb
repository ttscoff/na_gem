# frozen_string_literal: true

module NA
  class Project < Hash
    attr_accessor :project, :indent, :line, :last_line

    def initialize(project, indent = 0, line = 0, last_line = 0)
      super()
      @project = project
      @indent = indent
      @line = line
      @last_line = last_line
    end

    def to_s
      { project: @project, indent: @indent, line: @line, last_line: @last_line }.to_s
    end

    def inspect
      [
        "@project: #{@project}",
        "@indent: #{@indent}",
        "@line: #{@line}",
        "@last_line: #{@last_line}"
      ].join(" ")
    end
  end
end
