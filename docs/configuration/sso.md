# Single sign-on (SSO)

Greptile uses [BoxyHQ Jackson](https://boxyhq.com/docs/jackson/overview) for SAML SSO. The Jackson admin console must be reachable over HTTPS. Set that up in [Networking](./networking.md) before continuing.

This document covers the self-hosted bootstrap flow. The application settings page can generate a Jackson setup link when the signed-in organization admin has a verified email address. The default self-hosted legacy authentication service does not provide an email-verification flow, so the manual bootstrap path below is also supported.

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

### 2. Choose a setup path

#### Preferred: use the application settings page

After the services are running, an organization admin can open **Settings → Organization → SSO** and select **Set up SSO**. The application validates the admin and domain, creates the SAML connection, and opens the Jackson setup link.

If the page says **Email verification required**, use the controlled workaround below or follow the manual database bootstrap path. Do not create a second connection for the same tenant or domain.

#### Controlled self-hosted email-verification workaround

The SSO settings page requires `User.email_confirmed=true`. On the default self-hosted legacy auth path, a password signup can leave this field false because email verification is not configured. An operator may mark the known bootstrap administrator as verified directly in Postgres:

```sql
BEGIN;

SELECT id, email, email_confirmed
FROM "User"
WHERE email = 'admin@example.com';

UPDATE "User"
SET email_confirmed = true
WHERE id = <bootstrap_admin_user_id>
  AND email = 'admin@example.com'
  AND email_confirmed = false;

COMMIT;
```

Replace the email and user ID after checking the `SELECT` result. This is a narrowly scoped operator bootstrap action: it only unlocks the SSO settings page for that administrator. It does not configure SSO, verify a customer domain, or mark other users as verified. Take the normal database backup/change-control precautions before running it.

#### Manual database bootstrap

Log in to the Postgres database.

1. Locate the `Tenant` that should use SSO and note its numeric `id`:

   ```sql
   SELECT id, external_id, name, slug
   FROM "Tenant"
   WHERE slug = 'your-tenant-slug';
   ```

2. Check whether a SAML connection already exists for the tenant or domain:

   ```sql
   SELECT id, tenant_id, saml_tenant_id
   FROM "SamlConnection"
   WHERE tenant_id = <tenant_id>
      OR saml_tenant_id = 'example.com';
   ```

   Stop if the query returns a connection. A tenant can have one SAML connection, and a Jackson tenant/domain must not be assigned to two tenants.

3. If no connection exists, create one using the current column meanings:

   ```sql
   INSERT INTO "SamlConnection" (tenant_id, saml_tenant_id)
   VALUES (<tenant_id>, 'example.com');
   ```

   Here, `tenant_id` is the Greptile `Tenant.id`; `saml_tenant_id` is the Jackson tenant key and should normally be the users' email domain. An `InternalApiKey` is not required for the current SSO connection.

### 3. Jackson setup link

1. Open the Jackson admin console on the HTTPS hostname and sign in with `JACKSON_ADMIN_CREDENTIALS`.
2. Go to **Enterprise SSO → Connections**.
3. Click **New Setup Link**.
   - **Tenant:** the same value as `saml_tenant_id` above, for example `example.com`
   - **Product:** `greptile`
   - **Allowed redirect URLs:** your web URL, for example `https://app.example.com`
   - **Default redirect URL:** `<web_service>/login/saml` for the default self-hosted legacy auth path, for example `https://app.example.com/login/saml`

4. Send the generated setup link to the person who will configure the identity provider.

After they complete setup, the first successful SAML login enables domain auto-join by default unless an administrator has selected invite-only. Users are added when they sign in with a verified matching domain email. Use invitations while setup is incomplete or auto-join is disabled. Older self-hosted image versions may not include the auto-join behavior.

## Kubernetes

Enable Jackson and SAML in values:

```yaml
saml:
  enabled: true
components:
  jackson:
    enabled: true
```

Provide Jackson secrets (`JACKSON_*`, BoxyHQ keys) through `secrets.native` or your external secret store. Then follow the same `Tenant`, `SamlConnection`, and Jackson setup-link steps as Docker Compose. If the SSO settings page is blocked by email verification, use the controlled workaround or manual bootstrap path above.

Confirm `network.appUrl` is the HTTPS URL you add to Jackson's allowed redirect list.
