module Retrieval
  class Result
    attr_reader :kind, :tasks

    def initialize(kind:, tasks: [])
      @kind = kind
      @tasks = tasks
    end

    def self.failure
      new(kind: :failure)
    end

    def self.success(tasks:)
      kind = tasks.empty? ? :empty : :success
      new(kind:, tasks:)
    end

    def message
      return "Не удалось получить список открытых задач." if failure?
      return "Открытых задач нет." if empty?

      [ "Открытые задачи:", *tasks.map { |task| "- #{task.body}" } ].join("\n")
    end

    def empty?
      kind == :empty
    end

    def failure?
      kind == :failure
    end
  end
end
