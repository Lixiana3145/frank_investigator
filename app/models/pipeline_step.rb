class PipelineStep < ApplicationRecord
  broadcasts_refreshes_to :investigation

  enum :status, {
    queued: "queued",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: :queued, validate: true

  belongs_to :investigation

  validates :name, presence: true
end
