namespace :frank do
  desc "Run full pipeline integration test with real Brazilian articles. Resets dev DB, fetches, analyzes, dumps JSON."
  task integration_brazil: :environment do
    require "fileutils"

    URLS = [
      "https://agenciabrasil.ebc.com.br/economia/noticia/2026-03/estimativas-do-mercado-para-inflacao-e-pib-ficam-estaveis",
      "https://www.poder360.com.br/poder-economia/fazenda-projeta-que-brasil-crescera-23-em-2026/",
      "https://www.infomoney.com.br/economia/pib-2026-o-ano-em-que-a-economia-nao-desaba-mas-tambem-nao-decola/"
    ].freeze

    OUTPUT_DIR = Rails.root.join("tmp/integration_reports")

    abort "OPENROUTER_API_KEY is not set" unless ENV["OPENROUTER_API_KEY"].present?

    # Force inline job execution so the full pipeline runs synchronously
    ActiveJob::Base.queue_adapter = :inline

    # Limit linked articles to 3 for faster execution (full pipeline still exercises all paths)
    Rails.application.config.x.frank_investigator.max_link_depth = 1

    # Silence Turbo broadcast errors (cable DB may not have tables during rake task)
    ActiveSupport::Notifications.unsubscribe("turbo.broadcastable.broadcasting") rescue nil

    puts "=== Frank Investigator — Brazilian Integration Test ==="
    puts "Date: #{Time.current}"
    puts "Models: #{Rails.application.config.x.frank_investigator.openrouter_models.join(', ')}"
    puts ""

    # 1. Reset database
    puts "[1/5] Resetting development database..."
    ActiveRecord::Tasks::DatabaseTasks.drop_current
    ActiveRecord::Tasks::DatabaseTasks.create_current
    ActiveRecord::Tasks::DatabaseTasks.migrate

    # Load cable schema for Solid Cable
    cable_schema = Rails.root.join("db/cable_schema.rb")
    if cable_schema.exist? && ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable").present?
      ActiveRecord::Tasks::DatabaseTasks.load_schema(
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable"),
        :ruby,
        cable_schema.to_s
      )
    end
    puts "  Database reset complete."

    # 2. Seed ownership groups
    puts "[2/5] Seeding media ownership groups..."
    ownership_file = Rails.root.join("config/media_ownership_groups.yml")
    if ownership_file.exist?
      raw = YAML.load_file(ownership_file)
      count = 0
      raw.each do |_region, groups|
        groups.each do |_key, attrs|
          MediaOwnershipGroup.find_or_initialize_by(name: attrs.fetch("name")).tap do |group|
            group.parent_company = attrs["parent_company"]
            group.owned_hosts = attrs.fetch("owned_hosts", [])
            group.owned_independence_groups = attrs.fetch("owned_independence_groups", [])
            group.country = attrs["country"]
            group.notes = attrs["notes"]
            group.save!
            count += 1
          end
        end
      end
      puts "  Seeded #{count} ownership groups."
    else
      puts "  No media_ownership_groups.yml found, skipping."
    end

    # 3. Run pipeline for each URL
    puts "[3/5] Running full pipeline for #{URLS.size} articles..."
    investigations = []

    URLS.each_with_index do |url, idx|
      puts ""
      puts "  --- Article #{idx + 1}/#{URLS.size} ---"
      puts "  URL: #{url}"
      start_time = Time.current

      begin
        investigation = Investigations::EnsureStarted.call(submitted_url: url)
      rescue => e
        # With inline adapter, job errors propagate. Recover investigation from DB.
        normalized = Investigations::UrlNormalizer.call(url) rescue url
        investigation = Investigation.find_by(normalized_url: normalized)
        puts "  Job error (recovered): #{e.class}: #{e.message.truncate(120)}"
      end

      if investigation
        investigation.reload
        elapsed = (Time.current - start_time).round(1)
        puts "  Status: #{investigation.status} (#{elapsed}s)"
        puts "  Steps: #{investigation.pipeline_steps.pluck(:name, :status).map { |n, s| "#{n}=#{s}" }.join(', ')}"

        if investigation.completed?
          assessments = investigation.claim_assessments.includes(:claim)
          checkable = assessments.where(checkability_status: "checkable")
          puts "  Claims: #{assessments.count} total, #{checkable.count} checkable"
          checkable.each do |ca|
            puts "    [#{ca.verdict}] (#{ca.confidence_score}) #{ca.claim.canonical_text.truncate(80)}"
          end
        elsif investigation.failed?
          failed_step = investigation.pipeline_steps.find_by(status: "failed")
          puts "  FAILED at: #{failed_step&.name} — #{failed_step&.error_class}: #{failed_step&.error_message&.truncate(120)}"
        end

        investigations << investigation
      else
        puts "  ERROR: Investigation could not be created"
      end
    end

    # 4. Dump JSON reports
    puts ""
    puts "[4/5] Dumping JSON reports to #{OUTPUT_DIR}..."
    FileUtils.mkdir_p(OUTPUT_DIR)

    investigations.each do |investigation|
      investigation.reload
      root_article = investigation.root_article
      checkable_claims = investigation.claim_assessments
        .includes(claim: {}, evidence_items: :article, llm_interactions: {}, verdict_snapshots: {})
        .where(checkability_status: "checkable")
        .order(confidence_score: :desc)
      uncheckable_claims = investigation.claim_assessments
        .includes(:claim)
        .where(checkability_status: %w[not_checkable ambiguous])
        .order(created_at: :asc)
      pipeline_steps = investigation.pipeline_steps.order(:created_at)
      links = root_article&.sourced_links&.includes(:target_article)&.order(:position) || []

      report = {
        id: investigation.id,
        url: investigation.normalized_url,
        status: investigation.status,
        checkability_status: investigation.checkability_status,
        headline_bait_score: investigation.headline_bait_score,
        overall_confidence_score: investigation.overall_confidence_score,
        created_at: investigation.created_at,
        updated_at: investigation.updated_at,
        root_article: root_article && {
          url: root_article.normalized_url,
          title: root_article.title,
          host: root_article.host,
          fetch_status: root_article.fetch_status,
          source_kind: root_article.source_kind,
          authority_tier: root_article.authority_tier,
          authority_score: root_article.authority_score.to_f,
          source_role: root_article.source_role,
          excerpt: root_article.excerpt,
          headline_divergence_score: root_article.headline_divergence_score.to_f,
          linked_sources_count: root_article.sourced_links.count
        },
        rhetorical_analysis: investigation.rhetorical_analysis,
        claims: checkable_claims.map { |a| build_claim_json(a) },
        uncheckable_claims: uncheckable_claims.map { |a| { claim: a.claim.canonical_text, claim_kind: a.claim.claim_kind, checkability_status: a.checkability_status, reason_summary: a.reason_summary } },
        sources: links.map { |link| { href: link.href, anchor_text: link.anchor_text, host: link.target_article.host, source_kind: link.target_article.source_kind, authority_tier: link.target_article.authority_tier, authority_score: link.target_article.authority_score.to_f, follow_status: link.follow_status } },
        pipeline: pipeline_steps.map { |step| { name: step.name, status: step.status, started_at: step.started_at, finished_at: step.finished_at, error_class: step.error_class, error_message: step.error_message } },
        summary: investigation.summary
      }

      slug = URI.parse(investigation.normalized_url).host.gsub(".", "_")
      filepath = OUTPUT_DIR.join("#{slug}_#{investigation.id}.json")
      File.write(filepath, JSON.pretty_generate(report))
      puts "  Written: #{filepath.relative_path_from(Rails.root)}"
    end

    # 5. Summary
    puts ""
    puts "[5/5] Summary"
    puts "  Total investigations: #{investigations.size}"
    puts "  Completed: #{investigations.count(&:completed?)}"
    puts "  Failed: #{investigations.count(&:failed?)}"
    puts "  Total articles in DB: #{Article.count}"
    puts "  Total claims in DB: #{Claim.count}"
    puts "  Total evidence items: #{EvidenceItem.count}"
    puts ""
    puts "You can now run `bin/rails server` and browse to http://localhost:3000 to view reports."
    puts "JSON reports are in: #{OUTPUT_DIR.relative_path_from(Rails.root)}"
  end

  desc "Run single-article integration test with billing report. Usage: rake frank:investigate URL=https://..."
  task investigate: :environment do
    require "fileutils"

    url = ENV.fetch("URL") { abort "Usage: rake frank:investigate URL=https://..." }
    output_dir = Rails.root.join("tmp/integration_reports")

    abort "OPENROUTER_API_KEY is not set" unless ENV["OPENROUTER_API_KEY"].present?

    ActiveJob::Base.queue_adapter = :inline
    Rails.application.config.x.frank_investigator.max_link_depth = 1
    ActiveSupport::Notifications.unsubscribe("turbo.broadcastable.broadcasting") rescue nil

    puts "=== Frank Investigator — Single Article Analysis ==="
    puts "Date: #{Time.current}"
    puts "Models: #{Rails.application.config.x.frank_investigator.openrouter_models.join(', ')}"
    puts "URL: #{url}"
    puts ""

    # Reset database
    puts "[1/4] Resetting development database..."
    ActiveRecord::Tasks::DatabaseTasks.drop_current
    ActiveRecord::Tasks::DatabaseTasks.create_current
    ActiveRecord::Tasks::DatabaseTasks.migrate

    cable_schema = Rails.root.join("db/cable_schema.rb")
    if cable_schema.exist? && ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable").present?
      ActiveRecord::Tasks::DatabaseTasks.load_schema(
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable"),
        :ruby,
        cable_schema.to_s
      )
    end

    ownership_file = Rails.root.join("config/media_ownership_groups.yml")
    if ownership_file.exist?
      raw = YAML.load_file(ownership_file)
      raw.each do |_region, groups|
        groups.each do |_key, attrs|
          MediaOwnershipGroup.find_or_initialize_by(name: attrs.fetch("name")).tap do |group|
            group.parent_company = attrs["parent_company"]
            group.owned_hosts = attrs.fetch("owned_hosts", [])
            group.owned_independence_groups = attrs.fetch("owned_independence_groups", [])
            group.country = attrs["country"]
            group.notes = attrs["notes"]
            group.save!
          end
        end
      end
    end
    puts "  Done."

    # Run pipeline
    puts "[2/4] Running full pipeline..."
    pipeline_start = Time.current
    investigation = nil

    begin
      investigation = Investigations::EnsureStarted.call(submitted_url: url)
    rescue => e
      normalized = Investigations::UrlNormalizer.call(url) rescue url
      investigation = Investigation.find_by(normalized_url: normalized)
      puts "  Job error (recovered): #{e.class}: #{e.message.truncate(200)}"
    end

    pipeline_elapsed = (Time.current - pipeline_start).round(1)

    unless investigation
      abort "  ERROR: Investigation could not be created"
    end

    investigation.reload
    puts "  Status: #{investigation.status} (#{pipeline_elapsed}s)"

    # Full quality report
    puts ""
    puts "[3/4] Quality Report"
    IntegrationReport::Printer.new(investigation).print_all

    # Dump JSON report
    puts ""
    puts "[4/4] JSON Export"
    FileUtils.mkdir_p(output_dir)

    root = investigation.root_article
    assessments = investigation.claim_assessments.includes(:claim)
    checkable = assessments.where(checkability_status: "checkable").order(confidence_score: :desc)
    uncheckable = assessments.where(checkability_status: %w[not_checkable ambiguous])
    interactions = LlmInteraction.where(investigation:)
    completed = interactions.where(status: :completed)

    report = {
      url: investigation.normalized_url,
      status: investigation.status,
      pipeline_elapsed_seconds: pipeline_elapsed,
      root_article: root && {
        title: root.title,
        host: root.host,
        body_length: root.body_text.to_s.length,
        source_kind: root.source_kind,
        authority_tier: root.authority_tier,
        linked_sources: root.sourced_links.count,
        rejection_reason: root.rejection_reason
      },
      claims_summary: {
        total: assessments.count,
        checkable: checkable.count,
        uncheckable: uncheckable.count,
        verdicts: checkable.group(:verdict).count
      },
      billing: {
        total_cost_usd: completed.sum(:cost_usd).to_f.round(6),
        total_prompt_tokens: completed.sum(:prompt_tokens).to_i,
        total_completion_tokens: completed.sum(:completion_tokens).to_i,
        total_llm_calls: interactions.count,
        completed_calls: completed.count,
        failed_calls: interactions.where(status: :failed).count,
        total_latency_ms: completed.sum(:latency_ms).to_i,
        by_type: completed.group(:interaction_type).pluck(
          :interaction_type, Arel.sql("COUNT(*)"), Arel.sql("SUM(cost_usd)")
        ).map { |t, c, cost| { type: t, calls: c, cost_usd: cost.to_f.round(6) } },
        by_model: completed.group(:model_id).pluck(
          :model_id, Arel.sql("COUNT(*)"), Arel.sql("SUM(cost_usd)")
        ).map { |m, c, cost| { model: m, calls: c, cost_usd: cost.to_f.round(6) } }
      },
      claims: checkable.map { |a| build_claim_json(a) },
      articles: Article.all.map { |a| { url: a.normalized_url.truncate(100), host: a.host, status: a.fetch_status, rejection_reason: a.rejection_reason, source_kind: a.source_kind } }
    }

    slug = URI.parse(investigation.normalized_url).host.gsub(".", "_") rescue "unknown"
    filepath = output_dir.join("#{slug}_#{investigation.id}.json")
    File.write(filepath, JSON.pretty_generate(report))
    puts "JSON report: #{filepath.relative_path_from(Rails.root)}"
    puts ""
    total_cost = completed.sum(:cost_usd).to_f
    puts "Pipeline time: #{pipeline_elapsed}s | LLM cost: $#{'%.4f' % total_cost} | Claims: #{checkable.count} checkable / #{assessments.count} total"
  end
