require "test_helper"

class Investigations::DetectSelectiveQuotationJobTest < ActiveSupport::TestCase
  test "stores result on investigation" do
    root = Article.create!(
      url: "https://sqjob.com/article", normalized_url: "https://sqjob.com/article",
      host: "sqjob.com", fetch_status: :fetched,
      body_text: 'The minister said "we will consider raising taxes" during the press conference.',
      title: "Minister Tax Quote"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectSelectiveQuotationJob.perform_now(investigation.id)

    investigation.reload
    assert investigation.selective_quotation.present?
    assert investigation.selective_quotation.key?("quotations")
    assert investigation.selective_quotation.key?("quotation_integrity_score")
    assert investigation.selective_quotation.key?("summary")
  end

  test "creates pipeline step" do
    root = Article.create!(
      url: "https://sqjob2.com/article", normalized_url: "https://sqjob2.com/article",
      host: "sqjob2.com", fetch_status: :fetched,
      body_text: "Content.", title: "Test"
    )
    investigation = Investigation.create!(
      submitted_url: root.url, normalized_url: root.normalized_url,
      root_article: root, status: :processing
    )

    Investigations::DetectSelectiveQuotationJob.perform_now(investigation.id)

    step = investigation.pipeline_steps.find_by(name: "detect_selective_quotation")
    assert_equal "completed", step.status
  end
end
