class ErrorReport < ApplicationRecord
  validates :error_class, :message, :fingerprint, :severity, presence: true

  scope :recent, -> { order(last_occurred_at: :desc) }
  scope :errors_only, -> { where(severity: "error") }

  RETENTION_DAYS = 30

  def self.purge_old
    where("last_occurred_at < ?", RETENTION_DAYS.days.ago).delete_all
  end
end
