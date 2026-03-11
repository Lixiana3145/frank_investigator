class ArticleLink < ApplicationRecord
  enum :follow_status, {
    pending: "pending",
    crawled: "crawled",
    skipped: "skipped",
    failed: "failed"
  }, default: :pending, validate: true

  belongs_to :source_article, class_name: "Article", inverse_of: :sourced_links
  belongs_to :target_article, class_name: "Article", inverse_of: :targeted_links

  validates :href, presence: true
end
