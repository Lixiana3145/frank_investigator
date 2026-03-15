namespace :frank do
  desc "Print detailed quality report for the latest (or specified) investigation. Usage: rake frank:report [ID=1]"
  task report: :environment do
    investigation = if ENV["ID"].present?
      Investigation.find(ENV["ID"])
    else
      Investigation.order(:created_at).last
    end

    abort "No investigation found" unless investigation

    printer = IntegrationReport::Printer.new(investigation)
    printer.print_all
  end
end

module IntegrationReport
  class Printer
    def initialize(investigation)
      @inv = investigation
      @root = investigation.root_article
      @assessments = investigation.claim_assessments.includes(
        claim: :article_claims,
        evidence_items: :article,
        llm_interactions: {},
        verdict_snapshots: {}
      ).order(:id)
      @checkable = @assessments.select { |a| a.checkability_status == "checkable" }
      @uncheckable = @assessments.reject { |a| a.checkability_status == "checkable" }
      @links = @root&.sourced_links&.includes(:target_article)&.order(:position) || []
      @llm_interactions = LlmInteraction.where(investigation: @inv)
    end

    def print_all
      print_header
      print_article
      print_body_quality
      print_claims
      print_rhetorical_analysis
      print_evidence_sources
      print_verdict_snapshots
      print_llm_billing
      print_quality_summary
    end

    private

    def section(title)
      puts ""
      puts separator
      puts title
      puts separator
    end

    def separator
      "-" * 88
    end

    def print_header
      puts "=" * 88
      puts "INVESTIGATION REPORT"
      puts "=" * 88
      puts ""
      puts "  URL:       #{@inv.submitted_url}"
      puts "  Status:    #{@inv.status}"
      puts "  Analyzed:  #{@inv.analysis_completed_at&.strftime('%Y-%m-%d %H:%M UTC') || 'in progress'}"
      puts "  Summary:   #{@inv.summary}" if @inv.summary.present?
      puts "  Overall confidence: #{@inv.overall_confidence_score}"
    end

    def print_article
      return unless @root

      section "ARTICLE"
      puts "  Title:       #{@root.title}"
      puts "  Source:      #{@root.host}"
      puts "  Authority:   #{@root.authority_tier} (score: #{@root.authority_score.to_f.round(2)})"
      puts "  Source kind: #{@root.source_kind} | Role: #{@root.source_role}"
      puts "  Fetch:       #{@root.fetch_status}"
      puts "  Body:        #{@root.body_text.to_s.length} chars"
      puts "  Headline divergence: #{@root.headline_divergence_score}" if @root.headline_divergence_score.present?
      puts "  Headline bait score: #{@inv.headline_bait_score}" if @inv.headline_bait_score.to_f > 0
      puts ""
      puts "  Excerpt:"
      puts "  #{@root.excerpt&.truncate(280)}"
    end

    def print_body_quality
      return unless @root&.body_text.present?

      section "BODY TEXT QUALITY"

      body = @root.body_text
      puts "  Length: #{body.length} chars | Paragraphs: #{body.split("\n\n").size}"
      puts ""
      puts "  First 300 chars:"
      puts "  #{body.first(300)}"
      puts "  ..."
      puts ""
      puts "  Last 200 chars:"
      puts "  ...#{body.last(200)}"

      # Check for common noise patterns
      noise_checks = []
      noise_checks << "trailing tag labels" if body.last(100).match?(/\A[\p{L}\p{N}]+(?:\s+[\p{L}\p{N}]+){0,4}\z/m)
      noise_checks << "Publicidade/ad markers" if body.match?(/Publicidade|Propaganda|Advertisement/i)
      noise_checks << "cookie/LGPD text" if body.match?(/cookie|lgpd|proteção de dados/i)
      noise_checks << "login/senha text" if body.match?(/\blogin\b.*\bsenha\b|\bsign\s+in\b.*\bpassword\b/i)
      noise_checks << "share buttons text" if body.match?(/compartilhar|copiar link|share this/i)

      puts ""
      if noise_checks.any?
        puts "  Noise detected: #{noise_checks.join(', ')}"
      else
        puts "  Noise check: CLEAN (no ads, cookies, login, share buttons, or trailing tags detected)"
      end
    end

    def print_claims
      section "CLAIMS (#{@assessments.size} total: #{@checkable.size} checkable, #{@uncheckable.size} other)"

      @assessments.each_with_index do |ca, i|
        c = ca.claim
        ac = c.article_claims.find { |ac2| ac2.article_id == @root&.id }
        puts ""
        puts "  CLAIM #{i + 1}: [#{ca.verdict.upcase}] confidence: #{ca.confidence_score.to_f.round(2)}"
        puts "  Checkability: #{ca.checkability_status || c.checkability_status}"
        puts "  Kind: #{c.claim_kind} | Role: #{ac&.role} | Importance: #{ac&.importance_score}"
        puts "  Time: #{c.time_scope.presence || 'none'} | Topic: #{c.topic.presence || 'none'}"
        puts ""
        puts "  Surface text:"
        puts "    #{ac&.surface_text}"
        puts "  Canonical text:"
        puts "    #{c.canonical_text}"
        puts ""
        puts "  Assessment scores:"
        puts "    Authority: #{ca.authority_score.to_f.round(2)} | Independence: #{ca.independence_score.to_f.round(2)} | Citation depth: #{ca.citation_depth_score.to_f.round(2)}"
        puts "    Timeliness: #{ca.timeliness_score.to_f.round(2)} | Conflict: #{ca.conflict_score.to_f.round(2)}"
        puts "    Unanimous: #{ca.unanimous?} | Primary vetoed: #{ca.primary_vetoed?} | Unsub. viral: #{ca.unsubstantiated_viral?}"
        puts ""
        puts "  Reason: #{ca.reason_summary}" if ca.reason_summary.present?
        puts "  Missing evidence: #{ca.missing_evidence_summary}" if ca.missing_evidence_summary.present?

        if ca.evidence_items.any?
          puts ""
          puts "  Evidence (#{ca.evidence_items.size}):"
          ca.evidence_items.each do |ei|
            puts "    - [#{ei.stance}] #{ei.article&.host} (#{ei.source_kind}, auth: #{ei.authority_score.to_f.round(2)}, rel: #{ei.relevance_score.to_f.round(2)})"
            puts "      #{ei.excerpt&.truncate(120)}"
          end
        end

        llm_verdicts = ca.llm_interactions.select { |li| li.interaction_type == "assessment" && li.status == "completed" }
        if llm_verdicts.any?
          puts ""
          puts "  LLM verdicts:"
          llm_verdicts.each do |li|
            v = li.response_json
            puts "    - #{li.model_id}: #{v&.dig('verdict')} (conf: #{v&.dig('confidence_score')}) — #{v&.dig('reason_summary')&.truncate(100)}"
          end
        end
      end
    end

    def print_rhetorical_analysis
      section "RHETORICAL ANALYSIS"

      ra = @inv.rhetorical_analysis
      if ra.blank?
        puts "  (no rhetorical analysis performed)"
        return
      end

      ra = ra.is_a?(String) ? JSON.parse(ra) : ra

      puts "  Narrative bias score: #{ra['narrative_bias_score']}"
      puts "  Summary: #{ra['summary']}"
      puts ""

      fallacies = ra["fallacies"] || []
      if fallacies.any?
        puts "  Fallacies detected (#{fallacies.size}):"
        fallacies.each_with_index do |f, i|
          puts ""
          puts "    #{i + 1}. #{f['type']} (#{f['severity']})"
          puts "       Excerpt: #{f['excerpt']&.truncate(150)}"
          puts "       Explanation: #{f['explanation']&.truncate(200)}"
          puts "       Undermines: #{f['undermined_claim']&.truncate(120)}" if f["undermined_claim"].present?
        end
      else
        puts "  No fallacies detected."
      end
    end

    def print_evidence_sources
      section "EVIDENCE SOURCES (#{@links.size} links)"

      crawled = @links.select { |l| l.follow_status == "crawled" }
      pending = @links.select { |l| l.follow_status == "pending" }
      skipped = @links.select { |l| l.follow_status == "skipped" }

      puts "  Crawled: #{crawled.size} | Pending: #{pending.size} | Skipped: #{skipped.size}"

      hosts = @links.map { |l| l.target_article.host }.tally
      puts "  Host distribution: #{hosts.map { |h, c| "#{h} (#{c})" }.join(', ')}"
      puts ""

      @links.each_with_index do |link, i|
        a = link.target_article
        puts "  SOURCE #{i + 1}: [#{link.follow_status}]"
        puts "    URL:    #{a.url}"
        puts "    Title:  #{a.title.presence || '(not fetched)'}"
        puts "    Host:   #{a.host} | Fetch: #{a.fetch_status} | Authority: #{a.authority_tier} (#{a.authority_score.to_f.round(2)})"
        puts "    Body:   #{a.body_text.to_s.length} chars"
        puts "    Anchor: #{link.anchor_text&.truncate(120)}"
        puts "    Reject: #{a.rejection_reason}" if a.rejection_reason.present?
        puts ""
      end

      # Rejected articles (not linked but created and rejected)
      rejected = Article.where(fetch_status: :rejected)
      if rejected.any?
        puts "  Rejected articles (#{rejected.count}):"
        rejected.each do |a|
          puts "    #{a.normalized_url.truncate(80)} — #{a.rejection_reason}"
        end
        puts ""
      end
    end

    def print_verdict_snapshots
      snapshots = VerdictSnapshot.joins(:claim_assessment)
        .where(claim_assessments: { investigation_id: @inv.id })
        .order(:created_at)

      return if snapshots.empty?

      section "VERDICT HISTORY (#{snapshots.size} snapshots)"

      snapshots.each do |vs|
        transition = vs.previous_verdict.present? ? "#{vs.previous_verdict} -> #{vs.verdict}" : "initial -> #{vs.verdict}"
        puts "  Assessment ##{vs.claim_assessment_id}: #{transition} (conf: #{vs.confidence_score.to_f.round(2)})"
        puts "    Trigger: #{vs.trigger} | By: #{vs.triggered_by}"
        puts "    Evidence count: #{vs.evidence_count}"
        puts "    Reason: #{vs.reason_summary&.truncate(150)}"
        puts ""
      end
    end

    def print_llm_billing
      section "LLM BILLING"

      completed = @llm_interactions.where(status: :completed)
      failed = @llm_interactions.where(status: :failed)

      total_cost = completed.sum(:cost_usd).to_f
      total_prompt = completed.sum(:prompt_tokens).to_i
      total_completion = completed.sum(:completion_tokens).to_i
      total_latency = completed.sum(:latency_ms).to_i

      puts "  Total LLM calls:  #{@llm_interactions.count} (#{completed.count} completed, #{failed.count} failed)"
      puts "  Total tokens:     #{total_prompt + total_completion} (#{total_prompt} input + #{total_completion} output)"
      puts "  Total cost:       $#{'%.4f' % total_cost}"
      puts "  Total latency:    #{(total_latency / 1000.0).round(1)}s"
      puts ""

      puts "  By interaction type:"
      completed.group(:interaction_type).pluck(
        :interaction_type,
        Arel.sql("COUNT(*)"),
        Arel.sql("SUM(prompt_tokens)"),
        Arel.sql("SUM(completion_tokens)"),
        Arel.sql("SUM(cost_usd)")
      ).sort_by { |_, _, _, _, cost| -cost.to_f }.each do |type, count, pt, ct, cost|
        puts "    %-28s %3d calls | %6d in + %5d out | $%s" % [ type, count, pt.to_i, ct.to_i, "%.4f" % cost.to_f ]
      end

      puts ""
      puts "  By model:"
      completed.group(:model_id).pluck(
        :model_id,
        Arel.sql("COUNT(*)"),
        Arel.sql("SUM(prompt_tokens)"),
        Arel.sql("SUM(completion_tokens)"),
        Arel.sql("SUM(cost_usd)")
      ).sort_by { |_, _, _, _, cost| -cost.to_f }.each do |model, count, pt, ct, cost|
        puts "    %-38s %3d calls | %6d in + %5d out | $%s" % [ model, count, pt.to_i, ct.to_i, "%.4f" % cost.to_f ]
      end

      if failed.any?
        puts ""
        puts "  Failed calls:"
        failed.each do |f|
          puts "    #{f.model_id} (#{f.interaction_type}): #{f.error_class} — #{f.error_message.to_s.truncate(100)}"
        end
      end
    end

    def print_quality_summary
      section "QUALITY SUMMARY"

      total_claims = @assessments.size
      checkable = @checkable.size
      noise = 0 # all claims should be non-noise at this point
      verdicts = @checkable.group_by(&:verdict).transform_values(&:size)

      puts "  Claims:     #{total_claims} total, #{checkable} checkable, #{@uncheckable.size} other"
      puts "  Verdicts:   #{verdicts.map { |v, c| "#{v}: #{c}" }.join(', ')}"
      puts "  Noise:      #{noise} noise claims detected"
      puts ""

      # Evidence diversity
      hosts = @links.map { |l| l.target_article.host }.uniq
      same_host = hosts.select { |h| h == @root&.host }.any?
      external = hosts.reject { |h| h == @root&.host }
      puts "  Evidence hosts: #{hosts.size} unique (#{external.size} external)"
      puts "  Same-outlet only: #{same_host && external.empty? ? 'YES (evidence gap)' : 'no'}"
      puts ""

      # Body cleanliness
      body = @root&.body_text.to_s
      clean = !body.match?(/Publicidade|cookie|lgpd|login.*senha|copiar link/i)
      puts "  Body text clean: #{clean ? 'YES' : 'NO'}"
      puts "  Body length:     #{body.length} chars"
      puts ""

      # LLM efficiency
      completed = @llm_interactions.where(status: :completed).count
      failed = @llm_interactions.where(status: :failed).count
      total_cost = @llm_interactions.where(status: :completed).sum(:cost_usd).to_f
      failure_rate = @llm_interactions.count > 0 ? (failed.to_f / @llm_interactions.count * 100).round(1) : 0

      puts "  LLM calls:       #{@llm_interactions.count} (#{failed} failed, #{failure_rate}% failure rate)"
      puts "  LLM cost:        $#{'%.4f' % total_cost}"

      puts ""
      puts "=" * 88
    end
  end
end
