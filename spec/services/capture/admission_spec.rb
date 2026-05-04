require "rails_helper"

RSpec.describe Capture::Admission do
  describe ".call" do
    it "supports a single explicit task action" do
      decision = described_class.call("купить молоко")

      expect(decision.supported?).to be(true)
      expect(decision.normalized_text).to eq("купить молоко")
    end

    it "rejects the FT-001 unsupported corpus and records evidence" do
      corpus = {
        "купить молоко и позвонить маме" => "В сообщении больше одного действия.",
        "или купить билеты, или поехать на машине" => "В сообщении есть альтернатива, и система не может выбрать один вариант.",
        "что у меня на завтра?" => "Похоже на вопрос, а не на задачу.",
        "у Маши новый номер" => "Не удалось уверенно распознать одно явное действие.",
        "напомни завтра купить молоко" => "Похоже на напоминание, а не на простую задачу первого MVP."
      }

      results = corpus.each_with_object({}) do |(text, expected_reason), memo|
        decision = described_class.call(text)

        expect(decision.supported?).to be(false)
        expect(decision.reason).to eq(expected_reason)

        memo[text] = { reason: decision.reason, hint: decision.hint }
      end

      write_evidence("chk-02/admission-corpus.json", results)
    end
  end
end
