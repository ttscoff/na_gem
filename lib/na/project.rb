# frozen_string_literal: true

module NA
  class Project < Hash
    attr_accessor :project, :indent, :line

    def initialize(project, indent = 0, line = 0)
      super()
      @project = project
      @indent = indent
      @line = line
    end

    def to_s
      { project: @project, indent: @indent, line: @line }.to_s
    end

    def inspect
      [
        "@project: #{@project}",
        "@indent: #{@indent}",
        "@line: #{@line}"
      ].join(" ")
    end
  end
end
