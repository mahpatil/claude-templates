# LLM-Native Design Standards

Standards for building systems with Large Language Models as a core architectural primitive — not a bolt-on.

---

## Guiding Philosophy

Traditional AI/ML assumes you train models, build feature pipelines, and serve predictions. LLM-native design starts differently: **the model already knows how to reason — your job is to give it the right context, tools, and guardrails.**

| Traditional ML | LLM-Native |
|----------------|------------|
| Feature stores & pipelines | Context windows & retrieval |
| Model training & retraining | Prompt engineering & evaluation |
| Inference endpoints | Conversational and agentic interfaces |
| Batch predictions | Real-time reasoning with tool use |
| Custom models per task | Foundation models + task-specific prompts |
| Feedback loops for retraining | Feedback loops for prompt & retrieval improvement |

---

## Core Principles

### 1. RAG Over Fine-Tuning

Retrieval-Augmented Generation should be the **default approach** before considering fine-tuning.

**When to use RAG:**
- Domain-specific knowledge that changes frequently
- Need for source attribution and traceability
- Data that must stay within your control boundary
- Cost-sensitive scenarios (no training compute)

**When to consider fine-tuning:**
- Consistent style/tone that prompting alone cannot achieve
- Latency-critical paths where context window size matters
- Highly specialized domain with no existing model capability
- After RAG has been tried and measured insufficient

**RAG Architecture:**
```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  User Query  │────>│  Retriever    │────>│  Vector DB   │
└──────────────┘     │  (Embedding   │     │  (Pinecone,  │
                     │   + Rerank)   │     │   pgvector,  │
                     └───────┬───────┘     │   Qdrant)    │
                             │             └──────────────┘
                     ┌───────▼───────┐
                     │  LLM Call     │
                     │  (Query +     │
                     │   Retrieved   │
                     │   Context)    │
                     └───────┬───────┘
                             │
                     ┌───────▼───────┐
                     │  Response +   │
                     │  Citations    │
                     └───────────────┘
```

**Standards:**
- Chunk documents with overlap (e.g., 512 tokens, 50-token overlap)
- Use hybrid search (semantic + keyword) for better recall
- Always include source metadata in retrieved chunks for attribution
- Implement reranking for precision-critical use cases
- Monitor retrieval quality metrics (hit rate, MRR, NDCG)

---

### 2. Prompt Engineering as a First-Class Discipline

Prompts are code. Treat them with the same rigor as application logic.

**Prompt management standards:**
- Store prompts in version-controlled files, not inline strings
- Use templating (Jinja2, Mustache, or framework-native) for variable injection
- Document prompt intent, expected inputs, and output schema
- Tag prompts with version identifiers for A/B testing and rollback

**Prompt structure:**
```
├── prompts/
│   ├── summarization/
│   │   ├── v1.txt
│   │   ├── v2.txt
│   │   └── config.yaml        # model, temperature, max_tokens
│   ├── classification/
│   │   ├── v1.txt
│   │   └── config.yaml
│   └── agent/
│       ├── system_prompt.txt
│       ├── tool_definitions.yaml
│       └── config.yaml
```

**Best practices:**
- Use system prompts for persona, constraints, and output format
- Provide few-shot examples for complex or ambiguous tasks
- Prefer structured output (JSON, XML) over free-form text for downstream parsing
- Set explicit constraints: what the model should and should NOT do
- Keep prompts modular — compose complex behavior from smaller prompt components

---

### 3. Structured Output & Schema Enforcement

LLM outputs should be machine-parseable by default.

**Standards:**
- Define output schemas using JSON Schema, Pydantic, or Zod
- Use model-native structured output features (e.g., Claude's tool use, OpenAI's JSON mode)
- Validate all LLM output against the schema before processing
- Implement fallback handling for malformed or unexpected responses

**Example — Pydantic schema with validation:**
```python
from pydantic import BaseModel, Field
from enum import Enum

class Sentiment(str, Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"

class ReviewAnalysis(BaseModel):
    sentiment: Sentiment
    confidence: float = Field(ge=0.0, le=1.0)
    key_themes: list[str] = Field(max_length=5)
    summary: str = Field(max_length=200)
```

---

### 4. Agentic Orchestration

Design LLM-powered systems as composable agents with well-defined tools and boundaries.

**Agent architecture patterns:**

