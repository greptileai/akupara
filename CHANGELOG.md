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
