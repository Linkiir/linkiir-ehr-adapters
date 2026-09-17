# Linkiir EHR Adapters

Adapters for EHR, EMR and practice-management systems reached over a proprietary API rather than FHIR, plus openEHR. Adapters whose wire protocol is FHIR live in [linkiir-fhir-adapters](https://github.com/Linkiir/linkiir-fhir-adapters).

A **catalog** is a package of adapter content that one Linkiir Grid publishes and other grids subscribe to. Subscribing adds these adapters to your grid without a product upgrade.

| | |
|---|---|
| **Catalog id** | `lkehr` |
| **Publisher** | Linkiir Inc |
| **Adapters** | 2 |
| **Libraries** | 1 |
| **Documentation** | [https://help.linkiir.com/docs/catalogs/](https://help.linkiir.com/docs/catalogs/) |

---

## Subscribe

In Grid, open **Settings → Catalogs → Subscribe** and paste this URL:

```
https://github.com/Linkiir/linkiir-ehr-adapters
```

| Field | Value |
|---|---|
| **URL** | the address above |
| **Ref** | `main` |
| **SSH private key** | leave blank — this is a public repository, cloned anonymously |
| **Install name** | `linkiir-ehr-adapters` |

Use the install name exactly as given. Grid records it on every node built from this catalog, so a consistent name keeps a node's origin readable when you contact support.

Subscribing requires the **Manage catalogs** permission (Administration tier). Full instructions, including how to review an update before applying it, are in [the Catalogs documentation](https://help.linkiir.com/docs/catalogs/).

## Adapters

| Adapter | Type | Trigger | Version | Node type id |
|---|---|---|---|---|
| **PCC Connect** | source | interval | 1.0.0 | `LKEHR_PCC_CONNECT` |
| **PCC Request** | transform | on message | 1.0.0 | `LKEHR_PCC_REQUEST` |

### PCC Connect

Obtains a PointClickCare access token on a timer and reads the organization's facilities as a liveness check, pushing a status message downstream. With two-legged OAuth there is nothing to persist: the token is short-lived and can be re-obtained at will, so it is held in memory only.

`LKEHR_PCC_CONNECT` · source node · version 1.0.0 · 14 configuration fields · library `pcc_api` 1.0.0

Credentials required: **Client Secret**. These ship empty — see [Credentials](#credentials).

### PCC Request

Performs an authenticated PointClickCare request described by the incoming message and emits the response. Deliberately generic: it takes a method, path, query and body, so any workflow can reach any endpoint without this node knowing that workflow's domain. {orgUuid} in the path is substituted automatically.

`LKEHR_PCC_REQUEST` · transform node · version 1.0.0 · 13 configuration fields · library `pcc_api` 1.0.0

Credentials required: **Client Secret**. These ship empty — see [Credentials](#credentials).

## Libraries

Shared Lua modules the adapters above depend on. A node pins the exact version it uses, and published versions are immutable, so several can sit side by side.

| Library | Version | Used by |
|---|---|---|
| `pcc_api` | 1.0.0 | PCC Connect, PCC Request |

### `pcc_api` 1.0.0

PointClickCare API connectivity for the native Linkiir scripting API. Defaults to two-legged OAuth (client_credentials) over mutual TLS on connect2, which authenticates the application and needs no person to sign in, so it suits an unattended feed. The three-legged authorization-code grant is implemented as well and can be enabled by configuration when a deployment needs a signing user's privileges. Exposes connect, authenticated get and post to any path, and thin facility and patient helpers for proving a connection. Every call returns result or nil plus a classified error, and nothing raises.

Modules: `pcc_api.lua`, `pcc_api_config.lua`, `pcc_api_http.lua`, `pcc_api_oauth.lua`

## Credentials

Every adapter here ships with its credential fields **empty**, by design. Password fields are encrypted with your own grid's key, so a value shipped from this repository could not be decrypted on your machine. Enter yours on the node after you build it.

Two fields appear on most adapters:

| Field | What it does |
|---|---|
| **Live Mode** | When off, requests are prepared and logged but never sent. Use it to confirm configuration and authentication before touching a live system. |
| **Verify TLS** | Verifies the server's certificate. Leave on. Turn it off only against a local service with a self-signed certificate. |

## Versions and updates

| | |
|---|---|
| **Adapters** | Versioned by the `version` field on each adapter. A change that does not move the version forward is rejected, so one version always means one specific set of files. |
| **Libraries** | Immutable. A published version is never edited; a fix ships as a new version. Nodes pinned to an older version are undisturbed by an update. |

Grid shows you the incoming commit and diff before applying an update. Release notes for every Linkiir catalog adapter and library are published at [help.linkiir.com](https://help.linkiir.com/docs/catalogs/).

## Repository layout

```
catalog.json                              catalog manifest
nodes/<slug>/node_config.json             an adapter definition
nodes/<slug>/*.lua                        its scripts
nodes/<slug>/samples/                     de-identified test messages
libraries/<name>/<version>/library.json   a published library version
libraries/<name>/<version>/<name>/*.lua   its modules
```

The layout matches Grid's own on-disk layout, so a pull applies no transform.

## Other Linkiir catalogs

| Catalog | Covers |
|---|---|
| [linkiir-fhir-adapters](https://github.com/Linkiir/linkiir-fhir-adapters) | FHIR adapters and FHIR tooling |
| **linkiir-ehr-adapters** _(this one)_ | EHR and practice management over proprietary APIs, openEHR |
| [linkiir-interop-adapters](https://github.com/Linkiir/linkiir-interop-adapters) | HL7 v2, C-CDA, IHE, HIE, public health, engine migration |
| [linkiir-payer-adapters](https://github.com/Linkiir/linkiir-payer-adapters) | X12 EDI, clearinghouses, payer APIs, pharmacy |
| [linkiir-diagnostics-adapters](https://github.com/Linkiir/linkiir-diagnostics-adapters) | labs and LIS, imaging and PACS, devices |
| [linkiir-data-adapters](https://github.com/Linkiir/linkiir-data-adapters) | relational and NoSQL databases, warehouses, BI |
| [linkiir-transport-adapters](https://github.com/Linkiir/linkiir-transport-adapters) | object storage, file transport, message brokers |
| [linkiir-ai-adapters](https://github.com/Linkiir/linkiir-ai-adapters) | AI and LLM services |
| [linkiir-notification-adapters](https://github.com/Linkiir/linkiir-notification-adapters) | chat, SMS, voice, email, paging |
| [linkiir-business-adapters](https://github.com/Linkiir/linkiir-business-adapters) | CRM, ERP, ITSM, HR, identity, scheduling |

## Documentation and support

Product documentation lives at **[help.linkiir.com](https://help.linkiir.com/docs/catalogs/)** — how catalogs work, subscribing and reviewing updates, building nodes from catalog adapters, and offline delivery. This repository holds the adapter content itself; it is not the documentation site.

For a question about a specific adapter, quote its node type id.

## License

Copyright © Linkiir Inc. All rights reserved.

This source is published so Linkiir Grid customers can read, audit and run it. It is **not** open source, and no open-source licence is granted. Use of this content is governed by your agreement with Linkiir Inc covering Linkiir Grid. For licensing enquiries, contact Linkiir.

