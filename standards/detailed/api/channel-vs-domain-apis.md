# Channel APIs vs Domain APIs

Two API layers with opposite jobs.

- **Channel APIs** face outward. Each channel exposes *several* of them, one per experience slice (browse, checkout, account, and so on). They are stable for their consumers and composed for the screen.
- **Domain APIs** face inward. They are canonical capabilities that own business logic and data, indifferent to who is calling.

Between them sits a **composition / adaptation layer** (BFF, gateway, aggregators) that adapts one to the other, so front ends don't couple to internal boundaries — except where a channel deliberately consumes a domain API directly (see [When channels can call domain APIs directly](#when-channels-can-call-domain-apis-directly)).

> **Direct access is allowed.** The composition / adaptation layer is the *default* path between channels and domains — not a hard requirement. When a domain API's contract already matches what a channel needs, the channel can call the domain API directly without a channel API in front of it.

---

## Layered architecture

```
OUTWARD  ─  Channel APIs (each channel exposes several, one per experience slice)

  ┌─ Web storefront ─────┐  ┌─ Mobile app ─────────┐  ┌─ In-store / POS ─────┐  ┌─ Partner / B2B ──────┐
  │ • Browse API         │  │ • App Shell API      │  │ • Register API       │  │ • Catalog Feed       │
  │ • Checkout API       │  │ • Checkout API       │  │ • Stock Lookup       │  │ • Orders API         │
  │ • Account API        │  │ • Notify API         │  │                      │  │                      │
  └──────────────────────┘  └──────────────────────┘  └──────────────────────┘  └──────────────────────┘
                                    │  request in · composed response out
                                    ▼
SEAM     ─  Composition & adaptation layer  (BFF / gateway / aggregators)
            Compose · Aggregate · Reshape · Version
                                    │  capability calls · canonical models
                                    ▼
INWARD   ─  Domain APIs (capability-shaped, single-owner, one source of truth)

  ┌─ Catalog ────┐  ┌─ Cart / Order ┐  ┌─ Identity ───┐  ┌─ Content ────┐
  │ Products,    │  │ Checkout,     │  │ Auth,        │  │ CMS,         │
  │ pricing      │  │ orders        │  │ accounts     │  │ merchandising│
  └──────────────┘  └───────────────┘  └──────────────┘  └──────────────┘
                                    │  owns its own data
                                    ▼
PERSIST  ─  Each domain owns its store (no cross-reaching)

  [ Product DB ]      [ Order DB ]      [ Identity DB ]
```

---

## The channel APIs

Each channel is a *group* of purpose-specific channel APIs, not one monolithic contract.

### Web storefront — Browser SPA / SSR
A rich browser experience served by several channel APIs, each shaped for a slice of the journey. Browsing, checkout, and the account area evolve on their own release cadence.

| Channel API | Purpose | Talks to |
|---|---|---|
| Browse API | PLP / PDP payloads — big composed responses stitching catalog + merchandising content into one screen-ready payload | Catalog, Content |
| Checkout API | Drives the web checkout flow; coordinates cart, pricing snapshots, and identity for a browser-optimized funnel | Cart / Order, Identity, Catalog |
| Account API | Powers the logged-in account area — profile, order history, saved details; changes with the account UI, independent of checkout | Identity, Cart / Order |

### Mobile app — iOS / Android
Bandwidth- and battery-sensitive. Broken into trimmed, denormalized channel APIs tuned for small screens and offline.

| Channel API | Purpose | Talks to |
|---|---|---|
| App Shell API | Native home and feed; slim, cache-friendly payloads sized for mobile, distinct from the web browse contract | Catalog, Content |
| Checkout API | Native checkout with device wallets; same cart domain as web, but a mobile-specific contract around native pay sheets | Cart / Order, Identity |
| Notify API | Push tokens, notification inbox, and targeting; a narrow surface only the mobile channel exposes | Identity, Content |

### In-store / POS — Register terminals
Runs on the shop floor with its own auth, tax, and fulfillment rules. Low-latency and resilient to flaky in-store networks.

| Channel API | Purpose | Talks to |
|---|---|---|
| Register API | Cashier-facing checkout with in-store tax and tender rules layered on the cart domain | Cart / Order, Identity, Catalog |
| Stock Lookup | Quick price and availability checks at the terminal; a tiny, read-heavy surface only the store floor needs | Catalog |

