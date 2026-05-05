class Task < ApplicationRecord
  STATUSES = %w[open done].freeze

  scope :open_for_retrieval, -> { where(status: "open").order(:id) }

  validates :body, presence: true
  validates :source_text, presence: true
  validates :operation_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
