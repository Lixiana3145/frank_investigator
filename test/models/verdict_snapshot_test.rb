require "test_helper"

class VerdictSnapshotTest < ActiveSupport::TestCase
  setup do
    @investigation = Investigation.create!(
      submitted_url: "https://example.com/verdict-test",
      normalized_url: "https://example.com/verdict-test-#{SecureRandom.hex(4)}",
      status: :processing
    )
    claim = Claim.create!(
      canonical_text: "Test claim for verdict history tracking and audit trail validation",
      canonical_fingerprint: "verdict_snap_#{SecureRandom.hex(4)}",
      checkability_status: :checkable,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )
    @assessment = ClaimAssessment.create!(
      investigation: @investigation,
      claim: claim,
      verdict: :pending,
      confidence_score: 0
    )
  end

  test "record_verdict_change creates initial snapshot" do
    @assessment.record_verdict_change!(
      new_verdict: :supported,
      new_confidence: 0.85,
      new_reason: "Evidence supports this claim",
      trigger: "initial_assessment",
      triggered_by: "AssessClaimsJob"
    )

    assert_equal 1, @assessment.verdict_snapshots.count
    snapshot = @assessment.verdict_snapshots.first
    assert_equal "supported", snapshot.verdict
    assert_nil snapshot.previous_verdict
    assert_equal "initial_assessment", snapshot.trigger
    assert_equal "AssessClaimsJob", snapshot.triggered_by
  end

  test "record_verdict_change tracks verdict changes" do
    @assessment.record_verdict_change!(
      new_verdict: :needs_more_evidence,
      new_confidence: 0.4,
      new_reason: "Not enough data",
      trigger: "initial_assessment"
    )

    @assessment.record_verdict_change!(
      new_verdict: :supported,
      new_confidence: 0.82,
      new_reason: "New evidence confirms",
      trigger: "reassessment"
    )

    assert_equal 2, @assessment.verdict_snapshots.count
    change = @assessment.verdict_snapshots.chronological.last
    assert_equal "supported", change.verdict
    assert_equal "needs_more_evidence", change.previous_verdict
  end

  test "record_verdict_change does not snapshot when verdict unchanged" do
    @assessment.record_verdict_change!(
      new_verdict: :supported,
      new_confidence: 0.85,
      new_reason: "Evidence supports",
      trigger: "initial_assessment"
    )

    @assessment.record_verdict_change!(
      new_verdict: :supported,
      new_confidence: 0.87,
      new_reason: "Still supported with more data",
      trigger: "reassessment"
    )

    assert_equal 1, @assessment.verdict_snapshots.count
  end

  test "verdict_changed_count returns correct count" do
    @assessment.record_verdict_change!(new_verdict: :supported, new_confidence: 0.8, new_reason: "yes", trigger: "initial_assessment")
    @assessment.record_verdict_change!(new_verdict: :disputed, new_confidence: 0.7, new_reason: "no", trigger: "reassessment")
    @assessment.record_verdict_change!(new_verdict: :supported, new_confidence: 0.9, new_reason: "yes again", trigger: "new_evidence")

    assert_equal 2, @assessment.verdict_changed_count
  end

  test "verdict_changes scope filters non-changes" do
    @assessment.verdict_snapshots.create!(verdict: "supported", previous_verdict: nil, trigger: "initial_assessment", confidence_score: 0.8)
    @assessment.verdict_snapshots.create!(verdict: "disputed", previous_verdict: "supported", trigger: "reassessment", confidence_score: 0.7)

    assert_equal 1, @assessment.verdict_snapshots.verdict_changes.count
  end
end
