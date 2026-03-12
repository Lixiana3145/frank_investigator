class VerdictSnapshot < ApplicationRecord
  belongs_to :claim_assessment

  validates :verdict, :trigger, presence: true

  scope :chronological, -> { order(created_at: :asc) }
  scope :verdict_changes, -> { where("previous_verdict IS NOT NULL AND previous_verdict != verdict") }
end
