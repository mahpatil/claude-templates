# Cloud Network Topology Standards

Guidance for teams building their first cloud network from scratch: choosing between topology models (flat, peering mesh, hub-and-spoke), then deep-dives into implementing hub-and-spoke on AWS/Azure/GCP, segmenting for PCI compliance, and integrating API gateways with the network hub.

---

## Key Business Drivers

| Driver | Outcome |
|--------|---------|
| **Landing Zone Longevity** | The topology you pick in month 1 is expensive to undo in year 3 — choose deliberately |
| **Security Segmentation** | Network boundaries are the primary blast-radius control; compliance scope follows them |
| **Centralized Control** | One place to enforce egress, inspection, DNS, and logging instead of N one-off setups |
| **Team Autonomy** | Spokes give product teams freedom inside guardrails set by the platform team |
| **Cost** | Centralized NAT/egress and inspection avoid duplicated per-team spend |
| **Auditability** | Clean boundaries produce clean audit answers (especially for PCI, HIPAA, SOX) |
| **Hybrid Readiness** | A hub makes on-prem connectivity a one-time hub change, not a mesh rewiring |

---

## Choosing a Topology When Starting From Scratch

### The Three Realistic Options

| Option | What It Looks Like | Best For | Avoid When |
|--------|-------------------|----------|------------|
| **Flat (single VPC/VNet/project)** | Everything in one network, segmented only by subnets and firewall rules | PoCs, single-team products, first 90 days of learning | More than one team, any regulated workload, prod + non-prod sharing a network |
| **Isolated networks + peering mesh** | Each workload gets its own VPC/VNet/project; peers connected pairwise | Few (2–4) genuinely independent workloads | More than ~5 networks — peerings grow quadratically and nobody can reason about them |
| **Hub-and-spoke** | Shared services live in a central hub; workloads live in spokes; all traffic transits the hub | Multi-team orgs, anything regulated, anything expecting hybrid connectivity | Truly single-workload estates |

**Recommendation:** If you are starting from scratch with more than one team, or you expect regulated workloads (payments, health, personal data), start directly with **hub-and-spoke**. It is the only model that scales team count, compliance scope, and hybrid connectivity without a painful migration. If you must start flat (speed of learning), set a hard trigger to migrate: second product team, first production workload, or first compliance conversation — whichever comes first.

```
FLAT                          PEERING MESH                 HUB-AND-SPOKE
┌───────────────────┐         ┌─────┐ ┌─────┐              ┌──────────────────────┐
│  One big VPC      │         │ VPC ├─┤ VPC │              │       HUB            │
│  ┌────┐ ┌────┐    │         └──┬──┘ └──┬──┘              │ FW · DNS · NAT       │
│  │team│ │team│    │            │  ╳    │  (n·(n-1)/2)    │ VPN · Proxy ·        │
│  └────┘ └────┘    │         ┌──┴──┐ ┌──┴──┐              │ Logging · Bastion.   │
│  subnet fences    │         │ VPC ├─┤ VPC │              └─────┬──────┬─────┬───┘
└───────────────────┘         └─────┘ └─────┘                 ┌──┴──┐┌──┴──┐┌─┴───┐
                                                              │SPOKE││SPOKE││SPOKE│
                                                              └─────┘└─────┘└─────┘
```

### Decision Guide

| Question | Yes → |
|----------|-------|
| Will more than one team deploy workloads in the next 12 months? | [Hub-and-spoke](./hub-and-spoke-setup.md) |
| Any PCI/HIPAA/SOX-regulated workload planned? | Hub-and-spoke (mandatory) + [PCI segmentation design](./pci-compliance-topology.md) |
| On-prem or partner connectivity expected? | Hub-and-spoke |
| Solo team, throwaway system, pure learning exercise? | Flat is acceptable; timebox it |
| 2–3 unrelated products, no compliance, no hybrid? | Peering mesh is acceptable; revisit above 5 networks |

### Anti-Patterns to Refuse From Day One

- **One giant shared VPC "to keep things simple"** — subnet-level fencing cannot express trust levels; every team becomes root-equivalent to every other team's blast radius.
- **Full-mesh peering as the growth plan** — route-table sprawl, IP overlap incidents, and no single enforcement point for east-west traffic.
- **Per-spoke internet egress** — each spoke with its own NAT/egress means no single place to inspect, log, filter, or throttle outbound traffic.
- **Public IPs on workloads** — ingress belongs behind load balancers/API gateways in controlled locations, not on compute instances.
- **Overlapping CIDR ranges "we'll fix later"** — blocks peering, hybrid links, and acquisitions forever. Plan the address space before creating the first network.
- **Console-clicked networks** — if it isn't Terraform/IaC, it drifts, and drift in networks equals outages and audit findings.

---

## Standards Map

Deep-dive documents in this series:

| Document | Covers |
|----------|--------|
| [Hub-and-Spoke Setup](./hub-and-spoke-setup.md) | Reference model (what lives in hub vs spoke), implementation on AWS (Transit Gateway), Azure (hub VNet + Firewall), GCP (Shared VPC), cross-provider cheat sheet |
| [API Gateway & Hub Integration](./api-gateway-hub-integration.md) | Gateway placement patterns, private integration with spokes per provider (API Gateway/VPC Link, APIM internal mode, Apigee X/PSC) |
| [PCI Compliance & Topology](./pci-compliance-topology.md) | CDE segmentation design, control-to-location mapping, and whether to run separate PCI vs non-PCI API gateways |

---

## Adoption Checklist

Before the first production workload lands:

- [ ] IPAM plan approved: non-overlapping ranges, headroom reserved per spoke, environments separated
- [ ] Hub deployed via IaC: egress, DNS, logging, admin access all hub-centralized
- [ ] Spoke scaffold module published; teams cannot create networks outside it (policy enforced)
- [ ] Spokes verified private-only: no IGW/NAT/public IPs; egress observable at the hub
- [ ] East-west default-deny confirmed with a test matrix (spoke→spoke, spoke→on-prem, spoke→internet)
- [ ] Diagrams (network + data flows) generated from IaC and stored in-repo
- [ ] If PCI expected: CDE spokes/accounts/folder separated, dedicated inspection path live, [PCI gateway decision](./pci-compliance-topology.md#should-pci-and-non-pci-have-separate-api-gateways) made, segmentation test scheduled
- [ ] API gateway platform registered in the hub; product teams onboarded via spec-first registration, not bespoke gateways

---

## Related Standards

- [API Design](../api-design.md) — contract standards for the APIs these gateways expose
- [Channel vs Domain APIs](../api/channel-vs-domain-apis.md) — what belongs behind the edge vs internal contracts
- [Microservices](../microservices.md) — how spokes map to bounded contexts and team ownership