### Partner / B2B — External API clients
Third parties integrate against stable, contract-first channel APIs. Feed and orders are split so partners can consume catalog data without touching the order surface.

| Channel API | Purpose | Talks to |
|---|---|---|
| Catalog Feed | Bulk, versioned product + content export for partner catalogs; rate-limited and deliberately narrow | Catalog, Content |
| Orders API | Contract-first B2B ordering; hard-versioned and scoped to only what a partner may submit and see | Cart / Order, Identity |

---

## The domain APIs

Capability-shaped, single-owner, one source of truth. Each owns its own store and nothing reaches across.

| Domain | Owns | Store |
|---|---|---|
| Catalog | Product model, pricing, availability | Product DB |
| Cart / Order | Cart state and the order lifecycle; enforces checkout rules regardless of which channel started the cart | Order DB |
| Identity | Users, sessions, permissions; the single source of who someone is | Identity DB |
| Content | Editorial and merchandising content; feeds web and partner feeds, but the model lives here | Content store |

---

## The composition & adaptation layer

Often called a BFF (backend-for-frontend), API gateway, or aggregation service. It calls multiple domain APIs, joins and reshapes their responses, and returns exactly the payload a channel API needs. This is where breaking domain changes get absorbed so consumers don't feel them, and where per-channel concerns (payload shape, versioning, rate limits) live.

---

## When channels can call domain APIs directly

The adapter layer is the *default* path, not a hard requirement. Not every domain API needs a channel API in front of it — a channel can consume a domain API directly whenever adding a composition layer would buy nothing.

| Direct access is fine when | Use the adapter layer when |
|---|---|
| The channel's needs match the domain contract 1:1 — no reshaping, aggregation, or fan-out | The screen needs a composed payload stitched from several domains |
| The consumer is the domain's own management surface (admin, back-office, merchandising tools) that edits the capability directly | You want to shield the domain from consumer-driven change and keep its versioning slow |
| The payload is already screen-ready at domain granularity (a single entity or focused operation) | Multiple channels would couple to internal boundaries and block domain evolution |
| Auth and blast radius are scoped — a narrow, trusted, first-party consumer | You need per-channel rate limits, quotas, or contract versions |
| The caller is internal tooling or automation, not an end-user experience | The consumer is an end-user screen or a third party |

Practical examples of fair direct-access use cases:

- **Domain management UI** — a catalog management screen for merchandisers calls the Catalog domain API directly. The tool *is* the capability's editing surface; an adapter would only re-type the same contract.
- **Admin / back-office screens** — order lookup, user management, and other single-entity screens render the domain response as-is, with no cross-domain composition.
- **Internal automation** — data fixes, operational scripts, and reconciliation jobs consume the capability itself, not an experience.

The default remains: end-user channels go through the adapter. Direct access is a decision you make deliberately, with the consequences above in mind — not an accident of convenience.

---

## Where they differ

| | Channel API | Domain API |
|---|---|---|
| Shaped by | The consuming experience — one payload per screen or flow, so a channel has several | The business capability — one contract per domain |
| Primary consumer | A specific front end (web, mobile, POS, partner) | Other services and the adapter layer — never end users directly |
| Coupling | Tightly coupled to UI needs; expected to change with the experience | Decoupled from any UI; changes only when the capability changes |
| Data ownership | Owns none — composes data it doesn't store | Sole owner of its data and business rules |
| Versioning | Frequent, consumer-driven; absorbs breaking changes for the client | Slow, deliberate; breaking changes ripple across many callers |
| Granularity | Coarse — one call returns a whole screen's worth of data | Fine — focused operations on a single entity or process |
| Failure blast radius | Contained to one channel's experience | Shared — a domain outage affects every channel that needs it |

---

## The core rule

Dependencies point downward only. Channels depend on the adapter layer — or, where direct access is justified, on a domain API whose contract already matches what the channel needs. The adapter depends on domains; domains depend on nothing above them and never call each other through channel APIs. That one-directional flow is what lets you ship a new mobile screen without touching checkout, or refactor inventory without breaking the storefront.

---
