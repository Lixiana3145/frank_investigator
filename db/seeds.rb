brazil_profiles = Sources::ProfileRegistry.all(region: :brazil)

brazil_profiles.each do |profile|
  sample_url = "#{profile.homepage_url.chomp("/")}/frank-investigator-amostra"
  sample_title = "#{profile.name}: artigo de amostra para testes locais"
  sample_body = <<~TEXT.squish
    Esta e uma materia de amostra criada para testes locais do Frank Investigator.
    O texto representa um artigo associado ao veiculo #{profile.name} e afirma que uma medida reduziu impostos em 4 por cento em 2026.
  TEXT

  article = Article.find_or_initialize_by(normalized_url: sample_url)
  article.assign_attributes(
    url: sample_url,
    host: URI.parse(profile.homepage_url).host,
    title: sample_title,
    body_text: sample_body,
    excerpt: sample_body.truncate(180),
    fetch_status: :fetched,
    fetched_at: Time.current,
    main_content_path: "article",
    source_kind: profile.source_kind,
    authority_tier: profile.authority_tier,
    authority_score: profile.authority_score,
    independence_group: profile.independence_group
  )
  article.save!

  investigation = Investigation.find_or_initialize_by(normalized_url: sample_url)
  investigation.assign_attributes(
    submitted_url: sample_url,
    root_article: article,
    status: :completed,
    checkability_status: :checkable,
    headline_bait_score: 18,
    overall_confidence_score: 0.62,
    summary: "Amostra brasileira seeded para #{profile.name}"
  )
  investigation.save!
end

puts "Seeded #{brazil_profiles.count} Brazilian source profiles as local demo investigations."
