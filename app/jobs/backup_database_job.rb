class BackupDatabaseJob < ApplicationJob
  queue_as :default

  NIGHT_HOURS = (0..7)

  def perform
    hour = Time.current.in_time_zone("America/Sao_Paulo").hour
    return if NIGHT_HOURS.cover?(hour) && hour.odd?

    backup_dir = "/content/backups"
    FileUtils.mkdir_p(backup_dir)

    dest = File.join(backup_dir, "frank_investigator.sqlite3")
    ActiveRecord::Base.connection.execute("VACUUM INTO '#{dest}'")

    Rails.logger.info("[BackupDatabaseJob] Backed up to #{dest} (#{File.size(dest)} bytes)")
  end
end
