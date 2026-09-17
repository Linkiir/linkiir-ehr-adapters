# Linkiir EHR Adapters

EHR, EMR and practice-management systems reached over a proprietary API rather than FHIR, plus openEHR. Adapters whose wire protocol is FHIR live in linkiir-fhir-adapters instead.

**Catalog id:** `lkehr` — every node template in this catalog carries a `LKEHR_` node type id.
**Published adapters:** 2 &nbsp;•&nbsp; **Published libraries:** 1

---

## Subscribe

In Grid, go to **Settings → Catalogs → Subscribe** and paste:

```
https://github.com/Linkiir/linkiir-ehr-adapters
```

This is a public repository, so Grid clones it anonymously and no SSH key is needed. Leave **Ref** at `main` to track the latest published content.

Install it under the name **`linkiir-ehr-adapters`**. The install name is recorded on every node built from this catalog, so keeping it consistent makes a node's origin readable in support.

Subscribing needs the **Manage catalogs** permission (Administration tier).

## Published adapters

| Adapter | Slug | Node type | Node type id | Version | Libraries |
|---|---|---|---|---|---|
| PCC Connect | `pcc_connect` | source | `LKEHR_PCC_CONNECT` | 1.0.0 | pcc_api 1.0.0 |
| PCC Request | `pcc_request` | transform | `LKEHR_PCC_REQUEST` | 1.0.0 | pcc_api 1.0.0 |

## Published libraries

| Library | Version | Purpose |
|---|---|---|
| `pcc_api` | 1.0.0 | PointClickCare API connectivity for the native Linkiir scripting API. Defaults to two-legged OAuth (client_credentials) over mutual TLS on connect2, which authenticates the application and needs no person to sign in, so it suits an unattended feed. The three-legged authorization-code grant is implemented as well and can be enabled by configuration when a deployment needs a signing user's privileges. Exposes connect, authenticated get and post to any path, and thin facility and patient helpers for proving a connection. Every call returns result or nil plus a classified error, and nothing raises. |

## Roadmap

| Adapter | Node type | Connects to | Status |
|---|---|---|---|
| openEHR Query + Composition | source, transform | openEHR (AQL and compositions) | Next |
| MEDITECH Expanse | source | MEDITECH | Planned |
| Veradigm / Allscripts | source | Unity API | Planned |
| NextGen / Greenway / AdvancedMD / Tebra / DrChrono | source | ambulatory EMRs | Planned |
| MatrixCare / WellSky / Netsmart / Alayacare | source | post-acute and behavioural | Planned |
| EMIS Web / TPP SystmOne / OSCAR / Accuro | source | UK and Canada EMRs | Planned |
| Altera Paragon / Sunrise / Dedalus ORBIS / TrakCare | source | acute EHRs over proprietary APIs | Planned |
| Epic Cadence | source | Epic scheduling | Planned |

Status meanings: **Next** is in active development, **Planned** is scoped but not started. See [the Integration Network](https://linkiir.com/network/) for the full adapter list and where each one stands.

## Configuration and credentials

Every adapter ships with its credential fields **empty**, and that is deliberate. Password fields are encrypted with each grid's own key, so a value shipped from here could not decrypt on your machine — it would fail with an error blaming your key. Fill them in on the node after you build it.

Two fields appear on most adapters and are worth knowing:

- **Live Mode** — when off, requests are prepared and logged but never sent. Use it to prove configuration before touching a real system.
- **Verify TLS** — leave on. Turn it off only against a local service with a self-signed certificate.

## Support and status

Adapters here are **Beta** unless the roadmap table says otherwise: they work and run somewhere, but the template is still being finished, so expect a Linkiir engineer alongside you on a first deployment. **GA** means the template is hardened and running across multiple customers.

Every adapter has a named owner at Linkiir who maintains it. For a problem with a specific adapter, quote its node type id.

## Versioning

- **Adapters** are versioned by the `version` field in `node_config.json`. A change that does not move the version forward is refused by the validator.
- **Library versions are immutable.** A published `libraries/<name>/<version>/` directory is never edited; a fix ships as a new version directory. Several versions sit side by side and each node pins the one it uses, so updating this catalog cannot disturb a node pinned to an older library.

Before applying an update, Grid shows you the incoming commit and diff. Read [CHANGELOG.md](CHANGELOG.md) for what changed and why.

## Repository layout

```
catalog.json                              the manifest Grid validates
nodes/<slug>/node_config.json             an adapter's definition
nodes/<slug>/*.lua                        its scripts
nodes/<slug>/samples/                     de-identified test messages
libraries/<name>/<version>/library.json   a published library version
libraries/<name>/<version>/<name>/*.lua   its modules
```

The layout is identical to Grid's own on-disk layout, so a pull needs no transform.

---

Published by Linkiir Inc. Part of the [Linkiir catalog set](https://github.com/Linkiir?q=adapters) — see [the Catalogs documentation](https://help.linkiir.com/docs/catalogs/) for how catalogs reach a grid.
