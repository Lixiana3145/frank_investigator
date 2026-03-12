require "test_helper"

class SmearCampaignDefenseTest < ActiveSupport::TestCase
  EvidenceEntry = Struct.new(:stance, :relevance_score, :authority_score, :authority_tier,
                             :source_kind, :independence_group, :article, keyword_init: true)
  FakeArticle = Struct.new(:normalized_url, :title, :excerpt, :body_text, :host,
                           :fetched_at, :published_at, :id, :sourced_links, :authority_tier,
                           keyword_init: true)

  setup do
    @investigation = Investigation.create!(
      submitted_url: "https://example.com/smear-test",
      normalized_url: "https://example.com/smear-test-#{SecureRandom.hex(4)}",
      status: :processing
    )
    @claim = Claim.create!(
      canonical_text: "Celebrity X was caught doing something terrible",
      canonical_fingerprint: "smear_test_#{SecureRandom.hex(4)}",
      checkability_status: :checkable,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )
  end

  test "flags unsubstantiated viral when many secondaries support with no primary" do
    assessor = Analyzers::ClaimAssessor.new(investigation: @investigation, claim: @claim)

    entries = 5.times.map do |i|
      EvidenceEntry.new(
        stance: :supports, relevance_score: 0.8, authority_score: 0.5,
        authority_tier: "secondary", source_kind: "news_article",
        independence_group: "group_#{i}"
      )
    end

    assert assessor.send(:unsubstantiated_viral?, entries)
  end

  test "does not flag when primary source supports" do
    assessor = Analyzers::ClaimAssessor.new(investigation: @investigation, claim: @claim)

    entries = [
      EvidenceEntry.new(stance: :supports, authority_tier: "primary", relevance_score: 0.9, authority_score: 0.95),
      *3.times.map { EvidenceEntry.new(stance: :supports, authority_tier: "secondary", relevance_score: 0.7, authority_score: 0.5) }
    ]

    refute assessor.send(:unsubstantiated_viral?, entries)
  end

  test "does not flag when fewer than threshold secondaries" do
    assessor = Analyzers::ClaimAssessor.new(investigation: @investigation, claim: @claim)

    entries = 2.times.map do
      EvidenceEntry.new(stance: :supports, authority_tier: "secondary", relevance_score: 0.8, authority_score: 0.5)
    end

    refute assessor.send(:unsubstantiated_viral?, entries)
  end

  test "unsubstantiated viral caps confidence" do
    assessor = Analyzers::ClaimAssessor.new(investigation: @investigation, claim: @claim)

    confidence = assessor.send(:confidence_for,
      sufficiency_score: 0.9,
      authority_score: 0.7,
      independence_score: 0.8,
      timeliness_score: 0.9,
      weighted_support: 0.8,
      weighted_dispute: 0.0,
      citation_depth_score: 0.8,
      unsubstantiated_viral: true
    )

    assert_operator confidence, :<=, Analyzers::ClaimAssessor::UNSUBSTANTIATED_VIRAL_CONFIDENCE_CAP
  end

  test "confidence not capped when not viral" do
    assessor = Analyzers::ClaimAssessor.new(investigation: @investigation, claim: @claim)

    confidence = assessor.send(:confidence_for,
      sufficiency_score: 0.9,
      authority_score: 0.9,
      independence_score: 0.8,
      timeliness_score: 0.9,
      weighted_support: 0.9,
      weighted_dispute: 0.0,
      citation_depth_score: 1.0,
      unsubstantiated_viral: false
    )

    assert_operator confidence, :>, Analyzers::ClaimAssessor::UNSUBSTANTIATED_VIRAL_CONFIDENCE_CAP
  end
end
