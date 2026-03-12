class ClaimAssessment < ApplicationRecord
  broadcasts_refreshes_to :investigation

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
  has_many :verdict_snapshots, dependent: :destroy

  def record_verdict_change!(new_verdict:, new_confidence:, new_reason:, trigger:, triggered_by: nil)
    should_snapshot = verdict_snapshots.none? || verdict.to_s != new_verdict.to_s

    if should_snapshot
      verdict_snapshots.create!(
        verdict: new_verdict,
        previous_verdict: verdict_snapshots.any? ? verdict : nil,
        confidence_score: new_confidence,
        reason_summary: new_reason.to_s.truncate(500),
        trigger: trigger,
        triggered_by: triggered_by
      )
    end

    update!(
      verdict: new_verdict,
      confidence_score: new_confidence,
      reason_summary: new_reason
    )
  end

  def verdict_changed_count
    verdict_snapshots.verdict_changes.count
  end
end
