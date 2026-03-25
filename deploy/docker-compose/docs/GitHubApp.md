## Register a GitHub App for self-hosted GitHub
1. Go to your GitHub organization settings > Developer Settings > GitHub Apps > New GitHub App. If you have problems finding it, refer to the [official guide](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app#registering-a-github-app)
2. Set the following values:
    - GitHub App name: `Greptile`
    - Homepage URL: You can just write `https://greptile.com`
    - Callback URL: `http://<ip_address>:3000/api/auth/callback/github-enterprise` or `https://<your_dns_name>/api/auth/callback/github-enterprise`
    - Setup URL: `http://<ip_address>:3000/auth/github` or `https://<your_dns_name>/auth/github`
      - Make sure to select "Redirect on update".
    - Webhook URL: `http://<ip_address>:3007/webhook`
    - Webhook secret: Generate a secure random string
      - On unix environments, you can use `openssl rand -hex 32` to generate the secure random string.
3. Under "Permissions", ensure the following are enabled:
    - Repository permissions:
      - Checks: `Read & Write`
      - Commit statuses: `Read & Write`
      - Contents: `Read-only`
      - Issues: `Read & Write`
      - Metadata: `Read-only`
      - Pull requests: `Read & Write`
    - Organization permissions:  
      - Members: `Read-only`
    - Account permissions
      - Email Addresses: `Read-only` (Only required if using this GitHub App to sign in to Greptile (sign in with GitHub))
4. Under "Where can this GitHub App be installed?" make sure to select `Any account`
5. Click "Create GitHub App"
6. After having created the GitHub App, click on "General" in the left menu bar.
    - Create a Client Secret by clicking on "Generate a new client secret"
      - Ensure to make a copy of this client secret and store it for later
    - Scroll down to "Private keys" and click on "Generate a private key".
      - This will download a file containing a private key required further below.
7. Click on "Permissions & events" in the left menu bar.
    - Select the following events:
      - Issues
      - Issue Comment
      - Pull Request
      - Pull Request Review
      - Pull Request Review Comment
      - Pull Request Review Thread
8. Click on "Optional features" in the left menu bar.
    - Ensure to `Opt-out` of "User-to-server token expiration"
9. Gather the following values below to populate the relevant fields in the `.env` file:
    - App ID
    - App URL 
    - App Name 
    - Client ID
    - Client secret (generated above)
    - Webhook secret (generated above)
    - Private key (generated above) **Important**: To paste the key into the `.env` file new lines have to be replaced with `\n`
