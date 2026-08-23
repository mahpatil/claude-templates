# Hub-and-Spoke Setup on AWS, Azure, and GCP

Implementation guide for the hub-and-spoke network model: what lives in the hub versus spokes, non-negotiable rules, and step-by-step setup per cloud provider. Start with [Cloud Network Topology](./cloud-network-topology.md) for when to choose this model.

---

## Reference Model: What Lives Where

| Component | Location | Rationale |
|-----------|----------|-----------|
| Egress (NAT) + internet edge | Hub | Single point for filtering, logging, and egress policy |
| Ingress (WAF, load balancer, API gateway) | Hub or dedicated ingress spoke | One front door; consistent TLS, authN, rate limiting — see [API Gateway & Hub Integration](./api-gateway-hub-integration.md) |
| Site-to-site connectivity (VPN/dedicated interconnect) | Hub | Attach on-prem once, reachable everywhere (controlled) |
| DNS resolution (private zones, resolvers) | Hub | Consistent name resolution across all spokes and hybrid |
| Centralized logging/mirror targets, SIEM feeders | Hub | Network telemetry lands in one auditable place |
| Admin access (bastion/privileged session service) | Hub | No SSH/RDP paths scattered across spokes |
| Product workloads (apps, DBs, queues) | Spokes | Teams own their spoke; platform owns the hub |
| Environment separation (prod/non-prod) | Separate spokes at minimum; better: separate hubs | Prod hygiene and compliance isolation |

## Non-Negotiable Rules

**What this means:**
- **Spokes have no direct internet path.** No IGW/NAT/public IPs in spokes; `0.0.0.0/0` routes to the hub.
- **Spoke-to-spoke traffic flows through the hub** (where inspection/policy lives) — or is explicitly denied. Never implicit any-to-any.
- **One owner per spoke; platform team owns the hub.** Spoke teams can't modify routes to the hub; platform can't reach into spoke subnets uninvited.
- **Non-overlapping, centrally planned CIDRs.** Maintain the IP address management (IPAM) plan before provisioning; reserve generous headroom per spoke (e.g., `/20`+) because resizing later hurts.
- **Private-by-default service exposure.** Cross-spoke services are exposed via private endpoints/private link technologies, not public URLs.
- **Everything as code.** Hub and spoke scaffolding ships as reusable Terraform modules with policy-as-code guardrails (deny public IP, require flow logs, require tags).

```
                        INTERNET
                           │
                    ┌──────▼──────┐
                    │     HUB     │  WAF · API GW · FW/NVA
                    │             │  NAT egress · VPN/DX/Interconnect
                    │             │  DNS · Logging · Bastion
                    └──┬───┬───┬──┘
              inspected│   │   │inspected (or denied)
                 ┌─────┘   │   └─────┐
           ┌─────▼───┐ ┌───▼────┐ ┌──▼──────┐
           │ SPOKE A │ │ SPOKE B│ │ SPOKE C │
           │ product │ │ product│ │ CDE/PCI │  ← dedicated, see PCI standard
           └─────────┘ └────────┘ └─────────┘
```

---

## AWS — Transit Gateway Hub

**Building blocks:** Transit Gateway (TGW) as the hub router, shared cross-account via Resource Access Manager; central egress VPC (NAT gateways); optional inspection VPC (Gateway Load Balancer + firewall appliance); Route 53 Resolver endpoints for hybrid/private DNS; PrivateLink for private cross-account service exposure.

| Concern | AWS Implementation |
|---------|--------------------|
| Hub router | AWS Transit Gateway, one TGW route table per environment/trust zone |
| Spoke attachment | Per-VPC TGW attachment; spoke route `0.0.0.0/0 → TGW` |
| Egress | Central egress VPC: NAT GWs per AZ, TGW routes back to spokes |
| Inspection | Inspection VPC with GWLB + third-party IDS/IPS (optional, common for PCI) |
| DNS | Route 53 Resolver inbound/outbound endpoints in hub; shared private hosted zones |
| Private service exposure | PrivateLink endpoint services (spoke-to-spoke without routing through hub) |
| Guardrails | SCPs denying IGW/NAT creation outside egress account; `aws:PrincipalOrgPaths` conditions |

**Build order:**
1. Create a network account (the hub account) holding the TGW, egress VPC, and DNS endpoints.
2. Share the TGW to the organization via RAM; define TGW route tables so dev/staging/prod/CDE are isolated from each other by default.
3. Scaffold a spoke module: VPC with private subnets only, TGW attachment, routes (`local`, `0.0.0.0/0 → TGW`), flow logs to central S3.
4. Add the inspection VPC when east-west/west-east inspection is required (do it before PCI scope lands — see [PCI Compliance & Topology](./pci-compliance-topology.md)).
5. Enforce guardrails: SCP denies public IP/IGW in spoke OUs; Config rules alert on drift.

> **Alternative:** AWS Cloud WAN (managed core network with policy documents) replaces hand-built TGW route tables at larger scale. Start with plain TGW; adopt Cloud WAN when multi-region complexity demands it.

---

## Azure — Hub VNet with Azure Firewall

