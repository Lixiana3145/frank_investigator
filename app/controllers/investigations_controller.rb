class InvestigationsController < ApplicationController
  MAX_URL_LENGTH = 2048

  def home
    @submitted_url = params[:url].to_s.strip
    return render :home if @submitted_url.blank?

    if @submitted_url.length > MAX_URL_LENGTH
      @error_message = "URL is too long (maximum #{MAX_URL_LENGTH} characters)"
      return render :home, status: :unprocessable_entity
    end

    @normalized_url = Investigations::UrlNormalizer.call(@submitted_url)
    return redirect_to(root_path(url: @normalized_url), status: :see_other) if @submitted_url != @normalized_url

    investigation = Investigations::EnsureStarted.call(submitted_url: @normalized_url)
    redirect_to investigation_path(investigation), status: :see_other
  rescue Investigations::UrlNormalizer::InvalidUrlError => error
    @error_message = error.message
    render :home, status: :unprocessable_entity
  end

  def show
    @investigation = Investigation.find(params[:id])
    @root_article = @investigation.root_article
    @checkable_claims = @investigation.claim_assessments
      .includes(claim: {}, evidence_items: :article)
      .where(checkability_status: "checkable")
      .order(confidence_score: :desc)
    @uncheckable_claims = @investigation.claim_assessments
      .includes(:claim)
      .where(checkability_status: %w[not_checkable ambiguous])
      .order(created_at: :asc)
    @pipeline_steps = @investigation.pipeline_steps.order(:created_at)
    @links = @root_article&.sourced_links&.includes(:target_article)&.order(:position) || []
  end

  def graph_data
    investigation = Investigation.find(params[:id])
    root = investigation.root_article

    nodes = []
    edges = []

    if root.present?
      nodes << node_hash(root, :root)

      root.sourced_links.includes(:target_article).each do |link|
        target = link.target_article
        nodes << node_hash(target, :source)
        edges << { source: root.id, target: target.id, label: link.anchor_text.to_s.truncate(40) }
      end

      investigation.claims.includes(:articles).each do |claim|
        claim_node_id = "claim_#{claim.id}"
        nodes << { id: claim_node_id, label: claim.canonical_text.truncate(60), kind: "claim", claim_kind: claim.claim_kind }
        claim.articles.each do |article|
          existing = nodes.find { |n| n[:id] == article.id }
          nodes << node_hash(article, :source) unless existing
          edges << { source: article.id, target: claim_node_id, label: "mentions" }
        end
      end
    end

    render json: { nodes: nodes.uniq { |n| n[:id] }, edges: }
  end

  private

  def node_hash(article, role)
    {
      id: article.id,
      label: article.title.presence || article.host,
      kind: role.to_s,
      host: article.host,
      source_kind: article.source_kind,
      authority_tier: article.authority_tier,
      authority_score: article.authority_score.to_f,
      source_role: article.source_role,
      fetch_status: article.fetch_status
    }
  end
end
