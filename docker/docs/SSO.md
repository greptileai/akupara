## Setting up SSO 

First ensure that the jackson service has a custom domain and is accessible via HTTPS connection. See `docker/docs/CustomDomains.md` for more information. 

1. Set the following variables in the `.env`

```
# BoxyHQ/SAML Configuration (Optional)
AUTH_SAML_ONLY="false" #should be set to true if using BoxyHQ/SAML
SAML_ID="" # (can be left blank - otherwise set to some string like my_company_name)
SAML_SECRET="" # (can be left blank if not using SSO, otherwise openssl rand -base64 32)
BOXYHQ_API_KEY="" # (can be left blank if not using SSO, otherwise openssl rand -base64 32)
BOXYHQ_URL="http://saml-jackson:5225" # This cannot be a blank string. Leave unchanged if not using SAML.
AUTH_BOXYHQ_URL="http://saml-jackson:5225" # This cannot be a blank string. Leave unchanged if not using SAML.
AUTH_BOXYHQ_SAML_ISSUER="http://saml-jackson:5225" # This cannot be a blank string. Leave unchanged if not using SAML. 

# (Optional - do not need to be set if not using SAML)
JACKSON_DB_ENCRYPTION_KEY=<generate with: openssl rand -base64 32>
JACKSON_HOST_URL="localhost:5225" #<sso service hostname, e.g. sso.greptile.com or localhost:5225 for local testing>
JACKSON_EXTERNAL_URL="http://localhost:5225" #<full URL, e.g. https://sso.greptile.com or http://localhost:5225 for local testing>
JACKSON_ADMIN_CREDENTIALS="admin@example.com:password" #<admin email:password for Jackson admin console>
JACKSON_PUBLIC_KEY="" #<generate via https://boxyhq.com/docs/jackson/deploy/env-variables#public_key>
JACKSON_PRIVATE_KEY="" #<generate via https://boxyhq.com/docs/jackson/deploy/env-variables#private_key>
JACKSON_IDP_ENABLED=true
```

Once the service is running and you are able to log into the the jackson admin console. Follow these steps

2. Log in to the Postgres database.

    a. Create a new `Organization`, or locate the existing `Organization` where you want to set up SSO. Note the `Organization` ID.

    b. Create an `InternalApiKey` for the `Organization`, if one does not already exist. You can use something like `openssl rand -base64 36` to do this.

    c. Create a `SamlConnection` entry with the `org_id` from above and set the `tenant_id` to the domain of your user's email addresses. e.g. if your users have email addresses like `john@example.com`, then the `tenant_id` should be `example.com`.

3. Go to the Jackson service url. Sign in to the admin console with the credentials configured in the service's environment variables.

    a. Click on Enterprise SSO -> Connections from the sidebar.

    b. Click New Setup Link. The tenant is the same as the `tenant_id` you identified above. The product is `greptile`. Add your `web` service's URL to the list of allowed redirect URLs, e.g. `https://app.greptile.com`. Set the default redirect url to `<web_service>/login/saml`, e.g. `https://app.greptile.com/login/saml`. Create the setup link.

    c. Send the generated setup link to the customer, or the person who will be configuring the SSO connection. This will guide them through the configuration process.

4. Once the customer has completed the setup process, users can sign in to the `web` service using their SSO provider. New users will be added to the `Organization` you set up in step 1.