**Building blocks:** Hub VNet hosting Azure Firewall, VPN/ExpressRoute gateways, Bastion, and private DNS zones; VNet peering to spokes; User-Defined Routes steering spoke traffic to the firewall; Azure Policy enforcing guardrails. Azure Virtual WAN is the managed alternative for many regions/branches.

| Concern | Azure Implementation |
|---------|----------------------|
| Hub router | Hub VNet + VNet peering (no transitive peering in Azure — hub provides the transit) |
| Spoke attachment | Bidirectional peering: hub↔spoke with *allow forwarded traffic*; spoke uses *remote gateway* |
| Egress | Azure Firewall in hub; UDR `0.0.0.0/0 → AzureFirewallSubnet` on every spoke subnet |
| Inspection | Same Azure Firewall (with IDPS Premium tier) or partner NVA; forced tunneling for egress review |
| DNS | Private DNS zones linked to hub; Azure Firewall DNS proxy for spoke resolvers |
| Private service exposure | Private Endpoints (Private Link) per consuming spoke; centralize DNS zone records in hub |
| Guardrails | Azure Policy: deny public IPs, require UDRs, require NSG flow logs; Management Group hierarchy |

**Build order:**
1. Create a connectivity Subscription (hub) inside a dedicated Management Group.
2. Deploy hub VNet with `AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`; deploy Azure Firewall (Premium when PCI/IDPS needed) with explicit allow-rule sets.
3. Define the spoke Terraform module: peering to hub, UDR default route to firewall, NSG flow logs → Log Analytics, no public IPs.
4. Host private DNS zones in the hub; link every spoke; wire Private Endpoint DNS via conditional forwarders/resolver.
5. Apply Azure Policy assignments at the Management Group level so nothing non-compliant can be created anywhere.

> **Alternative:** Azure Virtual WAN (vWAN) — managed hubs with built-in routing intent and branch connectivity. Prefer plain hub VNet for a first build (more transparent); move to vWAN for many-region/multi-branch estates.

---

## GCP — Shared VPC as the Hub

GCP differs structurally: **Shared VPC makes the hub a *project*, not a separate network.** A host project owns the VPC; service projects attach and consume subnets via IAM. All spokes live inside one VPC, so east-west traffic never needs peering — but VPC *peering* itself is non-transitive, so never mix Shared VPC with peered-spoke designs.

| Concern | GCP Implementation |
|---------|--------------------|
| Hub router | Shared VPC host project (one VPC, folders per environment recommended) |
| Spoke attachment | Service projects attached to host project; IAM grants specific subnets |
| Egress | Cloud NAT + Cloud Router in host project; per-region NAT for deterministic IPs |
| Inspection | Third-party NGFW via Network Connectivity Center (NCC) spoke/endpoint or mirrored deployments; hierarchical firewall policies at org/folder level |
| DNS | Cloud DNS private zones + inbound/outbound server policies on the host project |
| Private service exposure | Private Service Connect (PSC) — publish/consume services privately, including Google APIs via PSC endpoints |
| Guardrails | Org Policy: `constraints/compute.vmExternalIpAccess`, `compute.disableSerialPortAccess`; hierarchical firewall policies |

**Build order:**
1. Create a host project under a `networking` folder; enable Shared VPC; attach product service projects.
2. Design subnets per environment/team with secondary ranges reserved for GKE; no overlaps ever.
3. Deploy Cloud Router + Cloud NAT in the host project; spokes get private-only VMs/Pods.
4. Set Cloud DNS server policies and private zones in the host project; enable Private Google Access for API traffic that never needs to leave Google's fabric.
5. Layer hierarchical firewall policies (org → folder → VPC) so baseline deny/allow rules exist before any spoke team creates its first rule.

> **Multi-cloud note:** If you run two or three clouds, mirror the *same logical model* everywhere — hub holds egress/inspection/DNS/ingress, spokes hold workloads, CDE isolated ([PCI details](./pci-compliance-topology.md)) — even though the primitives differ. Consistency beats per-cloud cleverness.

---

## Cross-Provider Cheat Sheet

| Capability | AWS | Azure | GCP |
|------------|-----|-------|-----|
| Hub construct | Transit Gateway (+ egress VPC) | Hub VNet / vWAN hub | Shared VPC host project |
| Spoke construct | VPC + TGW attachment | Spoke VNet + peering | Service project + subnets |
| Central firewall | GWLB + NVA (or Network Firewall) | Azure Firewall (IDPS Premium) | NVA via NCC / hierarchical policies |
| Private cross-team services | PrivateLink | Private Endpoint/Private Link | Private Service Connect |
| Hybrid entry | Direct Connect/VPN on hub CGW | ExpressRoute/VPN GW in hub | Interconnect/HA VPN via Cloud Router |
| Managed DNS | Route 53 + Resolver endpoints | Azure Private DNS + resolver | Cloud DNS + server policies |
| Guardrail engine | SCPs + Config | Azure Policy + MG hierarchy | Org Policies + hierarchical FW |

---

## Related Standards

- [Cloud Network Topology](./cloud-network-topology.md) — choosing between topology models
- [API Gateway & Hub Integration](./api-gateway-hub-integration.md) — where the ingress front door lives
- [PCI Compliance & Topology](./pci-compliance-topology.md) — segmenting CDE spokes within this model
