module Capture
  class Result
    attr_reader :kind, :message, :task, :reason, :hint

    def initialize(kind:, message:, task: nil, reason: nil, hint: nil)
      @kind = kind
      @message = message
      @task = task
      @reason = reason
      @hint = hint
    end

    def self.accepted(task:)
      new(kind: :accepted, message: "Задача сохранена.", task: task)
    end

    def self.rejected(reason:, hint:)
      new(
        kind: :rejected,
        message: "Не получилось сохранить задачу автоматически.",
        reason: reason,
        hint: hint
      )
    end

    def self.failed(reason:)
      new(
        kind: :failed,
        message: "Не удалось сохранить задачу.",
        reason: reason
      )
    end

    def http_status
      case kind
      when :accepted then :created
      when :rejected then :unprocessable_content
      else :internal_server_error
      end
    end

    def as_json(*)
      payload = {
        status: kind.to_s,
        message: message
      }

      payload[:task] = serialized_task if task
      payload[:reason] = reason if reason
      payload[:hint] = hint if hint

      payload
    end

    private

    def serialized_task
      {
        id: task.id,
        body: task.body,
        status: task.status
      }
    end
  end
end
