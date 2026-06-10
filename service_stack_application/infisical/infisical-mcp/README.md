# Infisical MCP Bridge for Codex

This folder contains the dedicated MCP service for connecting Codex or another MCP-capable client to the local self-hosted Infisical instance.

## Architecture

- Runs as a separate container on the shared external `infra_net` network.
- Uses the official `@infisical/mcp` server.
- Wraps the upstream server with a small local descriptor patch so MCP clients see the validated `list-projects` guidance for this self-hosted setup.
- Connects to the existing Infisical application over internal Docker DNS at `http://infisical:8080`.
- Authenticates with an Infisical Organization Machine Identity via Universal Auth.
- Supports a two-profile Codex setup: readonly and admin.

This is intentionally separate from the main `infisical` service so that the MCP-facing runtime can be configured, restarted, and permissioned independently.

Current local state:

- Codex is registered locally as an MCP client for this bridge
- the bridge authenticates successfully against the local Infisical instance with Universal Auth and an Organization Machine Identity
- the validated runtime path is Codex -> `infisical-mcp` -> `http://infisical:8080`

Recommended operating model:

- `codex-readonly`: default MCP profile for reads and discovery
- `codex-admin`: separate MCP profile for intentional write operations
- the shared `infisical-mcp` compose stack is the base runtime layer
- readonly and admin MCP sessions are normally started on demand as ephemeral `docker compose run --rm ...` processes
- for Codex MCP registration specifically, prefer a clean `docker run` stdio wrapper over the same env files because raw Compose startup output can interfere with MCP server registration

## Files

- `docker-compose.yml`: MCP runtime definition for the official `@infisical/mcp` server.
- `patch-descriptors.mjs`: local stdio proxy that patches MCP tool metadata before it reaches Codex.
- `.env.readonly.example`: local configuration template for the readonly machine identity.
- `.env.admin.example`: local configuration template for the admin machine identity.
- `codex-mcp-server.example.json`: example MCP server entry for Codex or compatible desktop clients.

## Authentication Model

Preferred default:

- `INFISICAL_AUTH_METHOD=universal-auth`
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`

Fallback:

- `INFISICAL_AUTH_METHOD=access-token`
- `INFISICAL_TOKEN`

User credentials are intentionally not part of this setup. The MCP bridge should authenticate only as a machine identity so that its scope, permissions, and rotation lifecycle remain explicit.

## Identity and RBAC Model

Use two Organization Machine Identities:

- `codex-readonly`
  - organization role: `No Access` or another minimal organization role without `project:create`
  - project role: read-only access in the projects Codex should inspect
- `codex-admin`
  - organization role: `Admin` or, preferably, a custom organization role that includes `project:create`
  - project role: `Admin` for fast setup or a custom write-capable role limited to:
    - `secrets`: `read`, `create`, `edit`, `delete`
    - `secret-folders`: `read`, `create`, `edit`, `delete`
    - `environments`: `read`, `create`, `edit`, `delete`

Important behavior:

- Organization-level identity alone is not enough for project secret access.
- To read or write secrets in a project, the identity must be added to that specific project under `Project Settings -> Access Control -> Machine Identities`.
- To create projects, the admin identity additionally needs organization-level permission for `project:create`.

## Rollout Phases

### Phase 1: Read-oriented pilot

Use a restricted Organization Machine Identity and validate only:

- `list-projects` with a concrete `type` value such as `secret-manager`
- `list-secrets`
- `get-secret`

The goal of Phase 1 is to prove container startup, authentication, network reachability, and Codex integration without enabling secret mutation or project creation.

### Phase 2: Controlled write enablement

Only after the pilot succeeds should the machine identity be granted additional rights for:

- `create-secret`
- `update-secret`
- `delete-secret`
- `create-project`
- `create-environment`
- `create-folder`
- `invite-members-to-project`

If the team wants stronger separation, run two MCP profiles:

- `infisical-readonly`
- `infisical-admin`

## Setup

1. Copy `.env.readonly.example` to `.env.readonly`.
2. Copy `.env.admin.example` to `.env.admin`.
3. Fill in the Universal Auth Client ID and Client Secret for `codex-readonly` and `codex-admin`.
4. Keep both credential sets out of the repository and rotate them in Infisical if they are ever exposed.
5. Ensure the shared infrastructure and the base `infisical` service are already running on `infra_net`.
6. For Codex MCP registration, use the `docker compose run --rm ...` examples from `codex-mcp-server.example.json`.
   For Codex itself, if MCP registration fails, switch to a clean `docker run` wrapper that uses the same env file and `patch-descriptors.mjs` mount.
7. Optional only for manual debugging: you may still start a profile persistently with `up -d`, but that is not the default operating model.

## Validation

Container/runtime validation:

- `docker compose --env-file .env.readonly -f docker-compose.yml config` renders successfully
- `docker compose --env-file .env.admin -f docker-compose.yml config` renders successfully
- Codex can launch both MCP profiles from `docker compose run --rm ...`
- if a profile is started manually for debugging, its logs do not show authentication failures

Codex/MCP validation for the pilot:

- Codex can register both MCP servers using the example config
- Codex is locally registered against the MCP bridge in the current workstation setup
- `infisical-readonly` can run `list-projects`, `list-secrets`, and `get-secret`
- `infisical-admin` can run `list-projects` and the planned write operations
- `list-projects` works when called with a concrete project `type`; `type="all"` did not work against the local self-hosted Infisical instance during validation

Write validation for the second phase:

- create a disposable test project
- verify whether `codex-admin` automatically has access to the new project; if not, add the identity to the project explicitly and document that as a required operational step
- create a test folder or environment
- create and read a disposable test secret
- update the test secret
- optionally delete the test secret again

## Troubleshooting

### Container restarts immediately with a Zod error for `INFISICAL_TOKEN`

Symptom:

- `docker compose ps` shows `Restarting`
- logs contain a validation error similar to `String must contain at least 1 character(s)` for `INFISICAL_TOKEN`

Cause:

- `INFISICAL_TOKEN` was passed into the container as an empty string even though the bridge was configured for `universal-auth`

Fix:

- remove `INFISICAL_TOKEN` entirely from the MCP container environment when using `INFISICAL_AUTH_METHOD=universal-auth`
- recreate or restart the container after updating the compose definition or `.env`

### `list-projects` fails when called with `type=\"all\"`

