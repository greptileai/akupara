# Greptile Self-Hosted 202609.10

We are replacing the 0.3.XXX versioning scheme with YYYYMM.<build>, based on the year and month of the image. New images will be released at least once a month.
This release expands self-hosted source-control and integration capabilities, adds configurable auto-approval and role controls, and updates the supported model configuration.

## Before upgrading

- **Supported upgrade from:** `v0.3.301` and `v0.3.301-1`
- **Upgrade urgency:** Non-urgent but recommended
- **Operator action:** Take a database backup.
- **Expected downtime:** less than 1 minute for the upgrade duration.

Follow the [self-hosted upgrade guide](https://github.com/greptileai/akupara/blob/release/202609.10/docs/operations/upgrade.md).

### Upgrade notes

- Legacy integration connections may require reconnection after the database migration.
- A new feature which adds an auto-approval and an approval-risk setting in the Web UI needs to be unlocked via two environment variables first: `AUTO_APPROVE_ENABLED='true'` and `APPROVAL_RISK_ENABLED='true'`; no pull request is auto-approved until an administrator configures auto-approval.
- Unused model aliases have been removed from [llmproxy-config.yaml](deploy/kubernetes/charts/greptile/files/llmproxy-config.yaml). Review that file and update your copy as needed.

## What's changed

### Highlights

- Add Bitbucket Data Center support, including bot-token connections and signed webhook delivery.
- Add configurable pull-request auto-approval, including path-based filters and approval-risk instructions.
- Add custom roles, a read-only Viewer role, and optional directory-group role mappings.
- Add an Available providers view for configured review-context integrations.
- Support the latest Claude Sonnet and Opus 5 models.

### Important fixes

- Improve GitHub Enterprise onboarding on self-hosted deployments.
- Improve GitLab and Bitbucket connection and webhook reliability.
- Configure the GitHub bot login and username on Kubernetes so self-hosted instances recognize their own pull-request comments.

See the [complete changelog](https://github.com/greptileai/akupara/blob/release/202609.10/CHANGELOG.md).

## Release artifacts

Source commit: `2fa7482bd13cd7ee0ab2f01f4bdefd39cbe2bc8a`

- [Compatibility requirements](https://github.com/greptileai/akupara/blob/release/202609.10/docs/installation/requirements.md)
