# PCC Request

Performs an authenticated PointClickCare request described by the incoming message and emits the response. Deliberately generic: it takes a method, path, query and body, so any workflow can reach any endpoint without this node knowing that workflow's domain. {orgUuid} in the path is substituted automatically.

| | |
|---|---|
| **Slug** | `pcc_request` |
| **Node type id** | `LKEHR_PCC_REQUEST` |
| **Node type** | transform |
| **Version** | 1.0.0 |
| **Interval driven** | no |
| **Libraries** | pcc_api 1.0.0 |

## Configuration

| Field | Type | Default | Notes |
|---|---|---|---|
| OAuth Mode | list | `2-legged` | 2-legged authenticates the application with client_credentials and needs nobody to sign in, which suits an unattended feed. 3-legged authenticates a person and carries their privileges. The two grants live on different hosts with different transport requirements, so this setting also picks the default URLs below. |
| Client ID | string | _(empty)_ | PointClickCare application Client ID (the Customer Key). Left blank on purpose. |
| Client Secret | password | _(empty — set on the node)_ | PointClickCare application Client Secret (the Customer Secret). Stored encrypted. |
| Organization UUID | string | _(empty)_ | Optional. PointClickCare returns the organization with the token, so this is normally discovered rather than configured. Set it only to pin a specific organization. |
| Client Certificate File | string | _(empty)_ | Path to the client certificate, relative to the Linkiir working directory. REQUIRED for 2-legged: connect2 enforces mutual TLS and rejects a request without one. Must be a certificate issued for client authentication; a self-signed one is refused. |
| Client Key File | string | _(empty)_ | Path to the private key for the client certificate. Must be set together with the certificate, or the handshake fails with a misleading error. |
| CA File | string | _(empty)_ | Optional trust anchor for verifying PointClickCare. Leave blank to use the system store. |
| Redirect URI | string | _(empty)_ | 3-legged only. Where PointClickCare sends the browser after sign-in. Must match the portal registration exactly and must be https. |
| Auth Base URL | string | _(empty)_ | Leave blank to follow OAuth Mode: connect2 for 2-legged, connect for 3-legged. Pairing a grant with the wrong host is the most common first-connection failure. |
| API Base URL | string | _(empty)_ | Leave blank to follow OAuth Mode. Set only to pin a different API version or a proxy. |
| Request Timeout | number | `20` | Seconds to wait for a PointClickCare response. |
| Verify TLS | bool | `true` | Verify PointClickCare's certificate. Leave on. |
| Live Mode | bool | `false` | When off, requests are prepared but never sent, and calls report themselves as simulated. Lets an imported adapter be inspected before it touches a real tenant. |
