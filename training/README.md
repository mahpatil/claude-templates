# Cloud-Native & Microservices Training

Complete training materials for teams new to cloud-native, microservices, and AI-native development.

## Modules

### [📖 Module 1: The Journey - Why We're Here](./01-The-Journey.md)
The story of monolithic architecture's challenges. Learn why cloud-native and microservices exist.
- The evolution from 2010 to 2024
- Pain points of the monolith
- Why transformation is needed

### [🏗️ Module 2: Monolith Pain Points](./02-Monolith-Pain.md)
Deep dive into the real problems teams face with monolithic architecture.
- Tight coupling and dependencies
- Inefficient scaling and wasted resources
- Slow release cycles
- Technology lock-in
- Team scaling challenges
- Deployment risks

### [🚀 Module 3: Cloud-Native Microservices](./03-Microservices.md)
Introduction to microservices architecture and core principles.
- Single responsibility principle
- Independent deployment
- Technology autonomy
- Scalability - scale what matters
- Fault isolation

### [🎯 Module 4: Domain-Driven Design Concepts](./04-DDD-Concepts.md)
Domain-Driven Design techniques for identifying service boundaries.
- Bounded contexts
- Ubiquitous language
- Entities vs value objects
- Aggregates
- Repositories
- The DDD design process

### [🔄 Module 5: Problem-Solution Patterns](./05-Problem-Solution.md)
Real-world comparisons of monolith vs microservices approaches.
- Problem 1: Multiple teams, one codebase
- Problem 2: Scaling bottlenecks
- Problem 3: Technology evolution
- Problem 4: Feature development speed

### [📚 Module 6: Cloud-Native Principles](./06-Principles.md)
The 13 core cloud-native principles and engineering tenets.
- Composable architecture & DDD
- API-first & contract-driven
- Cloud portability
- Observability
- Zero trust security
- Performance, availability, reliability
- Cost optimization, automation, infrastructure as code
- AI-first design
- Open source & open standards

### [🗺️ Module 7: Implementation Roadmap](./07-Roadmap.md)
A 10-week transformation plan and discussion questions.
- Week 1-2: Foundation
- Week 3-4: Domain mapping
- Week 5-6: Architecture design
- Week 7-10: Extract first service
- Week 11+: Scale
- Discussion questions for your team
- Success metrics

### [🤖 Module 8: AI-Native Development](./08-AI-Native-Development.md)
Building AI capabilities into cloud-native microservices from day one.
- Plan-Build-Test-Deploy-Monitor workflow
- Phase 1: Planning (identifying opportunities, success metrics)
- Phase 2: Building (data pipelines, feature stores, model serving)
- Phase 3: Testing (accuracy, latency, bias, drift detection)
- Phase 4: Deploying (canary, A/B testing, shadow mode, blue-green)
- Continuous learning and monitoring
- Real-world recommendation engine example
- Integration with microservices

---

## How to Use This Training

### For Self-Study
1. Read modules in order
2. Discuss each module with your team
3. Answer the discussion questions
4. Identify your first service to extract

### For Team Workshops
1. **Session 1 (2 hours):** Modules 1-2 (Why change? Monolith pain)
2. **Session 2 (2 hours):** Modules 3-4 (Microservices & DDD)
3. **Session 3 (2 hours):** Modules 5-6 (Problems, solutions, principles)
4. **Session 4 (2 hours):** Modules 7-8 (Roadmap & AI-Native)

### For Executives
Focus on:
- Module 1 (the business case)
- Module 5 (problem-solution patterns with time/cost metrics)
- Module 7 (the roadmap and timeline)

---

## Key Discussion Questions

**On Your Current System:**
- What are your top 3 pain points?
- If you could fix one thing, what would have the biggest impact?
- How often can you currently deploy to production?

**On Service Boundaries:**
- What are your core business capabilities?
- Where do teams currently clash?
- Can you identify 5-10 potential bounded contexts?

**On Cloud-Native Goals:**
- How often would you like to deploy? (daily? per-commit?)
- What's your biggest cloud cost concern?
- What observability gaps exist today?

**On First Steps:**
- Which service should you extract first?
- What would success look like?
- How would you measure improvement?

---

## Recommended Resources

- **Domain-Driven Design** by Eric Evans (20 hours)
- **Building Microservices** by Sam Newman (15 hours)
- **12-Factor App** (2 hours) - https://12factor.net
- **Event Storming Workshop** (1 day)
- **Kubernetes in Action** (20 hours)

---

## Next Steps

1. ✅ Read all modules (target: this week)
2. ✅ Schedule team workshop (target: next week)
3. ✅ Run event storming workshop (target: week 3)
4. ✅ Create service roadmap (target: week 4)
5. ✅ Pick pilot service (target: week 5)
6. ✅ Begin extraction (target: week 7)

---

## Files in This Directory

- `01-The-Journey.md` - Module 1
- `02-Monolith-Pain.md` - Module 2
- `03-Microservices.md` - Module 3
- `04-DDD-Concepts.md` - Module 4
- `05-Problem-Solution.md` - Module 5
- `06-Principles.md` - Module 6
- `07-Roadmap.md` - Module 7
- `08-AI-Native-Development.md` - Module 8
- `README.md` - This file
- `index.html` - Interactive HTML version (for diagram insertion)
- `PRINCIPLES_Training.md` - Original combined training document

---

## Tips for Adding Diagrams

For each module, you can add diagrams in common formats:
- **ASCII Art:** Use code blocks (\`\`\`)
- **Mermaid:** Use mermaid syntax in code blocks
- **Images:** Insert PNG/JPG files
- **Excalidraw:** Embed interactive diagrams
- **PlantUML:** Use plant UML syntax

Example:
\`\`\`mermaid
graph TD
    A[Start] --> B[Process] --> C[End]
\`\`\`

---

This training material is living documentation. Update it with your team's learnings, examples from your domain, and lessons from your migration.

Last updated: February 2024