| Pattern | Use When | Example |
|---------|----------|---------|
| Single agent + tools | Simple task automation | Customer support bot with KB lookup |
| Multi-agent pipeline | Sequential processing stages | Research → Draft → Review → Publish |
| Router agent | Task requires dynamic delegation | Triage agent routing to specialist agents |
| Human-in-the-loop agent | High-stakes decisions | Approval workflows, content moderation |

**Tool design standards:**
- Each tool has a clear, single-purpose description
- Tool inputs and outputs are strictly typed
- Tools are idempotent where possible
- Tools handle their own errors and return structured error messages
- Limit the number of tools per agent (prefer < 10 for reliability)

**Example — Tool definition:**
```python
tools = [
    {
        "name": "search_knowledge_base",
        "description": "Search the internal knowledge base for articles matching a query. Returns top 5 relevant articles with titles and snippets.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Natural language search query"},
                "category": {"type": "string", "enum": ["billing", "technical", "account"]}
            },
            "required": ["query"]
        }
    }
]
```

**Orchestration guardrails:**
- Set maximum iteration/step limits for agent loops
- Implement timeout boundaries for end-to-end agent execution
- Log every tool call and LLM reasoning step for auditability
- Use structured planning (e.g., ReAct, plan-then-execute) for complex tasks

---

### 5. Evaluation-as-Code

Automated evaluation is the testing framework for LLM systems. Without it, you're shipping vibes.

**Evaluation tiers:**

| Tier | What | How | When |
|------|------|-----|------|
| Unit evals | Individual prompt correctness | Assertions on structured output | Every PR |
| Regression evals | No degradation from changes | Golden dataset comparison | Every PR |
| Scenario evals | End-to-end workflow correctness | Multi-turn conversation tests | Pre-release |
| Human evals | Subjective quality assessment | Annotator scoring (Likert scale) | Periodic |

**Eval infrastructure:**
```
├── evals/
│   ├── datasets/
│   │   ├── summarization_golden.jsonl
│   │   └── classification_golden.jsonl
│   ├── metrics/
│   │   ├── accuracy.py
│   │   ├── faithfulness.py       # Does output match source?
│   │   └── relevance.py          # Is retrieval on-topic?
│   ├── runners/
│   │   └── eval_runner.py
│   └── reports/
│       └── .gitkeep
```

**Key metrics to track:**
- **Accuracy / correctness** — Does the output match expected answers?
- **Faithfulness** — Is the output grounded in the provided context (no hallucination)?
- **Relevance** — Are retrieved documents actually relevant to the query?
- **Latency** — Time-to-first-token and total response time
- **Cost** — Token usage per request, per workflow, per user
- **Tool call success rate** — Do agent tool invocations succeed?

**Standards:**
- Maintain golden datasets of at least 50–100 examples per task
- Run evals in CI — fail the build on regression beyond threshold
- Track eval metrics over time (dashboard, not just pass/fail)
- Use LLM-as-judge for scalable quality assessment, calibrated against human scores
- Never ship a prompt change without running the eval suite

---

### 6. Human-in-the-Loop Guardrails

LLMs are probabilistic. Design systems that acknowledge and manage uncertainty.

**Guardrail layers:**

```
┌─────────────────────────────────────────┐
│           Input Guardrails              │
│  • Prompt injection detection           │
│  • PII/sensitive data filtering         │
│  • Input length and rate limiting       │
├─────────────────────────────────────────┤
│           Model Layer                   │
│  • System prompt constraints            │
│  • Temperature and sampling controls    │
│  • Token budget limits                  │
├─────────────────────────────────────────┤
│           Output Guardrails             │
│  • Schema validation                    │
│  • Content safety filtering             │
│  • Confidence-based routing             │
│  • Hallucination detection              │
├─────────────────────────────────────────┤
│           Human Review                  │
│  • Low-confidence escalation            │
│  • High-stakes action approval          │
│  • Periodic quality audits              │
└─────────────────────────────────────────┘
```

**Standards:**
- Classify actions by risk tier (low / medium / high / critical)
- Low-risk: fully automated (e.g., summarization, search)
- Medium-risk: automated with logging and spot-check audits
- High-risk: automated draft + human approval (e.g., customer-facing content)
- Critical: human-only with AI-assist (e.g., legal, financial decisions)
- Log all LLM inputs and outputs for auditability (with PII redaction)
- Implement kill switches to disable LLM features without full deployment

---

### 7. Observability for LLM Systems

LLM systems require purpose-built observability beyond traditional APM.

