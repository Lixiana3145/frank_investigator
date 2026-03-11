class ClaimAssessment < ApplicationRecord
  enum :verdict, {
    pending: "pending",
    supported: "supported",
    disputed: "disputed",
    mixed: "mixed",
    needs_more_evidence: "needs_more_evidence",
    not_checkable: "not_checkable"
  }, default: :pending, validate: true, prefix: :verdict

  enum :checkability_status, {
    pending: "pending",
    checkable: "checkable",
    ambiguous: "ambiguous",
    not_checkable: "not_checkable"
  }, default: :pending, validate: true, prefix: :checkability

  belongs_to :investigation
  belongs_to :claim

  has_many :evidence_items, dependent: :destroy
  has_many :llm_interactions, dependent: :nullify
end
