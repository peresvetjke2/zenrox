module Routing
  class ProcessMessage
    RETRIEVAL_PATTERNS = [
      /\Aзадачи\z/i,
      /\Aпокажи(?:\s+мне)?\s+задачи\z/i,
      /\Aчто\s+у\s+меня(?:\s+открыто)?\??\z/i,
      /\Aкакие\s+у\s+меня\s+задачи\??\z/i
    ].freeze

    LIFECYCLE_RULES = [
      {
        intent_label: :mark_task_done,
        pattern: /\A(?:закрой|отметь(?:\s+как)?\s+выполненн(?:ой|ым)?|сделано)\s+(.+)\z/i,
        pending_message: "Не выполнил действие: задачу для завершения удалось определить, но автоматическое закрытие пока не реализовано.",
        clarification_message: "Не выполнил действие: уточните, какую задачу нужно завершить."
      },
      {
        intent_label: :reopen_task,
        pattern: /\A(?:верни(?:\s+обратно)?\s+в\s+работу|переоткрой|снова\s+открой)\s+(.+)\z/i,
        pending_message: "Не выполнил действие: задачу для возврата в работу удалось определить, но автоматическое переоткрытие пока не реализовано.",
        clarification_message: "Не выполнил действие: уточните, какую задачу нужно вернуть в работу."
      },
      {
        intent_label: :delete_task,
        pattern: /\A(?:удали|удалить)\s+(.+)\z/i,
        pending_message: "Не выполнил действие: задачу для удаления удалось определить, но автоматическое удаление пока не реализовано.",
        clarification_message: "Не выполнил действие: уточните точную задачу для удаления."
      }
    ].freeze

    UNSUPPORTED_REPLY = "Не выполнил действие: запрос пока не поддерживается в этом канале."
    MIXED_INTENT_REPLY = "Не выполнил действие: в одном сообщении получилось несколько запросов. Отправьте одну команду за раз."

    def self.call(text:, task_reader: Task, capture_admission: Capture::Admission)
      new(text:, task_reader:, capture_admission:).call
    end

    def initialize(text:, task_reader:, capture_admission:)
      @original_text = text.to_s.strip
      @normalized_text = normalize(text)
      @task_reader = task_reader
      @capture_admission = capture_admission
    end

    def call
      return mixed_intent_verdict if mixed_intent?
      return retrieval_verdict if retrieval_intent?

      lifecycle_match = matched_lifecycle_rule
      return lifecycle_verdict(lifecycle_match) if lifecycle_match

      return capture_verdict if capture_decision.supported?

      Verdict.unsupported(original_text:, reply_text: UNSUPPORTED_REPLY)
    end

    private

    attr_reader :capture_admission, :normalized_text, :original_text, :task_reader

    def capture_decision
      @capture_decision ||= capture_admission.call(original_text)
    end

    def capture_verdict
      Verdict.handoff(
        intent_label: :capture_task,
        downstream: :capture_task,
        original_text:
      )
    end

    def lifecycle_marker_count
      @lifecycle_marker_count ||= LIFECYCLE_RULES.count { |rule| normalized_text.match?(rule.fetch(:pattern)) }
    end

    def lifecycle_verdict(match)
      rule = match.fetch(:rule)
      candidate = normalize(match.fetch(:target_candidate))
      matches = find_matching_tasks(candidate)

      return Verdict.clarification_needed(
        intent_label: rule.fetch(:intent_label),
        original_text:,
        reply_text: rule.fetch(:clarification_message)
      ) unless matches.one?

      Verdict.pending_executor(
        intent_label: rule.fetch(:intent_label),
        original_text:,
        reply_text: rule.fetch(:pending_message),
        target_reference: {
          task_id: matches.first.id,
          body: matches.first.body
        }
      )
    end

    def find_matching_tasks(candidate)
      task_reader.all.select { |task| normalize(task.body) == candidate }
    end

    def matched_lifecycle_rule
      LIFECYCLE_RULES.each do |rule|
        match_data = normalized_text.match(rule.fetch(:pattern))
        next unless match_data

        return { rule:, target_candidate: match_data[1] }
      end

      nil
    end

    def mixed_intent?
      return true if retrieval_marker? && lifecycle_marker_count.positive?
      return false unless retrieval_marker?

      normalized_text.match?(/\sи\s/) && !retrieval_intent?
    end

    def mixed_intent_verdict
      Verdict.clarification_needed(
        intent_label: :none,
        original_text:,
        reply_text: MIXED_INTENT_REPLY
      )
    end

    def normalize(text)
      text.to_s.downcase.squish.sub(/[[:punct:]]+\z/, "")
    end

    def retrieval_intent?
      RETRIEVAL_PATTERNS.any? { |pattern| normalized_text.match?(pattern) }
    end

    def retrieval_marker?
      normalized_text.include?("задачи") || normalized_text.include?("что у меня")
    end

    def retrieval_verdict
      Verdict.handoff(
        intent_label: :list_open_tasks,
        downstream: :list_open_tasks,
        original_text:
      )
    end
  end
end