**What to instrument:**

| Signal | Examples |
|--------|----------|
| **Latency** | Time-to-first-token, total generation time, retrieval latency |
| **Cost** | Input/output tokens per call, cost per user session |
| **Quality** | Faithfulness scores, user feedback (thumbs up/down), escalation rate |
| **Reliability** | Error rates, retry rates, rate limit hits, timeout rates |
| **Retrieval** | Chunk hit rates, reranking effectiveness, empty result rate |
| **Agent** | Tool call counts, loop iterations, task completion rate |

**Tracing standard:**
- Use distributed tracing (OpenTelemetry) with LLM-specific spans
- Each LLM call is a span with attributes: model, prompt_tokens, completion_tokens, latency
- Each retrieval step is a span with attributes: query, num_results, top_score
- Each tool call is a span with attributes: tool_name, input, output, success

**Recommended tooling:**
- OpenTelemetry for trace/metric collection
- LangSmith, Langfuse, or Arize for LLM-specific observability
- Custom dashboards for cost tracking and quality trends

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Instead |
|-------------|--------------|---------|
| Dumping entire documents into context | Exceeds token limits, dilutes relevance | Use RAG with chunking and reranking |
| Hardcoding prompts in application code | Impossible to iterate, test, or version | Store prompts as versioned artifacts |
| No eval suite | "It works on my prompt" — ships regressions | Build evals before shipping features |
| Fine-tuning as first approach | Expensive, slow iteration, overfitting risk | Start with RAG + prompt engineering |
| Trusting LLM output without validation | Hallucinations, schema violations | Always validate and type-check output |
| Unlimited agent loops | Infinite loops, runaway costs | Set step limits and timeout boundaries |
| Ignoring token costs | Surprise bills, unsustainable scaling | Budget per request, monitor per user |
| Single monolithic prompt | Hard to maintain, debug, or reuse | Compose from modular prompt components |

---

## Technology Recommendations

| Category | Recommended | Notes |
|----------|-------------|-------|
| **LLM Providers** | Anthropic Claude, OpenAI GPT | Use provider abstraction layer for portability |
| **SDKs** | Anthropic SDK, OpenAI SDK | Prefer official SDKs; avoid unnecessary wrappers |
| **Orchestration** | LangChain, LlamaIndex, Claude Agent SDK | Choose based on complexity; simpler is better |
| **Vector Stores** | pgvector, Qdrant, Pinecone | pgvector for existing Postgres; managed for scale |
| **Embeddings** | Voyage, OpenAI, Cohere | Match embedding model to your retrieval domain |
| **Eval Frameworks** | promptfoo, Braintrust, custom | Integrate into CI pipeline |
| **Observability** | Langfuse, LangSmith, Arize | LLM-specific tracing and cost tracking |
| **Guardrails** | Guardrails AI, custom validators | Schema validation + content safety |

---

## Decision Framework

### When to use an LLM vs traditional code

```
Is the task deterministic with clear rules?
  ├─ YES → Use traditional code (regex, rules engine, SQL)
  └─ NO → Does it require understanding natural language?
            ├─ YES → Use an LLM
            │         ├─ Is the domain knowledge static? → RAG
            │         ├─ Is the output structured? → Structured output + validation
            │         └─ Does it need to take actions? → Agent with tools
            └─ NO → Use traditional ML (classification, regression, clustering)
```

### Model selection guidance

| Factor | Smaller/Faster Model | Larger/Capable Model |
|--------|---------------------|---------------------|
| Task complexity | Simple classification, extraction | Complex reasoning, multi-step |
| Latency requirement | < 500ms | Can tolerate 2-5s |
| Cost sensitivity | High volume, low value per call | Low volume, high value per call |
| Accuracy requirement | Good enough (> 90%) | Must be near-perfect |

---

## Checklist for LLM Feature Launch

- [ ] Prompts stored in version control with clear ownership
- [ ] Output schema defined and validated on every response
- [ ] Eval suite with golden dataset running in CI
- [ ] Input guardrails: injection detection, PII filtering, rate limiting
- [ ] Output guardrails: content safety, confidence routing, schema validation
- [ ] Observability: latency, cost, quality metrics dashboarded
- [ ] Cost budget defined per request/user/workflow
- [ ] Human escalation path for low-confidence or high-risk outputs
- [ ] Kill switch to disable LLM feature without full redeploy
- [ ] Documentation: prompt intent, expected behavior, known limitations