Symptom:

- the MCP server is up and authenticated
- `list-projects` still fails when the tool is called with `type=\"all\"`

Cause:

- the local self-hosted Infisical instance validated during this setup does not accept `all` as a project type for this tool path

Fix:

- call `list-projects` with a concrete type instead
- validated examples: `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, `ai`

### Universal Auth returns `401 Invalid credentials`

Symptom:

- the MCP process starts but authentication fails
- direct login against `/api/v1/auth/universal-auth/login` returns `401` with `Invalid credentials`

Typical causes:

- the Machine Identity ID was used instead of the Universal Auth Client ID
- the Client Secret does not match the active Universal Auth credential
- the new credentials were added to `.env.readonly` or `.env.admin`, but the next MCP process was started with stale local config or a manually persisted debug container

Fix:

- use the Universal Auth Client ID, not the Machine Identity ID
- verify the matching Client Secret
- if Codex uses `run --rm`, restart the MCP session so the next short-lived container picks up the updated `.env`
- if you started a persistent debug container manually, recreate that explicit profile container before retrying

## Operational Notes

- Prefer `http://infisical:8080` inside Docker. Use `http://infisical.localhost` only for host-side tools that are not on `infra_net`.
- The official `@infisical/mcp` server supports both read and write tools. Treat permission scope as part of the infrastructure design, not as a client-side convention.
- For `list-projects`, prefer explicit type filters such as `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, or `ai`. Do not assume `type="all"` is accepted by the local service.
- Use `infisical-readonly` as the default Codex MCP profile. Switch to `infisical-admin` only when a task intentionally needs to create projects or mutate project resources.
- The normal Codex path is ephemeral: each MCP invocation should use `docker compose run --rm ...` for the selected profile instead of relying on long-running readonly/admin sidecar containers.
- The local bridge patches the `list_projects` tool description so MCP clients are warned to use concrete project types instead of `all`.
- If `create-project` succeeds but secret writes in the new project fail, check whether `codex-admin` still needs explicit project membership after project creation.
- If you later expose this bridge through a different MCP gateway, preserve the same machine-identity and least-privilege model.
