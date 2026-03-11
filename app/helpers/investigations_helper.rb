module InvestigationsHelper
  def score_percent(value)
    number_to_percentage(value.to_f, precision: 0)
  end

  def badge_class_for(status)
    case status.to_s
    when "completed", "supported", "checkable", "crawled"
      "badge badge--green"
    when "failed", "disputed"
      "badge badge--red"
    when "not_checkable", "ambiguous", "skipped"
      "badge badge--slate"
    else
      "badge badge--amber"
    end
  end
end
