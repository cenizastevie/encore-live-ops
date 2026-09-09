# Encore — Live-Ops Platform

Encore is a learning project that simulates the infrastructure behind ticket
sales and gate entry for a touring concert. It exists to build hands-on,
production-grade understanding of EKS, Kafka, ELK, and agentic development —
see [CLAUDE.md](./CLAUDE.md) for the ground rules this project is built under
(teach-first, not AI-generated).

## What it does

- **Ticket purchases and gate scans** flow through Kafka topics
  (`ticket-purchases`, `ticket-scans`, `ticket-purchases-dlq`).
- **`encore-api`** (FastAPI) consumes those topics, persists processed
  records to Elasticsearch and agent diagnostics to Postgres, and exposes
  `/events`, `/metrics`, `/health`, `/ready`, and `/agent/report`.
- **A live-ops dashboard** shows real pod/replica/consumer-lag state and can
  trigger simulations: spike a ticket drop (HPA scale-up via Karpenter),
  mark the gate scanner unhealthy (liveness probe failure), kill a pod, or
  drain a node.
- **An agentic review layer** periodically inspects logs/metrics with
  read-only access and produces a diagnostic report (e.g. duplicate scans,
  a venue nearing capacity, a degrading gate scanner).

## Architecture

| Layer | Tech |
|---|---|
| Infra | Terraform, AWS EKS, VPC, RDS PostgreSQL, Route 53, ACM |
| Cluster add-ons | Karpenter, AWS Load Balancer Controller, Metrics Server, ExternalDNS, Argo CD |
| Data plane | Kafka (Strimzi, KRaft mode), Elasticsearch + Kibana (ECK) |
| Application | FastAPI (`encore-api`), async SQLAlchemy |
| Agentic layer | AWS Bedrock AgentCore (read-only) |

## Repo layout

This repo is being built incrementally, epic by epic — see
[issue-outline (2).md](<./issue-outline (2).md>) for the full breakdown
(Epic → Issue → Sub-issue, with expected outcomes and docs to read first).

0. **Developer workflow** — pre-commit hooks, TDD, local (docker-compose/kind) → staging (AWS) promotion pipeline
1. **Foundation** — EKS + Terraform (VPC, cluster, add-ons, GitOps, DNS/TLS, RDS)
2. **Data plane** — Kafka + ELK
3. **Application** — `encore-api`
4. **Dashboard** — live-ops UI and failure/load simulations
5. **Agentic review layer**
6. **Hardening and polish**

## Status

Early scaffolding — infrastructure and application code have not been
written yet. Check the issue outline for current progress.

## Working on this project

This repo is governed by [CLAUDE.md](./CLAUDE.md): it's a learning exercise,
so infrastructure and application code are written by Steven, with AI used
for review, concepts, and pointers to documentation rather than as the
implementer.
