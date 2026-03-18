# Novu Self-Hosted Bootstrap: Get the First API Key Without Dashboard

## Context

This repository is about a very specific problem:

How do you obtain the first usable Novu secret key for a newly created
organization in a self-hosted setup without opening the dashboard?

Today, the official Novu documentation:

- describes API authentication starting from an existing secret key
- shows that environment responses can contain `apiKeys`
- does not document a complete API-only bootstrap flow for the first key
  of a brand new organization

That gap matters for:

- CI/CD automation
- Infrastructure-as-Code
- fully headless self-hosted deployments

There is also an open Novu issue about this exact bootstrap problem:

- https://github.com/novuhq/novu/issues/5556

## What This PoC Proves

This PoC shows that, in a self-hosted Novu instance, you can bootstrap
the first secret key by reproducing the internal dashboard flow.

In the tested setup:

- official environment-related endpoints exist, but they do not solve the
  first-key bootstrap problem by themselves
- the first call to `GET /v1/environments/api-keys` returns `null`
- `POST /v1/environments/api-keys/regenerate` is required on first run
  to obtain a usable secret key
- once the key is returned, it should be saved and used normally with
  `Authorization: ApiKey <API_KEY>`
- after this one-time bootstrap, Novu self-hosted can be used without the
  dashboard at all if your workflow is API-only

This is a one-time bootstrap workaround, not an everyday API key
management flow.

## Disclaimer

This flow mixes official endpoints with undocumented bootstrap behavior.

- `novu-environment-id` was required in testing
- `novu-environment-id` is not surfaced in the current official docs
- the `regenerate` call is not optional in the tested bootstrap flow
- the workaround may break in future Novu versions

## Tested Version

Tested with:

- Novu `v3.14`

Verified on:

- March 18, 2026

## Bootstrap Flow

### 1. Register User

**Endpoint**

```http
POST /v1/auth/register
```

**Authentication**

None

**Body**

```json
{
  "firstName": "Java",
  "lastName": "Backend",
  "email": "java@backend.local",
  "password": "SecurePassword123!"
}
```

**Extract from response**

```text
.data.token
```

This token is the initial user JWT used for the next steps.

### 2. Create Organization

**Endpoint**

```http
POST /v1/organizations
```

**Headers**

```http
Authorization: Bearer <USER_JWT>
Content-Type: application/json
```

**Body**

```json
{
  "name": "JavaApp"
}
```

**Extract from response**

```text
.data._id
```

This is the new `organizationId`.

### 3. Switch Organization Context

**Endpoint**

```http
POST /v1/auth/organizations/{organizationId}/switch
```

**Headers**

```http
Authorization: Bearer <USER_JWT>
Content-Type: application/json
```

**Path parameter**

```text
organizationId=<ORG_ID>
```

**Extract from response**

```text
.data
```

This returns the organization-scoped JWT used for the environment calls.

### 4. List Environments

**Endpoint**

```http
GET /v1/environments
```

**Headers**

```http
Authorization: Bearer <ORG_JWT>
```

**Extract from response**

```text
.data[0]._id
```

This is the `ENV_ID` that must be passed in the next calls.

### 5. Get API Keys

**Endpoint**

```http
GET /v1/environments/api-keys
```

**Headers**

```http
Authorization: Bearer <ORG_JWT>
novu-environment-id: <ENV_ID>
```

**Extract from response**

```text
.data[0].key
```

Important: in the tested bootstrap flow, the first call returns `null`
every time for a brand new organization. On first bootstrap, this step is
informational only and is not enough to obtain a usable key.

### 6. Regenerate API Key

**Endpoint**

```http
POST /v1/environments/api-keys/regenerate
```

**Headers**

```http
Authorization: Bearer <ORG_JWT>
novu-environment-id: <ENV_ID>
```

**Body**

None

**Extract from response**

```text
.data[0].key
```

In the tested setup, this step is required. This is the actual workaround
that materializes the first usable secret key.

### 7. Verify the Key

**Endpoint**

```http
GET /v1/subscribers
```

**Headers**

```http
Authorization: ApiKey <API_KEY>
```

If this request works, the bootstrap succeeded.

## Why `regenerate` Is Necessary Here

In this PoC, `regenerate` is not a cosmetic fallback.

For a newly created organization in the tested self-hosted setup:

1. `GET /v1/environments/api-keys` returns `null`
2. `POST /v1/environments/api-keys/regenerate` returns the first usable
   secret key

So the workaround is:

1. create user
2. create organization
3. switch organization
4. resolve environment
5. call `api-keys`
6. detect `null`
7. call `api-keys/regenerate`
8. save the returned key and stop using the bootstrap flow

## Notes

- Run this only once during bootstrap.
- Persist the returned API key immediately after generation.
- After bootstrap, use the standard Novu API flow with
  `Authorization: ApiKey <API_KEY>`.
- In practice, this enables a self-hosted Novu setup operated without the
  dashboard once the first key has been bootstrapped.
- Do not treat `regenerate` as a normal operational path unless you
  explicitly want a new key.

## References

- Novu API Reference Overview: https://docs.novu.co/api-reference
- Novu List All Environments:
  https://docs.novu.co/api-reference/environments/list-all-environments
- Novu Create Environment:
  https://docs.novu.co/api-reference/environments/create-an-environment
- Novu issue about API-only onboarding of a new organization:
  https://github.com/novuhq/novu/issues/5556

# Buy me a coffee ☕
It took me a lot of time to create this guide. I want to donate the result of my efforts to the community, but if you feel like thanking me, buy me a coffee! : [paypal.me/mirawara](https://paypal.me/mirawara)
