# Project Outline — Issue-Ready Breakdown

**Project name: Encore** — a live-ops platform for a concert ticketing pipeline.
Every component below is named as if this were the real infrastructure team
behind ticket sales and gate entry for a touring show, because that concrete
scenario is what makes each piece testable and demoable instead of abstract.

Format: **Epic → Issue → Sub-issue**, each sub-issue has an **Expected Outcome**
(what "done" looks like) and **Read First** (docs to read before starting —
per CLAUDE.md, read these before writing anything, don't skip to code).

---

## Epic 0: Developer Workflow — Pre-commit, TDD, Local → Staging

Everything below assumes this workflow exists first: tests are written
before the implementation (TDD), nothing lands without passing pre-commit
checks, and every change is proven locally before it ever touches a real
AWS staging environment.

### Issue 0.1 — Pre-commit hooks
**Sub-issue 0.1.1 — Terraform hooks (fmt, validate, tflint, tfsec/checkov)**
- Expected outcome: `git commit` fails on unformatted HCL, a broken
  `terraform validate`, a tflint violation, or a tfsec/checkov high-severity
  finding — before it ever reaches CI.
- Read first: https://github.com/antonbabenko/pre-commit-terraform

**Sub-issue 0.1.2 — Python hooks (ruff/black, mypy, pytest-on-push)**
- Expected outcome: `git commit` on `encore-api` fails on lint/format
  violations or type errors; the full pytest suite runs at push time (or in
  CI) and blocks merge on failure.
- Read first: https://pre-commit.com/

### Issue 0.2 — TDD for `encore-api`
**Sub-issue 0.2.1 — Write the failing test before the route/consumer logic**
- Expected outcome: Every new endpoint or consumer behavior (e.g. rejecting
  a malformed purchase event, routing a duplicate `ticket_id` to the DLQ)
  has a test written and confirmed failing *before* the implementation is
  written, per CLAUDE.md's teach-first workflow.
- Read first: https://fastapi.tiangolo.com/tutorial/testing/

**Sub-issue 0.2.2 — Integration tests against real Kafka/Postgres/ES via testcontainers**
- Expected outcome: CI spins up ephemeral Kafka, Postgres, and Elasticsearch
  containers to run consumer/DB/search integration tests — not mocks that
  could silently drift from real behavior.
- Read first: https://testcontainers-python.readthedocs.io/

### Issue 0.3 — Local environment (before touching AWS)
**Sub-issue 0.3.1 — docker-compose stack for Kafka + Postgres + ES**
- Expected outcome: `docker compose up` gives a fully working local Kafka,
  Postgres, and Elasticsearch that `encore-api` can run against on a
  developer machine, with zero AWS dependency.
- Read first: https://docs.docker.com/compose/

**Sub-issue 0.3.2 — Local Kubernetes (kind) mirroring the staging shape**
- Expected outcome: A `kind` cluster where Strimzi, ECK, and `encore-api`
  can be deployed with the same manifests/Helm values used in staging
  (minus cloud-specific resources like ALB/IRSA), so manifest bugs are
  caught before a real AWS deploy.
- Read first: https://kind.sigs.k8s.io/

### Issue 0.4 — Staging environment on AWS
**Sub-issue 0.4.1 — Separate Terraform state/workspace per environment**
- Expected outcome: `staging` and (eventually) `prod` use isolated Terraform
  state and variable files — a staging `terraform apply` can never touch
  production resources.
- Read first: https://developer.hashicorp.com/terraform/language/state/workspaces

**Sub-issue 0.4.2 — Environment-scoped Argo CD Applications**
- Expected outcome: Argo CD tracks a `staging` branch/overlay separately
  from `prod`, so a merge to `main` deploys to staging automatically but
  production requires a separate, deliberate promotion step.
- Read first: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

### Issue 0.5 — Promotion pipeline: local → staging
**Sub-issue 0.5.1 — CI gate: pre-commit + full test suite required before staging deploy**
- Expected outcome: A PR cannot merge (and therefore cannot reach staging
  via Argo CD) unless pre-commit checks and the full test suite (Issue 0.2)
  pass in CI.
- Read first: (none — this wires together 0.1, 0.2, and 0.4)

---

## Epic 1: Foundation — EKS + Terraform

### Issue 1.1 — Networking (VPC)
**Sub-issue 1.1.1 — Provision VPC with private subnets + NAT**
- Expected outcome: A VPC with public + private subnets across ≥2 AZs, a NAT gateway, and route tables correctly associated. No workload runs in a public subnet.
- Read first: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

**Sub-issue 1.1.2 — Security groups and network boundaries**
- Expected outcome: Security groups scoped to only the ports/protocols actually needed between the cluster, RDS, and the internet-facing ALB.
- Read first: https://kubernetes.io/docs/concepts/services-networking/network-policies/

### Issue 1.2 — EKS Cluster
**Sub-issue 1.2.1 — Provision the `encore` cluster via terraform-aws-modules/eks**
- Expected outcome: A working EKS cluster named `encore` provisioned entirely by Terraform, with a **restricted (private or IP-allowlisted) API endpoint**.
- Read first: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest

**Sub-issue 1.2.2 — Configure IRSA (IAM Roles for Service Accounts)**
- Expected outcome: The `encore-api` pod assumes AWS permissions through IRSA rather than a broad node IAM role. You should be able to explain why this matters (blast radius).
- Read first: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html

### Issue 1.3 — Cluster Add-ons
**Sub-issue 1.3.1 — Install Karpenter**
- Expected outcome: Simulating a ticket-drop load spike (Epic 4) causes Karpenter to provision a new node automatically, visible via `kubectl get nodes -w`.
- Read first: https://karpenter.sh/docs/

**Sub-issue 1.3.2 — Install AWS Load Balancer Controller**
- Expected outcome: An Ingress for `encore-api` results in a real ALB being created and routing traffic to the pod.
- Read first: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/

**Sub-issue 1.3.3 — Install Metrics Server**
- Expected outcome: `kubectl top pods` returns real CPU/memory numbers for `encore-api` (required for HPA to function later).
- Read first: https://kubernetes-sigs.github.io/metrics-server/

### Issue 1.4 — GitOps
**Sub-issue 1.4.1 — Install and configure Argo CD**
- Expected outcome: A change pushed to the `encore` Git repo (e.g. bumping `encore-api`'s replica count) is automatically applied to the cluster without a manual `kubectl apply`.
- Read first: https://argo-cd.readthedocs.io/en/stable/

### Issue 1.5 — DNS and TLS (Route 53 + ACM + ExternalDNS)
**Sub-issue 1.5.1 — Create Route 53 hosted zone for `encore.<yourdomain>.com`**
- Expected outcome: A hosted zone exists for the `encore` subdomain, with NS records correctly delegated from the parent zone.
- Read first: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html

**Sub-issue 1.5.2 — Request an ACM certificate for `encore.<yourdomain>.com`**
- Expected outcome: A DNS-validated ACM certificate covering the Encore domain (and `*.encore.<yourdomain>.com` if you want per-venue subdomains later).
- Read first: https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html

**Sub-issue 1.5.3 — Attach the certificate to the ALB via Ingress annotations**
- Expected outcome: `https://encore.<yourdomain>.com` serves the live-ops dashboard over HTTPS; HTTP redirects to HTTPS.
- Read first: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/

**Sub-issue 1.5.4 — Install ExternalDNS with IRSA-scoped Route 53 access**
- Expected outcome: Creating/deleting the Encore Ingress automatically creates/deletes the matching Route 53 record. IAM policy scoped to only the `encore` hosted zone, not `hostedzone/*`.
- Read first: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md

### Issue 1.6 — Relational Data Layer (RDS)
**Sub-issue 1.6.1 — Provision RDS PostgreSQL (`encore-db`) via terraform-aws-modules/rds**
- Expected outcome: A private-subnet-only RDS PostgreSQL instance with automated backups and `deletion_protection` enabled, storing agent diagnostics and show/venue metadata.
- Read first: https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest

**Sub-issue 1.6.2 — Enable IAM database authentication**
- Expected outcome: `encore-api` connects to `encore-db` using a short-lived IAM auth token via its IRSA role, not a static password.
- Read first: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html

**Sub-issue 1.6.3 — Security group lockdown**
- Expected outcome: `encore-db`'s security group allows inbound only from the EKS pod security group on the Postgres port.
- Read first: https://kubernetes.io/docs/concepts/services-networking/network-policies/

---

## Epic 2: Data Plane — Kafka + ELK

### Issue 2.1 — Kafka via Strimzi
**Sub-issue 2.1.1 — Install Strimzi Cluster Operator**
- Expected outcome: Operator pod running; CRDs (`Kafka`, `KafkaTopic`, `KafkaUser`) available.
- Read first: https://strimzi.io/documentation/

**Sub-issue 2.1.2 — Deploy Kafka in KRaft mode with Encore's topics**
- Expected outcome: A Kafka cluster with three topics — `ticket-purchases`, `ticket-scans` (gate entry), and `ticket-purchases-dlq` — created via `KafkaTopic` custom resources. You can produce and consume a test purchase event via `kubectl exec`.
- Read first: https://strimzi.io/documentation/

**Sub-issue 2.1.3 — Add schema registry for the ticket-purchase event shape**
- Expected outcome: Producers/consumers validate messages against a registered schema for `{ticket_id, show_id, venue, seat, price, fan_id, purchase_time}`. A malformed purchase event is rejected, not silently accepted.
- Read first: https://strimzi.io/documentation/

**Sub-issue 2.1.4 — Route failed purchases to the dead-letter topic**
- Expected outcome: A purchase event that fails processing (e.g. duplicate ticket_id — a fraud signal) lands in `ticket-purchases-dlq` instead of blocking the consumer.
- Read first: https://strimzi.io/documentation/

### Issue 2.2 — ELK via ECK
**Sub-issue 2.2.1 — Install ECK operator**
- Expected outcome: Operator running; `Elasticsearch` and `Kibana` CRDs available.
- Read first: https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/install

**Sub-issue 2.2.2 — Deploy Elasticsearch + Kibana**
- Expected outcome: Kibana reachable, cluster health green, TLS enabled by default.
- Read first: https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s

**Sub-issue 2.2.3 — Ship logs with Filebeat DaemonSet**
- Expected outcome: Logs from `encore-api` and Kafka brokers are searchable in Kibana — e.g. you can search for a specific `ticket_id` across the pipeline.
- Read first: https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s

**Sub-issue 2.2.4 — Configure Index Lifecycle Management (ILM)**
- Expected outcome: Log indices roll over and expire automatically — they don't grow unbounded across ticket-drop events.
- Read first: https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s

---

## Epic 3: Application — `encore-api` (FastAPI Service)

Every sub-issue in this epic follows Epic 0's TDD loop (Issue 0.2): write
the failing test against the local docker-compose stack (Issue 0.3) first,
then implement, then verify pre-commit and the full suite pass before
merging — merges to `main` promote to staging per Issue 0.4/0.5.

### Issue 3.1 — Kafka consumer service
**Sub-issue 3.1.1 — Async consumer for `ticket-purchases` and `ticket-scans`**
- Expected outcome: `encore-api` consumes both topics and writes processed records into Elasticsearch, running as an async background task alongside the API. A failing integration test (Issue 0.2.2) exists for the happy path and for a malformed event before the consumer code is written.
- Read first: https://fastapi.tiangolo.com/advanced/events/

### Issue 3.2 — Health and readiness
**Sub-issue 3.2.1 — Implement meaningful `/health` and `/ready`**
- Expected outcome: `/health` fails if the consumer loop has died or Elasticsearch is unreachable — not a hardcoded 200. This is what makes the "make gate unhealthy" simulation in Epic 4 real.
- Read first: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

### Issue 3.3 — API surface
**Sub-issue 3.3.1 — `/events`, `/metrics`, `/agent/report` endpoints**
- Expected outcome: `/events` returns recent ticket purchases/scans, `/metrics` exposes Prometheus-format counters (tickets/sec, consumer lag), `/agent/report` returns the latest agent diagnosis.
- Read first: https://fastapi.tiangolo.com/tutorial/

### Issue 3.4 — Containerize and deploy
**Sub-issue 3.4.1 — Multi-stage Dockerfile + Helm chart for `encore-api`**
- Expected outcome: Image builds reproducibly, runs as non-root, and deploys via Argo CD (Issue 1.4) rather than `kubectl apply`.
- Read first: https://fastapi.tiangolo.com/deployment/docker/

### Issue 3.5 — Persist agent diagnostics to `encore-db`
**Sub-issue 3.5.1 — Write and read agent reports via async SQLAlchemy**
- Expected outcome: Each agent diagnostic (Epic 5) is written as a row referencing `show_id`/`venue`, not just held in memory. `/agent/report` returns history from the database, surviving a pod restart.
- Read first: https://fastapi.tiangolo.com/tutorial/sql-databases/

---

## Epic 4: Encore Live Ops Dashboard

### Issue 4.1 — RBAC for cluster access
**Sub-issue 4.1.1 — Scoped service account for the dashboard backend**
- Expected outcome: A ServiceAccount that can list/get pods and deployments, and delete pods — nothing more.
- Read first: https://kubernetes.io/docs/reference/access-control/rbac/

### Issue 4.2 — Live status panel
**Sub-issue 4.2.1 — Poll and display pod/replica/lag state**
- Expected outcome: The dashboard (see the "Encore — Live Ops" theme sample) shows real pod count, status, and `ticket-purchases` consumer lag, refreshing without a full page reload.
- Read first: https://github.com/kubernetes-client/python

### Issue 4.3 — Load simulation
**Sub-issue 4.3.1 — "Spike load" wired to a real ticket-drop generator + HPA**
- Expected outcome: Clicking "spike load" starts a generator producing synthetic `ticket-purchases` events at high volume; replica count visibly climbs via HPA. Dropping load lets it scale back down after cooldown.
- Read first: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

### Issue 4.4 — Health simulation
**Sub-issue 4.4.1 — "Make gate scanner unhealthy" toggle**
- Expected outcome: Toggling this causes `encore-api`'s liveness probe to fail and Kubernetes to restart the pod — observable in the dashboard's pod status.
- Read first: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

### Issue 4.5 — Failure simulation
**Sub-issue 4.5.1 — "Kill a pod" / "Drain a node" buttons**
- Expected outcome: Killing a pod shows the ReplicaSet immediately create a replacement; draining a node (if multi-node) shows pods reschedule elsewhere.
- Read first: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/

---

## Epic 5: Agentic Review Layer

### Issue 5.1 — AgentCore setup
**Sub-issue 5.1.1 — Provision the Encore review agent with read-only IAM**
- Expected outcome: An IAM role for the agent that can only read logs/metrics — verify by attempting (and failing) a write action manually.
- Read first: https://docs.aws.amazon.com/bedrock-agentcore/

### Issue 5.2 — Trigger mechanism
**Sub-issue 5.2.1 — Scheduled check or ELK alert webhook**
- Expected outcome: The agent runs automatically — e.g. every 15 minutes, or when consumer lag crosses a threshold during a ticket drop.
- Read first: https://docs.aws.amazon.com/bedrock-agentcore/

### Issue 5.3 — Diagnostic report
**Sub-issue 5.3.1 — Generate a structured report on ticketing anomalies**
- Expected outcome: A report covering things like duplicate ticket scans (possible fraud), a venue nearing capacity, or the gate scanner degrading — "what changed / likely cause / suggested next step" — retrievable via `/agent/report` and shown on the dashboard.
- Read first: https://docs.aws.amazon.com/bedrock-agentcore/

### Issue 5.4 — Auditability
**Sub-issue 5.4.1 — Log every query the agent makes**
- Expected outcome: A log trail showing exactly what the agent queried and when, so its reasoning about a given show's ticket sales is reviewable after the fact.
- Read first: https://docs.aws.amazon.com/bedrock-agentcore/

---

## Epic 6: Hardening and Polish

### Issue 6.1 — Resource governance
**Sub-issue 6.1.1 — Set requests/limits on all workloads**
- Expected outcome: No pod runs without explicit CPU/memory requests and limits; verify with `kubectl describe pod`.
- Read first: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

### Issue 6.2 — Disruption budgets
**Sub-issue 6.2.1 — Add PodDisruptionBudgets for `encore-api`**
- Expected outcome: A voluntary disruption (e.g. node drain) cannot take down all replicas of `encore-api` at once — important during an actual ticket-drop window.
- Read first: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/

### Issue 6.3 — Network policies
**Sub-issue 6.3.1 — Restrict pod-to-pod traffic**
- Expected outcome: `encore-api` can reach Kafka and Elasticsearch, but not unrelated namespaces/services — verified by an intentionally blocked test connection.
- Read first: https://kubernetes.io/docs/concepts/services-networking/network-policies/

### Issue 6.4 — Promotion drill
**Sub-issue 6.4.1 — Prove the local → staging path end-to-end**
- Expected outcome: A change made and fully tested on the local docker-compose/kind stack (Issue 0.3) merges through CI (pre-commit + tests, Issue 0.5) and lands in the AWS staging environment (Issue 0.4) via Argo CD, with no manual `kubectl apply` or `terraform apply` step.
- Read first: (none — this exercises Epic 0 end-to-end)

### Issue 6.5 — Documentation and demo
**Sub-issue 6.5.1 — Architecture diagram + README**
- Expected outcome: A README explaining Encore to someone who's never seen it, plus a diagram.
- Read first: (none — this is your own synthesis of everything above)

**Sub-issue 6.5.2 — Screen recording of the sandbox in action**
- Expected outcome: A short video showing a ticket drop → HPA scale-up, kill-pod → reschedule, and an agent report flagging a fraud anomaly — this becomes your interview demo.
- Read first: (none)
