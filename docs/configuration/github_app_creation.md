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

   - Checks: Read & Write
   - Commit statuses: Read & Write
   - Contents: Read-only
   - Issues: Read & Write
   - Metadata: Read-only
   - Pull requests: Read & Write

   **Organization**

   - Members: Read-only

   **Account**

   - Email addresses: Read-only (only if users sign in to Greptile with this GitHub App)

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

8. On **Optional features**, opt out of **User-to-server token expiration**.

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
