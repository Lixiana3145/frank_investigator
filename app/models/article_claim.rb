class ArticleClaim < ApplicationRecord
  enum :role, {
    headline: "headline",
    lead: "lead",
    body: "body",
    supporting: "supporting",
    linked_source: "linked_source"
  }, default: :body, validate: true

  enum :stance, {
    repeats: "repeats",
    supports: "supports",
    disputes: "disputes",
    references: "references"
  }, default: :repeats, validate: true

  belongs_to :article
  belongs_to :claim

  validates :surface_text, presence: true
end
