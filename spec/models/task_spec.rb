require "rails_helper"

RSpec.describe Task, type: :model do
  it "requires the minimal FT-001 persistence contract" do
    task = described_class.new

    expect(task).not_to be_valid
    expect(task.errors.attribute_names).to contain_exactly(
      :body,
      :source_text,
      :operation_id,
      :status
    )
  end

  it "accepts an open task with source text and operation id" do
    task = described_class.new(
      body: "купить молоко",
      source_text: "купить молоко",
      operation_id: SecureRandom.uuid,
      status: "open"
    )

    expect(task).to be_valid
  end
end
