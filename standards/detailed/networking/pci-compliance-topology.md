# PCI Compliance & Network Topology

How PCI DSS shapes the cloud network design: CDE segmentation within a hub-and-spoke model, where each control lives, and whether to run separate PCI vs non-PCI API gateways. Start with [Cloud Network Topology](./cloud-network-topology.md) for the overall model and [Hub-and-Spoke Setup](./hub-and-spoke-setup.md) for the underlying network build.

---

## Why Topology Is the First PCI Decision You Make

PCI DSS applies to the **Cardholder Data Environment (CDE)** — systems that store, process, or transmit cardholder data (PAN), *plus* anything that can impact its security. The fastest way to cut assessment cost and risk is **segmentation**: if the CDE is isolated such that the rest of the estate cannot reach it, the assessment scope shrinks from "everything" to "the CDE plus its chokepoints."

This is exactly what hub-and-spoke gives you — *if* you design for it:

- Put the CDE in **dedicated spokes**, architecturally identical to others but with stricter policy.
- Keep the CDE spoke(s) in a separate trust boundary: separate AWS accounts / Azure subscriptions (own Management Group) / GCP folder+projects, wired to a **separate TGW route table / firewall policy / firewall rule set** respectively.
- Every shared component that CDE traffic touches (firewall, DNS, bastion, logging pipeline) becomes **in-scope** unless you isolate CDE paths from day one.

## Topology Rules for PCI Workloads

**What this means:**

- **Dedicated CDE spokes/accounts.** Never co-locate PCI and non-PCI workloads in the same spoke "temporarily." Temporary arrangements in payments are permanent.
- **Explicit allow-list routing.** Only named spokes/services may initiate connections into the CDE spoke; default-deny everywhere else. Document these flows — assessors will ask for the data-flow diagram, and it must match reality.
- **Inspection on the CDE boundary.** East-west and egress traffic touching the CDE passes the firewall/IDS with a dedicated rule set. In AWS terms: separate TGW route table sending CDE-bound traffic through the inspection VPC. On Azure: dedicated Azure Firewall Premium policy with IDPS. On GCP: dedicated firewall policy tier + NVA path for CDE subnets.
- **Shared services either stay out-of-band or get partitioned.** Examples: CDE gets its own DNS view (no shared caching resolvers mixing queries), its own log destinations feeding the SIEM with retention per PCI (12 months, 3 immediately available), its own bastion/privileged-access path with MFA and session recording.
- **Minimize what enters the CDE at all.** Tokenize at the edge (see gateway guidance below): if your systems only ever see tokens, most of your topology stays out of scope entirely. Redirect to payment-service-provider-hosted fields where possible (SAQ A/A-EP territory) — the cheapest compliance is not storing or touching PAN.
- **Keep the diagram honest.** Maintain current network and data-flow diagrams as code artifacts reviewed on every topology change; PCI DSS v4.0 explicitly requires current diagrams and annual segmentation penetration tests (plus re-testing after any segmentation change).

## Control-to-Location Mapping

| PCI-relevant control | Where it lives in the topology |
|----------------------|-------------------------------|
| Default-deny segmentation | Hub routing/firewall policy isolating CDE spokes |
| Egress restriction from CDE | Hub firewall: CDE egress allow-list (PSP endpoints, patch sources) |
| Intrusion prevention | Inspection layer on CDE boundary (IDPS-enabled) |
| Access control into CDE | Hub bastion/PAM with MFA, recorded sessions, JIT elevation |
| Logging & monitoring (10.x) | CDE-specific log sinks → SIEM with alerting; 12-month retention |
| Time sync (10.6) | Dedicated NTP path documented for CDE spokes |
| Wireless/physical isolation | Not applicable in-cloud, but CDE accounts must block rogue network bridges (no mixed-purpose spokes) |
| Vulnerability/ASV scanning | External scan targets limited to declared CDE front doors (API gateway/LB VIPs) |

## Practical Scope Shapes

| Shape | Description | When to Choose |
|-------|-------------|----------------|
| **Tokenized (recommended)** | PSP-hosted fields/tokenization; your estate handles tokens only; CDE reduced to negligible or zero | Almost always the right first choice; revisit only for interchange economics |
| **Minimal CDE** | Small dedicated CDE spoke running only payment orchestration; everything else talks tokens | You operate payment processing yourself |
| **Broad CDE** | Payment logic spread across multiple spokes sharing infrastructure | Never accept this shape — it is a symptom of topology debt |