end

def build_claim_json(assessment)
  {
    id: assessment.id,
    claim: assessment.claim.canonical_text,
    claim_kind: assessment.claim.claim_kind,
    time_scope: assessment.claim.time_scope,
    verdict: assessment.verdict,
    confidence_score: assessment.confidence_score.to_f,
    authority_score: assessment.authority_score.to_f,
    independence_score: assessment.independence_score.to_f,
    timeliness_score: assessment.timeliness_score.to_f,
    conflict_score: assessment.conflict_score.to_f,
    citation_depth_score: assessment.citation_depth_score.to_f,
    primary_vetoed: assessment.primary_vetoed?,
    unsubstantiated_viral: assessment.unsubstantiated_viral?,
    unanimous: assessment.unanimous?,
    reason_summary: assessment.reason_summary,
    missing_evidence_summary: assessment.missing_evidence_summary,
    disagreement_details: assessment.disagreement_details,
    stale_at: assessment.stale_at,
    assessed_at: assessment.assessed_at,
    evidence: assessment.evidence_items.order(authority_score: :desc).map { |item|
      {
        source_url: item.source_url,
        title: item.article&.title,
        host: item.article&.host,
        source_kind: item.source_kind,
        authority_tier: item.article&.authority_tier,
        authority_score: item.authority_score.to_f,
        relevance_score: item.relevance_score.to_f,
        stance: item.stance,
        excerpt: item.excerpt
      }
    },
    llm_verdicts: assessment.llm_interactions
      .where(interaction_type: :assessment, status: :completed)
      .map { |i| { model_id: i.model_id, verdict: i.response_json&.dig("verdict"), confidence_score: i.response_json&.dig("confidence_score").to_f, reason_summary: i.response_json&.dig("reason_summary") } }
  }
end
