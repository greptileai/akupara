# GitHub App creation

## GitHub Cloud vs GitHub Enterprise

In Docker Compose `.env`:

```bash
GITHUB_ENABLED='false'            # true for GitHub.com
GITHUB_ENTERPRISE_ENABLED='true'  # true for self-hosted GitHub Enterprise
```

Set the matching URLs:

```bash
GITHUB_APP_URL='https://github.your-enterprise.com/github-apps/greptile'
GITHUB_ENTERPRISE_URL='https://github.your-enterprise.com'  # no trailing slash
GITHUB_ENTERPRISE_API_URL='https://github.your-enterprise.com/api/v3/'
GITHUB_ENTERPRISE_APP_URL="${GITHUB_APP_URL}"
```

On Kubernetes, set `github.appUrl`, `github.enterpriseUrl`, `github.enterpriseAppUrl`, and related IDs in `values.user.yaml`.

## Register a GitHub App (self-hosted GitHub)

When using Greptile with a self-hosted GitHub instance, you need to create a GitHub App for Greptile in your GitHub instance. Follow these steps:

1. Go to your GitHub organization settings > **Developer Settings** > **GitHub Apps** > **New GitHub App**. See the [GitHub guide](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app) if you cannot find that page.
2. Set:

   - **GitHub App name:** `Greptile`
   - **Homepage URL:** `https://greptile.com` is fine
   - **Callback URL:** `http://<ip_address>:3000/api/auth/callback/github-enterprise` or `https://<your_dns_name>/api/auth/callback/github-enterprise`
   - **Setup URL:** `http://<ip_address>:3000/auth/github` or `https://<your_dns_name>/auth/github` — enable **Redirect on update**
   - **Webhook URL:** `http://<ip_address>:3007/webhook` or the public webhook URL from [Networking](./networking.md)
   - **Webhook secret:** a secure random string (`openssl rand -hex 32` on Unix)

3. Enable these permissions:

   **Repository**

   - Actions: Read-only
   - Administration: Read-only
   - Checks: Read & Write
   - Commit statuses: Read & Write
   - Contents: Read & Write
   - Deployments: Read-only
   - Issues: Read & Write
   - Metadata: Read-only
   - Pull requests: Read & Write
   - Workflows: Read & Write (optional; required to apply fixes to `.github/workflows/` files)

   Contents write enables applying code suggestions and merging from the review UI. Administration read lets Greptile inspect branch protection before merging; administration write is not needed. Actions read and Deployments read let review chat inspect CI runs, logs, artifacts, and deployment status. They do not permit rerunning CI or creating deployments.

   **Organization**

   - Members: Read-only

   **Account**

   - Email addresses: Read-only (if users sign in or link their GitHub identity with this GitHub App)

4. Under **Where can this GitHub App be installed?**, select **Any account**.
5. Create the app.
6. On **General**:

   - Generate a client secret and store it
   - Generate a private key (downloads a `.pem` file)

7. On **Permissions & events**, subscribe to:

   - Issues
   - Issue comment
   - Pull request
   - Pull request review
   - Pull request review comment
   - Pull request review thread
   - Repository
   - Check run
   - Check suite
   - Status
   - Push
   - Branch protection rule
   - Repository ruleset (when available on your GitHub version)

   Check, status, push, and protection/ruleset events refresh CI and merge-readiness state in the review UI. Keep the existing pull request and comment events for review and discussion synchronization. Event availability varies by GitHub Enterprise Server version; unavailable event types must be omitted.

8. On **Optional features**, opt out of **User-to-server token expiration**.

## Update an existing GitHub App for the review UI

Upgrading Greptile does not change the GitHub App registration or approve new permissions on existing installations. Keep the existing app, App ID, private key, webhook secret, and installation; do not create a replacement app for this update.

1. Open the existing app's **Permissions & events** on the GitHub instance where it is registered. Compare its settings with the full list above. For apps created using the older Akupara instructions, the permission changes are:

   | Permission | Previous instructions | Updated instructions | Feature |
   |------------|-----------------------|----------------------|---------|
   | Contents | Read-only | Read & Write | Apply code suggestions and merge PRs |
   | Administration | Not requested | Read-only | Inspect branch protection before merging |
   | Actions | Not requested | Read-only | Read CI runs, jobs, logs, and artifacts in review chat |
   | Deployments | Not requested | Read-only | Read deployment history and status in review chat |
   | Workflows | Not requested | Read & Write, optional | Apply fixes to workflow files |

2. Save the permission changes and enable the missing webhook subscriptions listed above. Retain the existing webhook URL and secret.
3. Have an organization/account owner review and approve the new permissions for **each existing installation**, under the installed app's configuration. Until approved, that installation retains its previous grants. See GitHub's [app update instructions](https://docs.github.com/en/apps/maintaining-github-apps/modifying-a-github-app-registration).
4. Users performing GitHub actions in the review UI must link their GitHub account for the correct instance, even if they sign in to Greptile using a password or SAML. Reauthorize the connection if GitHub requests approval or Greptile requests reconnection. User-token actions are limited by both the app's grants and the user's own repository access; these permissions do not bypass branch protection.
5. Verify on a test PR: load its diff and checks, post/reply to a comment, resolve/reopen a thread, request a reviewer, submit a review decision, update the branch, apply a suggestion, and merge an eligible reviewed commit. If using review chat's CI/deployment tools, verify those reads too. Test workflow-file edits only when Workflows write was enabled. A GitHub policy or user-access refusal can still be expected even with the app permissions configured correctly.

Existing Checks, Commit statuses, Issues, Pull requests, Metadata, and organization Members permissions remain required. Updating the app settings alone does not replace installation-owner approval. See GitHub's [user-token permission model](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app).

## Values to copy into Greptile

| GitHub App field | Docker Compose `.env` | Kubernetes secrets / values |
|------------------|----------------------|-----------------------------|
| App ID | `GITHUB_APP_ID` | `github.appId` / `github.enterpriseAppId` |
| App URL | `GITHUB_APP_URL` | `github.appUrl` / `github.enterpriseAppUrl` |
| App name / bot login | `GITHUB_BOT_LOGIN` | `github.botLogin` |
| Bot username | `GITHUB_BOT_USERNAME` | `github.botUsername` |
| Client ID | `GITHUB_CLIENT_ID` | `secrets.native.GITHUB_CLIENT_ID` |
| Client secret | `GITHUB_CLIENT_SECRET` | `secrets.native.GITHUB_CLIENT_SECRET` |
| Webhook secret | `WEBHOOK_SECRET` | `secrets.native.WEBHOOK_SECRET` and `GITHUB_WEBHOOK_SECRET` |
| Private key | `GITHUB_PRIVATE_KEY` | `secrets.native.GITHUB_PRIVATE_KEY` |

`botLogin` / `botUsername` must match your GitHub App slug so Greptile can find its own prior comments.

**Private key in `.env`:** replace newlines with `\n` so the key is a single line.
