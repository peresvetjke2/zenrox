require "rails_helper"

RSpec.describe Retrieval::ListOpenTasks do
  describe ".call" do
    it "returns all open tasks in stable oldest-first order and excludes done tasks" do
      first_open = Task.create!(
        body: "купить молоко",
        source_text: "купить молоко",
        operation_id: "ft-002-open-1",
        status: "open"
      )
      Task.create!(
        body: "позвонить маме",
        source_text: "позвонить маме",
        operation_id: "ft-002-done-1",
        status: "done"
      )
      second_open = Task.create!(
        body: "записаться к врачу",
        source_text: "записаться к врачу",
        operation_id: "ft-002-open-2",
        status: "open"
      )

      result = described_class.call

      expect(result).not_to be_failure
      expect(result).not_to be_empty
      expect(result.tasks).to eq([ first_open, second_open ])
      expect(result.message).to eq(
        <<~TEXT.chomp
          Открытые задачи:
          - купить молоко
          - записаться к врачу
        TEXT
      )

      write_evidence(
        "chk-01/mixed-open-tasks.json",
        {
          task_ids: result.tasks.map(&:id),
          task_bodies: result.tasks.map(&:body),
          reply: result.message
        },
        feature: "ft-002"
      )
    end

    it "returns the empty-state verdict without mutating storage" do
      Task.create!(
        body: "готово",
        source_text: "готово",
        operation_id: "ft-002-done-only",
        status: "done"
      )

      before_snapshot = Task.order(:id).pluck(:id, :status, :body)

      result = nil

      expect do
        result = described_class.call
      end.not_to change(Task, :count)

      expect(result).to be_empty
      expect(result.message).to eq("Открытых задач нет.")
      expect(Task.order(:id).pluck(:id, :status, :body)).to eq(before_snapshot)

      write_evidence(
        "chk-02/empty-open-tasks.json",
        {
          before: before_snapshot,
          after: Task.order(:id).pluck(:id, :status, :body),
          reply: result.message
        },
        feature: "ft-002"
      )
    end

    it "returns the failure verdict when task reading fails" do
      failing_reader = Class.new do
        def self.open_for_retrieval
          raise ActiveRecord::ActiveRecordError, "read failed"
        end
      end

      before_snapshot = Task.order(:id).pluck(:id, :status, :body)
      result = nil

      expect do
        result = described_class.call(reader: failing_reader)
      end.not_to change(Task, :count)

      expect(result).to be_failure
      expect(result.message).to eq("Не удалось получить список открытых задач.")
      expect(Task.order(:id).pluck(:id, :status, :body)).to eq(before_snapshot)

      write_evidence(
        "chk-05/read-failure.json",
        {
          before: before_snapshot,
          after: Task.order(:id).pluck(:id, :status, :body),
          reply: result.message
        },
        feature: "ft-002"
      )
    end

    it "does not mask unexpected runtime errors as retrieval failures" do
      buggy_reader = Class.new do
        def self.open_for_retrieval
          raise ArgumentError, "bug"
        end
      end

      expect do
        described_class.call(reader: buggy_reader)
      end.to raise_error(ArgumentError, "bug")
    end
  end
end