---

# Should PCI and Non-PCI Have Separate API Gateways?

**Recommendation: yes — run a dedicated API gateway deployment for PCI traffic, separate from the general platform gateway**, whenever your systems handle PAN in any form. If your architecture is fully tokenized (you only ever see tokens, never PAN), a single gateway is acceptable — but design it so splitting later is a configuration change, not a rebuild.

## Why Separate

| Reason | Explanation |
|--------|-------------|
| **Scope containment** | A shared gateway means its config store, caches, logs, metrics, dashboards, and operator access all plausibly touch CDE data → the whole gateway platform enters PCI scope. A dedicated instance confines scope to one deployment. |
| **Policy isolation** | PCI gateways need stricter, slower-changing policies (TLS versions/ciphers, header hygiene, schema validation, request size limits). Sharing a platform couples PCI change cadence to every team's release train. |
| **Change-management separation** | PCI in-scope components require assessed change processes (PCI DSS 6.x). Two deployments let the non-PCI gateway stay agile while the PCI gateway carries the heavier process. |
| **Blast radius & availability** | A bad deploy or noisy tenant on the shared gateway must never degrade the payment path. Separate deployments give independent scaling, quotas, and failure domains. |
| **Audit simplicity** | Assessors trace the network/data-flow diagram to reality. A dedicated PCI gateway produces a crisp boundary: "this hostname, this VIP, this deployment, done." |

## Trade-offs of Separation (Be Honest About Costs)

| Cost | Mitigation |
|------|-----------|
| Duplicate gateway spend | PCI gateway is typically small — payment endpoints are few; cost is minor vs assessment cost |
| Two platforms to operate | Same gateway technology in both places; shared Terraform modules, diverging only in policy profiles |
| Risk of inconsistent authN/authZ | Extract auth into a shared (out-of-scope) identity provider both gateways consult; keep JWT/OIDC patterns identical |
| Client confusion (two base URLs) | Treat as a feature: `api.example.com` vs `pay-api.example.com` makes the security boundary visible to everyone |

## How to Split per Provider

General gateway mechanics per provider are in [API Gateway & Hub Integration](./api-gateway-hub-integration.md); the split looks like this:

| Provider | Non-PCI gateway | PCI gateway |
|----------|----------------|-------------|
| **AWS** | API Gateway (shared account/ingress VPC) | Dedicated API Gateway in the CDE account, behind its own WAF/WebACL, private integrations only into CDE spokes; own custom domain (`pay-api.*`) |
| **Azure** | APIM instance (internal mode) in shared hub | Second APIM instance (its own deployment) in a dedicated CDE hub/spoke, own Application Gateway WAF policy, own private DNS zone |
| **GCP** | Apigee X org/env group on shared host project | Dedicated Apigee environment (ideally separate Apigee instance/eval region) with PSC attachments in the CDE folder's host project; Cloud Armor policy tuned for payment endpoints |

In all three: the PCI gateway's *backends* resolve only to CDE spokes; its logs ship to the CDE SIEM sink; its operators are a distinct IAM group; and it appears as a labeled box in the PCI network diagram.

## Decision Guide

| Situation | Choice |
|-----------|--------|
| Systems store, process, or transmit PAN | **Separate PCI gateway** (strongly recommended) |
| Fully tokenized — only tokens cross your boundary (PSP-hosted fields) | Single gateway acceptable; keep payment routes in a distinct route/path group ready to carve out |
| Regulated + fast-moving startup, one product | Separate gateway still worth it if PCI scope exists; the cost asymmetry favors isolation |
| Multi-tenant platform where some tenants take payments | Separate gateway mandatory for the payment tenants; tenancy routing decides which gateway fronts each request |

---

## Related Standards

- [Cloud Network Topology](./cloud-network-topology.md) — topology choice and series index
- [Hub-and-Spoke Setup](./hub-and-spoke-setup.md) — building the network this segmentation lives in
- [API Gateway & Hub Integration](./api-gateway-hub-integration.md) — general gateway placement patterns
