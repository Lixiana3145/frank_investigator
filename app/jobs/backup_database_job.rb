class BackupDatabaseJob < ApplicationJob
  queue_as :default
  BACKUP_PATH = "/content/backups/frank_investigator.sqlite3".freeze

  def perform
    FileUtils.mkdir_p(File.dirname(BACKUP_PATH))

    ActiveRecord::Base.connection.execute("VACUUM INTO '/content/backups/frank_investigator.sqlite3'")

    Rails.logger.info("[BackupDatabaseJob] Backed up to #{BACKUP_PATH} (#{File.size(BACKUP_PATH)} bytes)")
  end
end
