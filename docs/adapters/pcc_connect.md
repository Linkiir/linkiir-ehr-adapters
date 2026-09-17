# PCC Connect

Obtains a PointClickCare access token on a timer and reads the organization's facilities as a liveness check, pushing a status message downstream. With two-legged OAuth there is nothing to persist: the token is short-lived and can be re-obtained at will, so it is held in memory only.

| | |
|---|---|
| **Slug** | `pcc_connect` |
| **Node type id** | `LKEHR_PCC_CONNECT` |
| **Node type** | source |
| **Version** | 1.0.0 |
| **Interval driven** | yes |
| **Libraries** | pcc_api 1.0.0 |

## Configuration

| Field | Type | Default | Notes |
|---|---|---|---|
| Interval | number | `900000` | How often, in milliseconds, to re-check the connection. 900000 is fifteen minutes. The token is cached in memory and only re-fetched when it nears expiry, so this costs little. |
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
