# LLM Integration Ideas

Potential ways to incorporate LLMs into Cove as production features.

## User-Facing Features

### Natural Language Search
Let users query items in plain English (e.g. "affordable consciously sourced coffee under $20"). An LLM translates the query into structured discovery parameters for `GET /discovery` (query text, category, filters), which are then executed normally.

**Note:** Requires a reasonably populated catalog to feel useful. Seed the `catalog` schema with 20-30 items across categories before building this out.

### Admin Item Ingestion
Paste a brand's website URL or item description into an admin form. An LLM extracts structured data (name, price, category, tags, ethical certifications) and pre-fills a `catalog.items` row (via `cove-catalog`) for review and publishing.

**Why build this:** Directly solves the sparse-data problem while demonstrating LLM integration. A two-for-one.

### Personalized Recommendations
Surface items with an explanation of why they were recommended ("Based on your interest in indie coffee roasters..."). More engaging than a silent algorithm.

### Review Summarization
When item reviews are added, summarize sentiment into a "what buyers say" blurb shown on the item detail screen.

### Brand Storytelling
A "tell me about this brand" button that synthesizes a producer's catalog data into a short narrative paragraph shown on the brand page.

### Onboarding Quiz
Ask a few free-text questions about the user's values (sustainability priorities, budget, preferred categories). Use an LLM to interpret answers into structured user preferences stored as `profile.interests` (via `cove-user`) and used for personalization.

## Backend / Pipeline

### PR Review Step (CI)
Add a GitHub Actions step that calls the Claude API to summarize what changed in a PR diff or flag potential issues. Runs on every PR — a real API call in a real workflow.

## Getting Started

The **admin item ingestion** tool is the best starting point:
- Unblocks the data problem
- Scoped and buildable without a full backend
- Clearly demonstrates LLM-in-production experience
- Can be a simple SwiftUI admin form + a backend endpoint that writes to the `catalog` schema (via `cove-catalog`)

## Stack Considerations

- Call LLM APIs from a **backend service** on the cluster, server-side (keeps API keys out of the iOS app)
- Use the **Anthropic Claude API** or OpenAI API
- Return structured JSON from the LLM using tool use / structured outputs
- Log all LLM inputs and outputs for observability
