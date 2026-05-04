module Capture
  class ProcessMessage
    def self.call(text:, writer: TaskWriter)
      new(text:, writer:).call
    end

    def initialize(text:, writer:)
      @text = text.to_s
      @writer = writer
    end

    def call
      decision = Admission.call(text)
      return Result.rejected(reason: decision.reason, hint: decision.hint) unless decision.supported?

      task = writer.call(body: decision.normalized_text, source_text: text)
      return Result.failed(reason: "Сохранение задачи не завершилось успешно.") unless task

      Result.accepted(task:)
    end

    private

    attr_reader :text, :writer
  end
end
