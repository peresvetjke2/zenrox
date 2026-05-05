module Retrieval
  class ListOpenTasks
    def self.call(reader: Task)
      new(reader:).call
    end

    def initialize(reader:)
      @reader = reader
    end

    def call
      Result.success(tasks: reader.open_for_retrieval.to_a)
    rescue ActiveRecord::ActiveRecordError
      Result.failure
    end

    private

    attr_reader :reader
  end
end
