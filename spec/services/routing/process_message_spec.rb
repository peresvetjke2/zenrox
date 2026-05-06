require "rails_helper"

RSpec.describe Routing::ProcessMessage do
  describe ".call" do
    it "routes supported capture and retrieval inputs to the proper downstream handoff" do
      corpus = {
        "купить молоко" => { intent_label: :capture_task, resolution_status: :handoff, downstream: :capture_task },
        "что у меня открыто?" => { intent_label: :list_open_tasks, resolution_status: :handoff, downstream: :list_open_tasks },
        "покажи задачи" => { intent_label: :list_open_tasks, resolution_status: :handoff, downstream: :list_open_tasks }
      }

      results = corpus.each_with_object({}) do |(text, expected), memo|
        verdict = described_class.call(text:)

        expect(verdict.intent_label).to eq(expected.fetch(:intent_label))
        expect(verdict.resolution_status).to eq(expected.fetch(:resolution_status))
        expect(verdict.downstream).to eq(expected.fetch(:downstream))

        memo[text] = {
          intent_label: verdict.intent_label,
          resolution_status: verdict.resolution_status,
          downstream: verdict.downstream
        }
      end

      write_evidence("chk-01/routing-supported.json", results, feature: "ft-004")
    end

    it "returns lifecycle verdicts without capture or retrieval handoff and keeps executor pending" do
      task = Task.create!(
        body: "купить молоко",
        source_text: "купить молоко",
        operation_id: "ft-004-lifecycle-1",
        status: "open"
      )

      done_verdict = described_class.call(text: "закрой купить молоко")
      reopen_verdict = described_class.call(text: "верни в работу купить молоко")
      delete_verdict = described_class.call(text: "удали купить молоко")

      [ done_verdict, reopen_verdict, delete_verdict ].each do |verdict|
        expect(verdict.resolution_status).to eq(:pending_executor)
        expect(verdict.downstream).to be_nil
        expect(verdict.target_reference).to eq({ task_id: task.id, body: "купить молоко" })
      end

      write_evidence(
        "chk-02/routing-lifecycle.json",
        {
          task: task.attributes.slice("id", "body", "status"),
          verdicts: {
            done: verdict_snapshot(done_verdict),
            reopen: verdict_snapshot(reopen_verdict),
            delete: verdict_snapshot(delete_verdict)
          }
        },
        feature: "ft-004"
      )

      write_evidence(
        "chk-05/routing-pending-executor.json",
        {
          before_statuses: Task.order(:id).pluck(:id, :status, :body),
          verdicts: {
            done: done_verdict.reply_text,
            reopen: reopen_verdict.reply_text,
            delete: delete_verdict.reply_text
          },
          after_statuses: Task.order(:id).pluck(:id, :status, :body)
        },
        feature: "ft-004"
      )
    end

    it "returns clarification or unsupported verdicts for mixed, ambiguous and out-of-scope inputs" do
      Task.create!(
        body: "купить молоко",
        source_text: "купить молоко",
        operation_id: "ft-004-duplicate-1",
        status: "open"
      )
      Task.create!(
        body: "купить молоко",
        source_text: "купить молоко",
        operation_id: "ft-004-duplicate-2",
        status: "done"
      )

      mixed_verdict = described_class.call(text: "покажи задачи и закрой первую")
      capture_retrieval_mixed = described_class.call(text: "добавь купить молоко и покажи задачи")
      unsupported_verdict = described_class.call(text: "что я говорил про корову месяц назад?")
      delete_verdict = described_class.call(text: "удали купить молоко")

      expect(mixed_verdict).to have_attributes(intent_label: :none, resolution_status: :clarification_needed)
      expect(capture_retrieval_mixed).to have_attributes(intent_label: :none, resolution_status: :clarification_needed)
      expect(unsupported_verdict).to have_attributes(intent_label: :none, resolution_status: :unsupported)
      expect(delete_verdict).to have_attributes(intent_label: :delete_task, resolution_status: :clarification_needed)

      write_evidence(
        "chk-03/routing-safety.json",
        {
          mixed: verdict_snapshot(mixed_verdict),
          capture_retrieval_mixed: verdict_snapshot(capture_retrieval_mixed),
          unsupported: verdict_snapshot(unsupported_verdict)
        },
        feature: "ft-004"
      )

      write_evidence(
        "chk-06/routing-delete-clarification.json",
        {
          task_bodies: Task.order(:id).pluck(:body, :status),
          verdict: verdict_snapshot(delete_verdict)
        },
        feature: "ft-004"
      )
    end

    def verdict_snapshot(verdict)
      {
        intent_label: verdict.intent_label,
        resolution_status: verdict.resolution_status,
        downstream: verdict.downstream,
        reply_text: verdict.reply_text,
        target_reference: verdict.target_reference
      }
    end
  end
end
