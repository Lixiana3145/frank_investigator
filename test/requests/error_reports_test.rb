require "test_helper"

class ErrorReportsTest < ActionDispatch::IntegrationTest
  setup do
    @auth_headers = {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin")
    }
    @report = ErrorReport.create!(
      error_class: "RuntimeError",
      message: "test error",
      fingerprint: "test_fp_#{SecureRandom.hex(4)}",
      severity: "error",
      source: "test",
      first_occurred_at: Time.current,
      last_occurred_at: Time.current
    )
  end

  test "index requires authentication" do
    get error_reports_path
    assert_response :unauthorized
  end

  test "index returns 200 with auth" do
    get error_reports_path, headers: @auth_headers
    assert_response :ok
    assert_includes response.body, "RuntimeError"
  end

  test "show returns error detail" do
    get error_report_path(@report), headers: @auth_headers
    assert_response :ok
    assert_includes response.body, "test error"
  end

  test "destroy_all clears all reports" do
    assert ErrorReport.any?
    delete destroy_all_error_reports_path, headers: @auth_headers
    assert_response :redirect
    assert_equal 0, ErrorReport.count
  end
end
