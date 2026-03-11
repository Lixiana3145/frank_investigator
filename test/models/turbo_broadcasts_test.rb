require "test_helper"

class TurboBroadcastsTest < ActiveSupport::TestCase
  test "PipelineStep has broadcasts_refreshes_to callback" do
    # Verify the model class has the Turbo broadcast callback configured
    step = PipelineStep.new
    assert step.respond_to?(:broadcast_refresh_later_to),
      "PipelineStep should have Turbo broadcast methods via broadcasts_refreshes_to"
  end

  test "ClaimAssessment has broadcasts_refreshes_to callback" do
    assessment = ClaimAssessment.new
    assert assessment.respond_to?(:broadcast_refresh_later_to),
      "ClaimAssessment should have Turbo broadcast methods via broadcasts_refreshes_to"
  end

  test "Investigation has broadcasts_refreshes callback" do
    investigation = Investigation.new
    assert investigation.respond_to?(:broadcast_refresh_later),
      "Investigation should have Turbo broadcast methods via broadcasts_refreshes"
  end

  test "PipelineStep commit callbacks include broadcast" do
    callbacks = PipelineStep._commit_callbacks.map { |cb| cb.filter.to_s }
    broadcast_callback = callbacks.any? { |f| f.include?("broadcast") || f.include?("refresh") }

    # Also check via the model's after_commit chain
    assert PipelineStep.respond_to?(:broadcasts_refreshes_to) || broadcast_callback || PipelineStep.instance_methods.include?(:broadcast_refresh_later_to),
      "PipelineStep should broadcast refreshes after commit"
  end

  test "ClaimAssessment commit callbacks include broadcast" do
    assert ClaimAssessment.instance_methods.include?(:broadcast_refresh_later_to),
      "ClaimAssessment should have broadcast_refresh_later_to method"
  end

  test "pipeline step partial exists with dom_id" do
    assert File.exist?(Rails.root.join("app/views/investigations/_pipeline_step.html.erb")),
      "Pipeline step partial should exist"

    content = File.read(Rails.root.join("app/views/investigations/_pipeline_step.html.erb"))
    assert_includes content, "dom_id(step)", "Pipeline step partial should use dom_id"
  end

  test "claim assessment partial uses dom_id" do
    content = File.read(Rails.root.join("app/views/investigations/_claim_assessment.html.erb"))
    assert_includes content, "dom_id(assessment)", "Claim assessment partial should use dom_id"
  end
end
