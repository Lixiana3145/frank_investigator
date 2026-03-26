require "test_helper"

class Api::InvestigationsTest < ActionDispatch::IntegrationTest
  setup do
    @original_secret = ENV["FRANK_AUTH_SECRET"]
    ENV["FRANK_AUTH_SECRET"] = "test-secret-token"
  end

  teardown do
    ENV["FRANK_AUTH_SECRET"] = @original_secret
  end

  test "rejects requests without auth token" do
    post api_investigations_path, params: { url: "https://example.com/article" }, as: :json
    assert_response :unauthorized
  end

  test "rejects requests with wrong token" do
    post api_investigations_path,
      params: { url: "https://example.com/article" },
      headers: { "Authorization" => "Bearer wrong-token" },
      as: :json
    assert_response :unauthorized
  end

  test "rejects blank url" do
    post api_investigations_path,
      params: { url: "" },
      headers: { "Authorization" => "Bearer test-secret-token" },
      as: :json
    assert_response :unprocessable_entity
    assert_equal "url is required", response.parsed_body["error"]
  end

  test "creates investigation with valid token and url" do
    post api_investigations_path,
      params: { url: "https://example.com/api-test-article" },
      headers: { "Authorization" => "Bearer test-secret-token" },
      as: :json
    assert_response :created
    body = response.parsed_body
    assert body["slug"].present?
    assert_equal "https://example.com/api-test-article", body["url"]
    assert body["report_url"].present?
  end

  test "returns existing investigation for duplicate url" do
    2.times do
      post api_investigations_path,
        params: { url: "https://example.com/api-dup-test" },
        headers: { "Authorization" => "Bearer test-secret-token" },
        as: :json
    end
    # Both should return the same slug
    slugs = Investigation.where(normalized_url: "https://example.com/api-dup-test").pluck(:slug).uniq
    assert_equal 1, slugs.size
  end
end
