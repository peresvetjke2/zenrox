module Routing
  class ProcessMessage
    LEADING_FILLER_WORDS = %w[можешь можете можно пожалуйста плиз прошу давай].freeze
    TRAILING_FILLER_WORDS = %w[пожалуйста плиз].freeze
    TASK_NOUNS = %w[задача задачи задачу задач задачам задачами задачах дел дело дела делам делами делах].freeze
    RETRIEVAL_REQUEST_WORDS = %w[что какие покажи показать список перечисли мои].freeze
    OPEN_STATE_WORDS = %w[открыто открытые открытых открытым открытыми].freeze
    LIFECYCLE_OBJECT_WORDS = %w[задача задачу задачи дело дела].freeze
    GENERIC_TARGET_WORDS = %w[это эту этот эту-то это-то задачу задача задачи дело дела первую первый первое все всё].freeze
    CAPTURE_HINT_WORDS = %w[добавь добавьте запиши запишите создай создайте внеси внесите].freeze

    LIFECYCLE_RULES = [
      {
        intent_label: :mark_task_done,
        pattern: /\A(?:закрой|закрыть|заверши|завершить|отметь(?:\s+как)?(?:\s+выполненн(?:ой|ым))?|отметить(?:\s+как)?(?:\s+выполненн(?:ой|ым))?|сделал|сделано|готово|готова|готов|выполнено)\b(?:\s+(.+))?\z/i,
        pending_message: "Не выполнил действие: задачу для завершения удалось определить, но автоматическое закрытие пока не реализовано.",
        clarification_message: "Не выполнил действие: уточните, какую задачу нужно завершить."
      },
      {
        intent_label: :reopen_task,
        pattern: /\A(?:верни(?:\s+обратно)?\s+в\s+работу|вернуть(?:\s+обратно)?\s+в\s+работу|переоткрой|переоткрыть|снова\s+открой|открой\s+снова)\b(?:\s+(.+))?\z/i,
        pending_message: "Не выполнил действие: задачу для возврата в работу удалось определить, но автоматическое переоткрытие пока не реализовано.",
        clarification_message: "Не выполнил действие: уточните, какую задачу нужно вернуть в работу."
      },
      {
        intent_label: :delete_task,
        pattern: /\A(?:удали|удалить|убери|стереть)\b(?:\s+(.+))?\z/i,
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
      @matchable_text = strip_edge_fillers(@normalized_text)
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

    attr_reader :capture_admission, :matchable_text, :normalized_text, :original_text, :task_reader

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
      @lifecycle_marker_count ||= LIFECYCLE_RULES.count { |rule| matchable_text.match?(rule.fetch(:pattern)) }
    end

    def lifecycle_verdict(match)
      rule = match.fetch(:rule)
      candidate = normalize_target(match.fetch(:target_candidate))
      return lifecycle_clarification(rule:, clarification_reason: :missing_target) if candidate.blank?
      return lifecycle_clarification(rule:, clarification_reason: :missing_target) if generic_target?(candidate)

      matches = find_matching_tasks(candidate)

      return lifecycle_clarification(rule:, clarification_reason: :missing_target) if matches.empty?
      return lifecycle_clarification(rule:, clarification_reason: :ambiguous_target) unless matches.one?

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
      task_reader.all.select { |task| normalize_target(task.body) == candidate }
    end

    def generic_target?(candidate)
      target_tokens = tokenize(candidate)
      return true if target_tokens.empty?

      target_tokens.all? { |token| GENERIC_TARGET_WORDS.include?(token) || LIFECYCLE_OBJECT_WORDS.include?(token) }
    end

    def matched_lifecycle_rule
      LIFECYCLE_RULES.each do |rule|
        match_data = matchable_text.match(rule.fetch(:pattern))
        next unless match_data

        return { rule:, target_candidate: match_data[1] }
      end

      nil
    end

    def mixed_intent?
      families = []
      families << :retrieval if retrieval_intent?
      families << :lifecycle if lifecycle_marker_count.positive?
      families << :capture if capture_decision.supported?

      return true if families.uniq.size > 1

      clauses = split_clauses
      return false unless clauses.size > 1

      clause_families = clauses.filter_map { |clause| weak_clause_family(clause) }.uniq
      clause_families.size > 1
    end

    def mixed_intent_verdict
      Verdict.clarification_needed(
        intent_label: :none,
        original_text:,
        reply_text: MIXED_INTENT_REPLY,
        clarification_reason: :mixed_intent
      )
    end

    def normalize(text)
      text.to_s.downcase.gsub(/[[:punct:]]+/, " ").squish
    end

    def normalize_target(text)
      stripped = strip_edge_fillers(normalize(text))
      tokens = tokenize(stripped)
      tokens.shift while tokens.first && LIFECYCLE_OBJECT_WORDS.include?(tokens.first)
      tokens.join(" ")
    end

    def retrieval_intent?
      return true if matchable_text == "задачи"
      return true if retrieval_query_text?
      return true if retrieval_list_noun_phrase?

      false
    end

    def retrieval_list_noun_phrase?
      retrieval_tokens = tokenize(matchable_text)
      retrieval_tokens.any? { |token| %w[мои список].include?(token) } &&
        retrieval_tokens.any? { |token| TASK_NOUNS.include?(token) }
    end

    def retrieval_query_text?
      retrieval_tokens = tokenize(matchable_text)
      has_task_noun = retrieval_tokens.any? { |token| TASK_NOUNS.include?(token) }
      has_retrieval_request = retrieval_tokens.any? { |token| RETRIEVAL_REQUEST_WORDS.include?(token) }
      mentions_open_state = retrieval_tokens.any? { |token| OPEN_STATE_WORDS.include?(token) }
      mentions_owned_tasks = matchable_text.include?("что у меня") || matchable_text.include?("какие у меня")

      return true if mentions_owned_tasks && mentions_open_state

      has_task_noun && (has_retrieval_request || mentions_open_state || mentions_owned_tasks)
    end

    def retrieval_verdict
      Verdict.handoff(
        intent_label: :list_open_tasks,
        downstream: :list_open_tasks,
        original_text:
      )
    end

    def lifecycle_clarification(rule:, clarification_reason:)
      Verdict.clarification_needed(
        intent_label: rule.fetch(:intent_label),
        original_text:,
        reply_text: rule.fetch(:clarification_message),
        clarification_reason:
      )
    end

    def split_clauses
      @split_clauses ||= matchable_text.split(/\s+(?:и|а)\s+/).map(&:strip).reject(&:blank?)
    end

    def strip_edge_fillers(text)
      tokens = tokenize(text)
      tokens.shift while tokens.first && LEADING_FILLER_WORDS.include?(tokens.first)
      tokens.pop while tokens.last && TRAILING_FILLER_WORDS.include?(tokens.last)
      tokens.join(" ")
    end

    def tokenize(text)
      text.to_s.scan(/\p{L}+/)
    end

    def weak_clause_family(clause)
      return :retrieval if retrieval_clause?(clause)
      return :lifecycle if lifecycle_clause?(clause)
      return :capture if capture_hint_clause?(clause)
      return :capture if capture_admission.call(clause).supported?

      nil
    end

    def retrieval_clause?(clause)
      clause_tokens = tokenize(clause)
      clause_tokens.any? { |token| TASK_NOUNS.include?(token) } &&
        clause_tokens.any? { |token| RETRIEVAL_REQUEST_WORDS.include?(token) || OPEN_STATE_WORDS.include?(token) }
    end

    def lifecycle_clause?(clause)
      LIFECYCLE_RULES.any? { |rule| clause.match?(rule.fetch(:pattern)) }
    end

    def capture_hint_clause?(clause)
      clause_tokens = tokenize(clause)
      first_token = clause_tokens.first
      return false unless first_token

      CAPTURE_HINT_WORDS.include?(first_token) || Capture::Admission::VERB_PATTERN.match?(first_token)
    end
  end
end
