module Api
  class InvestigationsController < ActionController::API
    before_action :authenticate_api_token!

    def create
      url = params[:url].to_s.strip

      if url.blank?
        return render json: { error: "url is required" }, status: :unprocessable_entity
      end

      if url.length > 2048
        return render json: { error: "url too long (max 2048)" }, status: :unprocessable_entity
      end

      normalized_url = Investigations::UrlNormalizer.call(url)
      Investigations::UrlClassifier.call(normalized_url)

      investigation = Investigations::EnsureStarted.call(submitted_url: normalized_url)

      render json: {
        slug: investigation.slug,
        status: investigation.status,
        url: investigation.normalized_url,
        report_url: investigation_url(investigation)
      }, status: :created
    rescue Investigations::UrlNormalizer::InvalidUrlError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue Investigations::UrlClassifier::RejectedUrlError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def authenticate_api_token!
      secret = ENV["FRANK_AUTH_SECRET"]
      return render_unauthorized("FRANK_AUTH_SECRET not configured") if secret.blank?

      token = request.headers["Authorization"]&.sub(/\ABearer\s+/i, "")
      render_unauthorized("Invalid or missing token") unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, secret)
    end

    def render_unauthorized(message)
      render json: { error: message }, status: :unauthorized
    end
  end
end
