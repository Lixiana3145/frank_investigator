Rails.application.configure do
  config.mission_control.jobs.http_basic_auth_enabled = true
  config.mission_control.jobs.http_basic_auth_user = ENV.fetch("JOBS_AUTH_USER", "admin")
  config.mission_control.jobs.http_basic_auth_password = ENV.fetch("JOBS_AUTH_PASSWORD", "admin")
end
