module Capture
  class TaskWriter
    def self.call(body:, source_text:, operation_id: SecureRandom.uuid)
      new(body:, source_text:, operation_id:).call
    end

    def initialize(body:, source_text:, operation_id:)
      @body = body
      @source_text = source_text
      @operation_id = operation_id
    end

    def call
      task = Task.new(
        body: body,
        source_text: source_text,
        status: "open",
        operation_id: operation_id
      )

      return task if task.save

      nil
    end

    private

    attr_reader :body, :source_text, :operation_id
  end
end
