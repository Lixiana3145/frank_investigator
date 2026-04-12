require "test_helper"
require "yaml"

class LocaleCoverageTest < ActiveSupport::TestCase
  APP_GLOBS = %w[app/**/*.rb app/**/*.erb].freeze
  TRANSLATION_CALL_RE = /(?<![[:alnum:]_])(?:I18n\.)?t\(\s*["']([^"']+)["']/.freeze

  test "english and portuguese locale trees have the same leaf keys" do
    en_keys = flattened_leaf_keys(locale_tree("en"))
    pt_keys = flattened_leaf_keys(locale_tree("pt-BR"))

    assert_equal en_keys, pt_keys
  end

  test "all literal app translation keys exist in english and portuguese" do
    extract_literal_translation_keys.each do |key|
      assert I18n.exists?(key, :en), "missing en key #{key}"
      assert I18n.exists?(key, :"pt-BR"), "missing pt-BR key #{key}"
    end
  end

  private

  def locale_tree(locale)
    YAML.load_file(Rails.root.join("config/locales/#{locale}.yml"))[locale]
  end

  def flattened_leaf_keys(obj, prefix = [], out = [])
    case obj
    when Hash
      obj.each { |key, value| flattened_leaf_keys(value, prefix + [ key.to_s ], out) }
    else
      out << prefix.join(".")
    end

    out.sort
  end

  def extract_literal_translation_keys
    APP_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }
      .filter_map do |path|
        extract_keys_from_file(path)
      end
      .flatten
      .uniq
      .sort
  end

  def extract_keys_from_file(path)
    content = File.read(path)

    content.scan(TRANSLATION_CALL_RE).flatten.filter_map do |key|
      next if key.include?("#\{")

      if key.start_with?(".")
        resolve_relative_key(path, key)
      else
        key
      end
    end
  end

  def resolve_relative_key(path, key)
    return unless path.include?("/app/views/")

    relative_path = path.split("/app/views/").last
    parts = relative_path.split("/")
    basename = parts.pop
    stem = basename.sub(/\..*\z/, "").delete_prefix("_")

    (parts + [ stem, key.delete_prefix(".") ]).join(".")
  end
end
