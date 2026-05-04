module Capture
  class ProcessMessage
    def self.call(text:, writer: TaskWriter, operation_id: SecureRandom.uuid)
      new(text:, writer:, operation_id:).call
    end

    def initialize(text:, writer:, operation_id:)
      @text = text.to_s
      @writer = writer
      @operation_id = operation_id
    end

    def call
      decision = Admission.call(text)
      return Result.rejected(reason: decision.reason, hint: decision.hint) unless decision.supported?

      task = writer.call(body: decision.normalized_text, source_text: text, operation_id:)
      return Result.failed(reason: "Сохранение задачи не завершилось успешно.") unless task

      Result.accepted(task:)
    end

    private

    attr_reader :operation_id, :text, :writer
  end
end
