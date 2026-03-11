# Automated Fact-Checking Research Notes

Last updated: March 11, 2026

## Main conclusion

The strongest automated fact-checking systems do not read one article and directly emit a verdict. The approaches that work best combine:

- claim spotting
- claim matching against previously checked claims
- evidence retrieval from the open web or curated authoritative corpora
- question decomposition for hard claims
- citation-grounded synthesis
- calibrated abstention when evidence is weak

That matches the intended direction for Frank Investigator.

## What is already known to work

### 1. Claim spotting and check-worthiness triage

This stage matters in production because not every sentence in a news article is worth checking. AFaCTA reframes factual claim detection and shows LLMs can help generate better supervision data for this first gate.

Source:

- ACL 2024, AFaCTA: https://aclanthology.org/2024.acl-long.104/

### 2. Matching new claims to prior fact-checks

Repeated misinformation is common, often with small paraphrases. Systems that match incoming claims to previously reviewed claims save the most effort. ClaimCheck reports measurable gains from claim-matching before falling back to novel-claim analysis. Multilingual claim matching has also shown promise, which matters because the same claim often crosses languages and outlets.

Sources:

- ClaimCheck 2025: https://aclanthology.org/2025.knowledgenlp-1.26/
- Claim Matching Beyond English 2021: https://aclanthology.org/2021.acl-long.347/
- Fact Check Insights: https://www.factcheckinsights.org/
- Google ClaimReview docs: https://developers.google.com/search/docs/appearance/structured-data/factcheck

### 3. Retrieval-first verification with explicit evidence quality

Real-world fact-checking works better when systems are judged not only on the verdict but also on whether they found good evidence. AVeriTeC pushed the field away from closed-world benchmark assumptions and toward evidence retrieved from the wild. The winning InFact system relies on a multi-stage retrieval stack rather than a single-shot LLM answer.

Sources:

- AVeriTeC 2024 shared task: https://aclanthology.org/2024.fever-1.1/
- InFact 2024: https://aclanthology.org/2024.fever-1.12/
- Retrieval improvement paper 2024: https://aclanthology.org/2024.fever-1.28/

### 4. Domain-specific evidence beats generic browsing

When the evidence source is high quality and structured, systems improve. Check-COVID verifies news claims against scientific papers and outperforms GPT-3.5 with a task-specific pipeline, reinforcing that curated evidence sources remain valuable.

Source:

- Check-COVID 2023: https://aclanthology.org/2023.findings-acl.888/

### 5. Operational AI fact-checking mostly helps humans monitor at scale

Production systems today are strongest at monitoring, ranking, clustering, and surfacing suspicious or repeated claims across media streams. Full Fact AI is a good example of this production pattern.

Sources:

- Full Fact AI: https://fullfact.ai/
- Full Fact Report 2025: https://fullfact.org/policy/reports/full-fact-report-2025/

## What is not solved

### 1. Closed-world benchmark success does not transfer cleanly

FEVER was foundational, but it assumes curated Wikipedia evidence. That made it useful for research but much easier than real-time news analysis with partial, noisy, changing evidence.

Source:

- FEVER 2018: https://aclanthology.org/N18-1074/

### 2. Prompting alone is unreliable

Recent multilingual work found that chain-of-thought and cross-lingual prompting did not reliably improve fact-checking quality. That is a warning against relying on prompt tricks as the main product strategy.

Source:

- Multilingual Fact-Checking using LLMs 2024: https://aclanthology.org/2024.nlp4pi-1.2/

### 3. Efficient or open systems still lag

Recent AVeriTeC work with efficient open-weight systems still reports modest performance. That suggests the hard part is not simply model size but orchestration, retrieval, evidence selection, and calibration.

Source:

- AVeriTeC at CheckThat! 2025: https://aclanthology.org/2025.fever-1.15/

### 4. Cross-language and cross-topic calibration is still weak

A recent preprint reports strong language and topic sensitivity for LLM fact-checking. This is a warning sign for a product meant to generalize across publication styles and claim types.

Source:

- Facts are Harder Than Opinions 2025: https://arxiv.org/abs/2506.03655v1

### 5. Time-aware evidence handling is still immature

One of the most important real-world constraints is whether a piece of evidence existed when the claim was made. This is still not standard in many pipelines.

Source:

- Complex Claim Verification with Evidence Retrieved in the Wild 2024: https://aclanthology.org/2024.naacl-long.196/

### 6. Multimodal misinformation remains hard

Image-text mismatches and manipulated media are still difficult. Even better-designed benchmarks only show moderate performance.

Source:

- VERITE 2023: https://link.springer.com/article/10.1007/s13735-023-00312-6

## Design implications for Frank Investigator

These are product inferences drawn from the sources above.

- The local database should store canonical claims and evidence history, not only raw articles.
- Claim matching should run before full analysis because repeated claims are common and much cheaper to resolve.
- The system should prefer authoritative evidence connectors when possible instead of treating every news article as equally trustworthy.
- The pipeline should model uncertainty explicitly and frequently return "not yet checkable" when the evidence is incomplete.
- Evidence must carry timestamps, provenance, and some notion of source independence.
- The LLM should mainly help with decomposition, query generation, contradiction analysis, and synthesis over cited evidence.

## Questions worth validating during implementation

- How far can we get with article-to-claim and claim-to-evidence graphing before adding expensive full-text crawl depth?
- Which source classes deserve authority boosts in version 1: government data, court records, company filings, press releases, scientific papers, transcripts?
- What is the minimum viable claim canonicalization that still clusters paraphrases well?
- How should confidence be decomposed so users can see whether a low score came from weak evidence, conflicting sources, or an inherently subjective claim?
