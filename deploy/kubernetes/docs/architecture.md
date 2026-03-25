# Architecture

Greptile chart deploys application workloads only:
- web, auth, api, chunker, summarizer, worker, webhook, jobs, llmproxy
- optional jackson for SAML
- optional bundled Postgres

Hatchet is deployed separately and connected through `hatchet.*` values and `HATCHET_CLIENT_TOKEN`.
