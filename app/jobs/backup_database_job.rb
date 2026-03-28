class BackupDatabaseJob < ApplicationJob
  queue_as :default

  def perform
    backup_dir = "/content/backups"
    FileUtils.mkdir_p(backup_dir)

    dest = File.join(backup_dir, "frank_investigator.sqlite3")
    ActiveRecord::Base.connection.execute("VACUUM INTO '#{dest}'")

    Rails.logger.info("[BackupDatabaseJob] Backed up to #{dest} (#{File.size(dest)} bytes)")
  end
end
