# Single sign-on (SSO)

Greptile uses [BoxyHQ Jackson](https://boxyhq.com/docs/jackson/overview) for SAML SSO. The Jackson admin console must be reachable over HTTPS. Set that up in [Networking](./networking.md) before continuing.

## Docker Compose

### 1. Environment variables

In `deploy/docker-compose/.env`:

```bash
AUTH_SAML_ONLY="true"  # required to start Jackson and use SAML
AUTH_BOXYHQ_SAML_ID=""       # optional, e.g. my_company_name
AUTH_BOXYHQ_SAML_SECRET=""   # openssl rand -base64 32
AUTH_BOXYHQ_API_KEY=""       # openssl rand -base64 32
AUTH_BOXYHQ_URL="http://saml-jackson:5225"

JACKSON_DB_ENCRYPTION_KEY=<openssl rand -base64 32>
JACKSON_HOST_URL="sso.example.com"
JACKSON_ADMIN_CREDENTIALS="admin@example.com:password"
JACKSON_PUBLIC_KEY=""   # https://boxyhq.com/docs/jackson/deploy/env-variables#public_key
JACKSON_PRIVATE_KEY=""  # https://boxyhq.com/docs/jackson/deploy/env-variables#private_key
JACKSON_IDP_ENABLED=true
```

`AUTH_BOXYHQ_URL` cannot be blank even when SSO is unused; leave the in-cluster default. Set `AUTH_SAML_ONLY=true` so `./bin/start-greptile.sh` starts the `saml` profile.

### 2. Organization records

Log in to the Postgres database.

1. Create or locate the `Organization` that should use SSO. Note its ID.
2. Create an `InternalApiKey` for that organization if one does not exist (`openssl rand -base64 36`).
3. Create a `SamlConnection` with that `org_id`. Set `tenant_id` to the email domain of your users (for `john@example.com`, use `example.com`).

### 3. Jackson setup link

1. Open the Jackson admin console on the HTTPS hostname and sign in with `JACKSON_ADMIN_CREDENTIALS`.
2. Go to **Enterprise SSO → Connections**.
3. Click **New Setup Link**.
   - **Tenant:** the same `tenant_id` as above
   - **Product:** `greptile`
   - **Allowed redirect URLs:** your web URL, e.g. `https://app.greptile.com`
   - **Default redirect URL:** `<web_service>/login/saml`, e.g. `https://app.greptile.com/login/saml`
4. Send the generated setup link to the person who will configure the identity provider.

After they complete setup, users can sign in to the web service with SSO. New users are added to the organization from step 2.

## Kubernetes

Enable Jackson and SAML in values:

```yaml
saml:
  enabled: true
components:
  jackson:
    enabled: true
```

Provide Jackson secrets (`JACKSON_*`, BoxyHQ keys) through `secrets.native` or your external secret store. Then follow the same organization, `SamlConnection`, and Jackson setup-link steps as Docker Compose.

Confirm `network.appUrl` is the HTTPS URL you add to Jackson's allowed redirect list.
