require "test_helper"

class Sources::ProfileRegistryTest < ActiveSupport::TestCase
  test "loads the configured brazilian source profiles" do
    profiles = Sources::ProfileRegistry.all(region: :brazil)

    assert_operator profiles.count, :>=, 8
    assert profiles.any? { |profile| profile.key == "uol_noticias" }
    assert profiles.any? { |profile| profile.key == "g1" }
  end

  test "matches a configured brazilian host" do
    profile = Sources::ProfileRegistry.match("g1.globo.com")

    assert_equal "g1", profile.key
    assert_equal "globo.com", profile.independence_group
  end
end
