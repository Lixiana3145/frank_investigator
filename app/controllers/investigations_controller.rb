class InvestigationsController < ApplicationController
  def show
    @submitted_url = params[:url].to_s.strip
    return render :home if @submitted_url.blank?

    @normalized_url = Investigations::UrlNormalizer.call(@submitted_url)
    return redirect_to(root_path(url: @normalized_url), status: :see_other) if @submitted_url != @normalized_url

    @investigation = Investigations::EnsureStarted.call(submitted_url: @normalized_url)
  rescue Investigations::UrlNormalizer::InvalidUrlError => error
    @error_message = error.message
    render :home, status: :unprocessable_entity
  end
end
