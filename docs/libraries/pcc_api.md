# `pcc_api` 1.0.0

PointClickCare API connectivity for the native Linkiir scripting API. Defaults to two-legged OAuth (client_credentials) over mutual TLS on connect2, which authenticates the application and needs no person to sign in, so it suits an unattended feed. The three-legged authorization-code grant is implemented as well and can be enabled by configuration when a deployment needs a signing user's privileges. Exposes connect, authenticated get and post to any path, and thin facility and patient helpers for proving a connection. Every call returns result or nil plus a classified error, and nothing raises.

| | |
|---|---|
| **Library** | `pcc_api` |
| **Version** | 1.0.0 |
| **Immutable** | yes — a fix ships as a new version directory |

## Modules

- `pcc_api/pcc_api.lua`
- `pcc_api/pcc_api_config.lua`
- `pcc_api/pcc_api_http.lua`
- `pcc_api/pcc_api_oauth.lua`

## Using it

A node that pins this library gets the `pcc_api/` folder copied in beside its script. Add it to `package.path` and require the entry module:

```lua
local pcc_api = require("pcc_api.pcc_api")
```
