module Routing
  class Verdict
    attr_reader :downstream, :intent_label, :original_text, :reply_text, :resolution_status, :target_reference

    def initialize(intent_label:, resolution_status:, original_text:, downstream: nil, reply_text: nil, target_reference: nil)
      @intent_label = intent_label
      @resolution_status = resolution_status
      @original_text = original_text
      @downstream = downstream
      @reply_text = reply_text
      @target_reference = target_reference
    end

    def self.handoff(intent_label:, downstream:, original_text:)
      new(
        intent_label:,
        resolution_status: :handoff,
        downstream:,
        original_text:
      )
    end

    def self.clarification_needed(intent_label:, original_text:, reply_text:, target_reference: nil)
      new(
        intent_label:,
        resolution_status: :clarification_needed,
        original_text:,
        reply_text:,
        target_reference:
      )
    end

    def self.pending_executor(intent_label:, original_text:, reply_text:, target_reference:)
      new(
        intent_label:,
        resolution_status: :pending_executor,
        original_text:,
        reply_text:,
        target_reference:
      )
    end

    def self.unsupported(original_text:, reply_text:)
      new(
        intent_label: :none,
        resolution_status: :unsupported,
        original_text:,
        reply_text:
      )
    end

    def handoff?
      resolution_status == :handoff
    end
  end
end
