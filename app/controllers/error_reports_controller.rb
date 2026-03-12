class ErrorReportsController < ApplicationController
  http_basic_authenticate_with(
    name: ENV.fetch("JOBS_AUTH_USER", "admin"),
    password: ENV.fetch("JOBS_AUTH_PASSWORD", "admin")
  )

  def index
    @error_reports = ErrorReport.recent.limit(100)
  end

  def show
    @error_report = ErrorReport.find(params[:id])
  end

  def destroy_all
    ErrorReport.delete_all
    redirect_to error_reports_path, notice: t("error_reports.notices.cleared")
  end
end
