class Article < ApplicationRecord
  enum :fetch_status, {
    pending: "pending",
    fetched: "fetched",
    failed: "failed"
  }, default: :pending, validate: true

  has_many :article_claims, dependent: :destroy
  has_many :claims, through: :article_claims
  has_many :sourced_links, class_name: "ArticleLink", foreign_key: :source_article_id, inverse_of: :source_article, dependent: :destroy
  has_many :targeted_links, class_name: "ArticleLink", foreign_key: :target_article_id, inverse_of: :target_article, dependent: :destroy
  has_many :evidence_items, dependent: :nullify

  validates :url, :normalized_url, :host, presence: true
end
