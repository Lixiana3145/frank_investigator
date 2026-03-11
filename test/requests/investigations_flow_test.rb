require "test_helper"

class InvestigationsFlowTest < ActionDispatch::IntegrationTest
  test "renders the homepage" do
    get root_path

    assert_response :success
    assert_includes response.body, "Investigate a news article"
  end

  test "redirects submitted urls to the normalized canonical query param" do
    get root_path, params: { url: "HTTPS://Example.COM/news?id=2&a=1#fragment" }

    assert_redirected_to "/?url=https%3A%2F%2Fexample.com%2Fnews%3Fa%3D1%26id%3D2"
  end

  test "creates an investigation for a normalized url" do
    assert_enqueued_with(job: Investigations::KickoffJob) do
      get root_path, params: { url: "https://example.com/news" }
    end

    assert_response :success
    assert_equal "https://example.com/news", Investigation.last.normalized_url
    assert_includes response.body, "turbo-cable-stream-source"
  end
end
