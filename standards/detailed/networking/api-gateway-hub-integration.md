# API Gateway & Network Hub Integration

How the API gateway fits into a hub-and-spoke network: placement patterns and private integration with product spokes on AWS, Azure, and GCP. Start with [Cloud Network Topology](./cloud-network-topology.md) for the overall model, and [Hub-and-Spoke Setup](./hub-and-spoke-setup.md) for the underlying network build.

---

## Why the Gateway Is a Network Decision

The API gateway is part of the network architecture, not an afterthought: it is usually the **front door** (north-south ingress) and sometimes the **internal contract point** (east-west). Placing it deliberately keeps TLS termination, authentication, rate limiting, and WAF decisions in one governed location.

## Placement Patterns

| Pattern | Description | Trade-offs |
|---------|-------------|-----------|
| **Edge-fronted hub gateway** (default) | Internet → cloud edge (CDN/WAF/DDoS) → API gateway in hub → private backends in spokes | Best governance; adds one hop; standard choice |
| **Spoke-resident gateway** | Each product runs its own gateway in its spoke; hub only routes | Team autonomy; duplicates policy, certs, and cost; inconsistent client experience |
| **Internal-only gateway** | Gateway reachable only via private endpoints for east-west contracts | Pairs well with edge pattern; do not expose raw spokes publicly |

**Default stance:** one **edge-fronted, hub-resident gateway platform per environment**, with backends always reached privately (no public backend URLs). Product teams register APIs on the platform; they don't run their own unless there's a documented reason.

> Handling cardholder data? See [PCI Compliance & Topology](./pci-compliance-topology.md) — PCI traffic should run on its own dedicated gateway deployment.

---

## AWS — Amazon API Gateway + Private Integration

```
Internet → CloudFront (+ WAF/Shield) → API Gateway (regional, custom domain, ACM)
                                        │  (resource policy: private-only)
                                        ▼
                              VPC Link / Interface VPC Endpoint (execute-api)
                                        │ via Transit Gateway
                              ┌─────────┴──────────┐
                              │ Spoke ALB/NLB      │ → ECS/EKS/Lambda backends
                              └────────────────────┘
```

**Key mechanics:**
- Use **regional** endpoints with ACM certificates; put CloudFront + AWS WAF in front for edge protection.
- Backends integrate via **VPC Link** (HTTP APIs → ALB/NLB; REST APIs → NLB) — the ALB sits in the product spoke, reachable only privately.
- For **private-only APIs**, attach an interface VPC endpoint for `execute-api` in the hub/spokes; enforce with resource policies so the API is unreachable from the internet entirely.
- Route 53 private hosted zones in the hub give spokes consistent private DNS names for internal APIs.

## Azure — API Management (Internal VNet Mode)

```
Internet → Front Door (+ WAF) → Application Gateway (WAF_v2, in hub)
                                   │
                                   ▼
                     APIM (Premium/v2, Internal VNet mode, injected in hub)
                                   │ private endpoints / MTLS
                     ┌─────────────┴─────────────┐
                     │ Spoke backends (App Service│
                     │ with access restrictions,  │
                     │ AKS internal ingresses)    │
                     └────────────────────────────┘
```

**Key mechanics:**
- Run APIM in **Internal mode** injected into the hub: it gets only private IPs; the only way in is through your ingress chain.
- Terminate WAF at **Application Gateway** in the hub; use **Front Door** for global edge/caching when clients are geographically spread.
- Backends are called over **Private Endpoints**; lock App Service/AKS to private-only access so nothing bypasses the gateway.
- Centralize `*.privatelink.*zone` DNS records in hub-linked private DNS zones — the #1 source of Private Link breakage is wrong DNS.

## GCP — Apigee X / API Gateway + Private Service Connect

```
Internet → Global External ALB (+ Cloud Armor WAF)
                │
                ▼
     Apigee X (PSC attachments hosted in hub/host project)
                │ PSC endpoints / internal PASsthrough LB
     ┌──────────┴───────────┐
     │ Spoke backends: GKE  │
     │ internal LBs, Cloud   │
     │ Run via Serverless NEG│
     └───────────────────────┘
```

**Key mechanics:**
- **Apigee X** attaches to your Shared VPC via **PSC attachments** — host the attachments in the hub so gateway traffic is governed like everything else.
- Lightweight option: **Google Cloud API Gateway** + Cloud Armor on the global ALB for simpler estates; upgrade to Apigee when you need quotas, monetization, or developer portals.
- Backends: GKE internal LBs, PSC-negotiated services, or Serverless NEGs for Cloud Run — all private addresses inside the Shared VPC.
- Enable **Private Google Access** so spoke workloads call Google APIs over private paths, keeping egress volume (and inspection cost) down.

---

## Cross-Provider Summary

| Concern | AWS | Azure | GCP |
|---------|-----|-------|-----|
| Managed gateway | Amazon API Gateway | Azure API Management | Apigee X / API Gateway |
| Edge/WAF pairing | CloudFront + AWS WAF | Front Door + App Gateway WAF_v2 | Global ALB + Cloud Armor |
| Private injection | VPC Link / execute-api VPCE | Internal VNet mode (VNet-injected) | PSC attachments into Shared VPC |
| Backend privacy | ALB/NLB in spokes via TGW | Private Endpoints | PSC / internal LBs / NEGs |
| Hub placement | Gateway in ingress VPC; VPCE in hub | APIM in hub VNet | PSC attachments in host project |

---

## Related Standards

- [Cloud Network Topology](./cloud-network-topology.md) — topology choice and series index
- [Hub-and-Spoke Setup](./hub-and-spoke-setup.md) — the network this gateway plugs into
- [PCI Compliance & Topology](./pci-compliance-topology.md) — separate PCI vs non-PCI gateways
- [API Design](../api-design.md) — contract standards for what these gateways expose
