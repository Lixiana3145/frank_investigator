# Frank Investigator Technical Architecture

Last updated: March 11, 2026

## Product contract

Frank Investigator is a public, no-auth Rails 8 application that accepts a news article URL and produces a shareable analysis page.

Primary entry flow:

1. User visits `/`
2. User submits a URL
3. App normalizes the URL and redirects to `/?url=<escaped_url>`
4. The app finds or creates the investigation for that normalized URL
5. Background jobs fetch, parse, analyze, and expand the evidence graph
6. The page progressively updates as results become available

## What version 1 must do

- fetch the article with Chromium, not simple HTTP
- parse only the main article body and ignore sidebars, headers, footers, ads, and unrelated modules
- extract the outbound links inside the article body
- recursively ingest those linked sources with depth and host limits
- derive canonical claims from the article and headline
- separate checkable claims from non-checkable or opinion-based statements
- score headline bait relative to article evidence
- compute confidence from transparent factors, not only LLM confidence
- show users both the current verdict and the missing evidence

## Rails-native implementation choices

- database: SQLite3
- job backend: Solid Queue
- cache: Solid Cache
- realtime updates: Turbo Streams, optionally Solid Cable later
- background orchestration: Active Job with explicit step records
- LLM integration: RubyLLM, configured for OpenRouter
- browser automation: Chromium through a dedicated adapter

## Core domain model

### Investigation

Represents one requested analysis for one normalized root URL.

Key fields:

- `submitted_url`
- `normalized_url`
- `status`
- `root_article_id`
- `headline_bait_score`
- `overall_confidence_score`
- `checkability_status`
- `summary`
- `analysis_completed_at`

Notes:

- unique index on `normalized_url`
- acts as the stable record looked up by `/?url=...`

### Article

Represents one fetched page that appears in the evidence graph, including the root article and followed citations.

Key fields:

- `url`
- `normalized_url`
- `host`
- `title`
- `published_at`
- `body_text`
- `excerpt`
- `fetch_status`
- `content_fingerprint`
- `fetched_at`
- `main_content_path`

Notes:

- unique index on `normalized_url`
- `main_content_path` is a debugging aid for extraction

### ArticleLink

Represents a directed edge from one article to another discovered inside the main article body.

Key fields:

- `source_article_id`
- `target_article_id`
- `href`
- `anchor_text`
- `context_excerpt`
- `position`
- `follow_status`
- `depth`

Notes:

- unique index on `[source_article_id, href]`
- tracks crawl scope and recursion

### Claim

Represents a canonical, de-duplicated claim.

Key fields:

- `canonical_text`
- `claim_kind`
- `checkability_status`
- `topic`
- `entities_json`
- `time_scope`
- `first_seen_at`
- `last_seen_at`

Notes:

- unique index on a normalized canonical fingerprint
- a claim can be linked to many articles

### ArticleClaim

Join model linking claims to articles, including how the claim was used.

Key fields:

- `article_id`
- `claim_id`
- `role`
- `surface_text`
- `stance`
- `importance_score`
- `title_related`

Roles:

- `headline`
- `lead`
- `body`
- `supporting`
- `linked_source`

### ClaimAssessment

Stores the current analysis result for a claim inside one investigation.

Key fields:

- `investigation_id`
- `claim_id`
- `verdict`
- `confidence_score`
- `checkability_status`
- `reason_summary`
- `missing_evidence_summary`
- `conflict_score`
- `authority_score`
- `independence_score`
- `timeliness_score`

Notes:

- unique index on `[investigation_id, claim_id]`

### EvidenceItem

Represents a cited piece of evidence supporting or contradicting a claim.

Key fields:

- `claim_assessment_id`
- `article_id`
- `source_url`
- `source_type`
- `published_at`
- `stance`
- `excerpt`
- `citation_locator`
- `authority_score`
- `independence_group`

Source types may include:

- article
- transcript
- scientific_paper
- government_record
- court_record
- company_filing
- press_release
- dataset

### PipelineStep

