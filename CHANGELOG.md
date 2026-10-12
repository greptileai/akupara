## 202610.5 - 2026-10-12

### Added

- Add self-hosted Knowledge Base generation and viewing, including a shared persistent artifact store for generated knowledge bases.
- Add OpenAI GPT review policies with Base, Plus, and Apex review types.
- Enable the Gitea connection option by default in self-hosted deployments.

### Changed

- Default self-hosted review routing to the OpenAI policy `greptile-v5.3@6`; deployments without `gpt-6.1-sol` can use `v5.2-tiers@2` instead.
- Require a HTTPS `network.appUrl` when using auth v2, because Hydra rejects non-localhost HTTP OAuth redirects.
- Require custom web deployments to use `BILLING` instead of `BILLING_ENABLED`.
- Add documented configuration for private certificate authorities used by internal SCM, SSO, or LLM endpoints.

### Fixed

- Respect automatic-approval settings configured on the base branch and safely withhold approval when those settings cannot be loaded.

## 202609.10

### Added

- Add Bitbucket Data Center support, including bot-token connections and signed webhook delivery.
- Add configurable pull-request auto-approval, including path-based filters and approval-risk instructions.
- Add custom roles, a read-only Viewer role, and optional directory-group role mappings.
- Add an Available providers view for configured review-context integrations.
- Support Claude Sonnet 5 and Claude Opus 5.

### Changed

- Legacy integration connections may need to be reconnected after upgrading.
- Add support for static self-hosted feature flags through deployment configuration.
- Enable pull-request auto-approval and approval-risk instructions by default in on-prem deployments.
- Simplify the LLM proxy configuration by removing unused models and routing aliases.
- Pin the BoxyHQ Jackson image to `26.2.0`.
- Disable Pylon in web deployments.

### Fixed

- Improve GitHub Enterprise onboarding on self-hosted deployments.
- Improve GitLab and Bitbucket connection and webhook reliability.
- Set the GitHub bot login and username on Kubernetes so self-hosted instances can recognize their own pull-request comments.
