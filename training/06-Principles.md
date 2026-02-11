[← Back to Index](./INDEX.md)

# 📚 Module 6: Cloud-Native Core Principles

## The 13 Core Principles

### Principle 1: Composable Architecture & DDD
Design services around business domains (bounded contexts), not technical layers.

✅ **Good:** Orders Service, Payments Service, Users Service (business domains)
❌ **Bad:** Database Service, Cache Service, API Service (technical layers)

### Principle 2: API-First & Contract-Driven
Services communicate via clear contracts (REST APIs, gRPC, events).

```
Orders Service → Payments Service

Contract:
POST /payments/authorize
{
  "orderId": "12345",
  "amount": 75.99,
  "currency": "USD"
}

Response:
{
  "transactionId": "txn_abc123",
  "status": "authorized",
  "timestamp": "2024-02-11T10:30:00Z"
}
```

Both teams agree on this contract. Implementation can change independently.

### Principle 3: Cloud Portability
Avoid vendor lock-in. Use open standards.

✅ **Good:** Docker (portable containers), Kubernetes (portable orchestration), PostgreSQL, OpenTelemetry
❌ **Bad:** AWS Lambda-specific code, Azure App Services, proprietary frameworks

### Principle 4: Observability
Logs, metrics, and traces are first-class citizens.

Every service must provide:
- **Logs:** What happened (errors, state changes)
- **Metrics:** How much (request count, latency, errors)
- **Traces:** Where the request went (across services)

### Principle 5: Zero Trust Security
Authenticate and authorize every request, at every layer.

- Service A calls Service B? Must authenticate.
- User makes API call? Must authenticate and authorize.
- Internal network? Still not trusted.

### Principle 6: Performance Optimization
Optimize where it matters. Measure first, optimize second.

- Caching (Redis for frequently accessed data)
- Compression (gzip responses)
- Efficient algorithms (don't loop when you can query)
- Async processing (don't make users wait)

### Principle 7: High Availability
Design for failure. Services should be redundant.

- Multiple instances running
- Load balancer routes around failures
- Graceful degradation (lose features, not data)
- Geographic redundancy

### Principle 8: Reliability & Resilience
Services should handle failures gracefully.

```
Order Service calls Payments Service.
Payments is down (network issue, deployment).

Reliable approach:
try:
  payment = paymentsService.authorize(order)
catch PaymentServiceUnavailable:
  // Don't crash. Handle it.
  queue_payment_for_retry()
  mark_order_as_pending_payment()
  return to user: "We're processing your payment. Check back soon."
```

### Principle 9: Cost Optimization
Cloud is cheap, but careless usage is expensive.

- Right-size instances (don't over-provision)
- Auto-scaling (scale down when not needed)
- Use spot instances for non-critical work
- Monitor cloud spend continuously

### Principle 10: Automation First
Manual processes don't scale.

- CI/CD pipeline (automate deployments)
- Automated testing (catch bugs before production)
- Security scanning (find vulnerabilities automatically)
- Infrastructure as Code (version-controlled, reproducible)

### Principle 11: Infrastructure as Code
Infrastructure is code. Version control it. Reproduce it.

```
Before (Manual):
1. SSH into server
2. Run apt-get install nodejs
3. Copy config files
4. Start service
Hope you remember every step. Hope it's documented.

After (IaC - Terraform/CloudFormation):
resource "aws_ec2_instance" "payment_service" {
  ami           = "ami-0c02d3d5cb0d24d67"
  instance_type = "t3.medium"

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install nodejs
    ${file("${path.module}/config.json")}
  EOF
}

Benefits:
✓ Reproducible (run once or 100 times, same result)
✓ Version controlled (see what changed, when, who)
✓ Code reviewable (changes go through review)
✓ Testable (run in staging first)
```

### Principle 12: AI-First Design
Design systems to leverage AI from the start.

- Inference endpoints for ML models
- Feature stores for data
- Feedback loops to improve models
- Not bolted on, integrated from beginning

### Principle 13: Open Source & Open Standards
Prefer open standards over proprietary solutions.

✅ **Good:** Kubernetes, PostgreSQL, OpenTelemetry, OAuth2, gRPC
❌ **Bad:** Custom cloud platform, proprietary database, custom protocols

**Benefits:** Community support, portability, long-term sustainability, cost.

---

## Core Engineering Tenets

These principles guide all decisions:

| Tenet | Meaning | Example |
|-------|---------|---------|
| **Clarity over cleverness** | Write obvious code, not clever code | `if !order.isPaid { return error }` instead of `order.paid?&.process()` |
| **Small, safe changes** | Ship small, testable changes frequently | 1 feature per PR, not 50 features at once |
| **Separation of concerns** | Each component does one thing | Orders Service ≠ Payments Service |
| **Defensive boundaries** | Validate inputs at edges | API validates requests; internal code trusts validated data |
| **Observability-first** | Logs, metrics, traces built-in | Every service logs decisions, metrics, traces |
| **Consistency across teams** | Shared practices and vocabulary | All services use same logging format, naming conventions |
| **Data-driven decisions** | Metrics over opinions | "This is slower" → measure it, find the bottleneck |
| **Quality & security built-in** | Not added later | Tests, security scans in CI/CD pipeline |
| **Living documentation** | Documentation stays current | Auto-generated from code where possible |
| **Continuous learning** | Retrospectives, post-mortems, evolution | After incidents, ask "what can we learn?" |

---

[← Back to Index](./INDEX.md) | [Previous: Module 5](./05-Problem-Solution.md) | [Next: Module 7 →](./07-Roadmap.md)