Tracks one idempotent unit of work for one investigation.

Key fields:

- `investigation_id`
- `name`
- `status`
- `attempts_count`
- `started_at`
- `finished_at`
- `result_json`
- `error_class`
- `error_message`
- `lock_version`

Notes:

- unique index on `[investigation_id, name]`
- every job owns one step name

## Pipeline phases

### Phase 1: intake

- normalize the submitted URL
- find or create the investigation
- enqueue fetch and analysis fan-out

### Phase 2: fetch and extraction

- fetch the root article with Chromium
- extract the main content using readability-style heuristics
- save article text, metadata, and in-body links
- create child article placeholders for followed links

### Phase 3: claim decomposition

- extract headline claims
- extract article-body claims
- classify each claim as checkable, opinion, rhetorical, or ambiguous
- cluster paraphrases into canonical claims

### Phase 4: evidence expansion

- follow in-body links within a controlled recursion budget
- gather linked-source summaries
- identify missing evidence
- optionally query authority-specific retrievers later

### Phase 5: verification

- retrieve prior local matches
- retrieve contradictory or corroborating evidence
- compute factor scores
- ask the LLM ensemble to synthesize a citation-grounded assessment

### Phase 6: presentation

- update the public page as partial results land
- keep checkable and non-checkable sections separate
- surface confidence drivers and missing evidence

## LLM strategy

The LLM is not the only judge. It is a structured collaborator.

Version 1 LLM duties:

- claim extraction
- claim normalization suggestions
- title-vs-body bait analysis
- evidence comparison
- rationale synthesis with explicit citations

Version 1 LLM non-duties:

- final verdict without retrieved evidence
- freeform browsing without traceable sources
- silent confidence assignment

### Consensus plan

Use RubyLLM through OpenRouter with three independently configured models.

Suggested pattern:

- run three model analyses in parallel on the same evidence packet
- require structured JSON responses
- aggregate by majority verdict plus score dispersion
- downgrade confidence when the three models materially disagree

## Confidence model

Overall confidence should be computed from sub-scores rather than a single opaque model probability.

Suggested sub-scores:

- evidence sufficiency
- source authority
- source independence
- temporal consistency
- contradiction severity
- claim clarity
- model consensus

Example output labels:

- high confidence
- medium confidence
- low confidence
- insufficient evidence

## Headline bait score

The title analysis should compare the headline to the set of extracted primary claims and supporting evidence.

Signals:

- headline makes stronger claim than the body
- headline implies certainty while body remains tentative
- headline introduces entities or causality not supported in the body
- headline omits important uncertainty or scope limits

## Active Job orchestration and idempotency

Jobs must be safe to retry and safe to enqueue more than once.

Rules:

- every job starts by claiming its `PipelineStep`
- a completed step exits immediately
- a running step may be re-enqueued but must not duplicate writes
- writes happen inside transactions
- downstream jobs only fan out after the parent step commits

Suggested first jobs:

- `Investigations::KickoffJob`
- `Investigations::FetchRootArticleJob`
- `Investigations::ExtractClaimsJob`
- `Investigations::AnalyzeHeadlineJob`
- `Investigations::ExpandLinkedArticlesJob`
- `Investigations::AssessClaimsJob`

## Testing strategy

### Unit tests

Focus on:

- URL normalization
- article-body extraction
- claim classification
- canonical claim fingerprinting
- confidence aggregation
- pipeline step claiming and retry behavior

### Job tests

Focus on:

- idempotent re-execution
- fan-out behavior
- no duplicate join rows under repeated runs
- correct partial-state transitions

### Request and system tests

Focus on:

- homepage form submission
- canonical redirect format
- analysis page rendering with partial and complete states
- Turbo refresh of job results

## Near-term implementation order

1. schema and models
2. investigation lookup and homepage flow
3. pipeline step runner
4. stubbed fetcher and parser interfaces
5. initial jobs with deterministic fake analyzers in test
6. Chromium adapter
7. RubyLLM adapter and consensus aggregator
