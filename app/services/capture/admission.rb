module Capture
  class Admission
    VERB_PATTERN = /\A[\p{L}-]+(?:ть|ти|чь)\z/i
    QUESTION_WORDS = %w[что где когда зачем почему какой какая какие сколько].freeze
    NOTE_PATTERN = /\Aу\s+\p{L}+/i

    Decision = Struct.new(:supported?, :normalized_text, :reason, :hint, keyword_init: true)

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text.to_s.strip
    end

    def call
      return reject_blank if text.empty?
      return reject_question if question?
      return reject_alternative if alternative?
      return reject_reminder if reminder?
      return reject_multiple_actions if multiple_actions?
      return reject_non_task unless leading_infinitive?

      Decision.new(supported?: true, normalized_text: text)
    end

    private

    attr_reader :text

    def reject_blank
      rejected(
        reason: "В сообщении нет задачи для сохранения.",
        hint: "Сформулируйте одно короткое действие, например: купить молоко."
      )
    end

    def reject_question
      rejected(
        reason: "Похоже на вопрос, а не на задачу.",
        hint: "Переформулируйте сообщение как одно действие без вопросительной формы."
      )
    end

    def reject_alternative
      rejected(
        reason: "В сообщении есть альтернатива, и система не может выбрать один вариант.",
        hint: "Оставьте одно конкретное действие без вариантов 'или'."
      )
    end

    def reject_reminder
      rejected(
        reason: "Похоже на напоминание, а не на простую задачу первого MVP.",
        hint: "Уберите формулировку напоминания и оставьте только одно действие."
      )
    end

    def reject_multiple_actions
      rejected(
        reason: "В сообщении больше одного действия.",
        hint: "Разбейте сообщение на одну задачу за раз."
      )
    end

    def reject_non_task
      rejected(
        reason: "Не удалось уверенно распознать одно явное действие.",
        hint: "Начните сообщение с одного действия, например: позвонить маме."
      )
    end

    def rejected(reason:, hint:)
      Decision.new(supported?: false, reason: reason, hint: hint)
    end

    def question?
      text.include?("?") || QUESTION_WORDS.include?(words.first&.downcase)
    end

    def alternative?
      words.any? { |word| word.casecmp("или").zero? }
    end

    def reminder?
      words.first&.casecmp("напомни")&.zero?
    end

    def multiple_actions?
      infinitives.count > 1
    end

    def leading_infinitive?
      return false if NOTE_PATTERN.match?(text)

      infinitives.one? && infinitives.first == words.first
    end

    def infinitives
      @infinitives ||= words.select { |word| VERB_PATTERN.match?(word) }
    end

    def words
      @words ||= text.downcase.scan(/\p{L}+/)
    end
  end
end
