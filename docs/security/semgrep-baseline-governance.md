# Semgrep Baseline Governance

**Status:** Accepted temporary baseline for Phase 3B/3C  
**Owner:** Project owner / DevSecOps reviewer  
**Review trigger:** Before production-readiness hardening  
**Last updated:** 2026-06-24

---

## Purpose

This document governs the set of known Semgrep findings that are accepted as a temporary baseline during Phase 3B/3C
of the CI/CD security pipeline. It exists to:

- Clearly separate **known, accepted findings** from **new, potentially blocking findings**.
- Provide a single source of truth for what the Semgrep Gate should treat as REPORT-ONLY vs. blocking.
- Document risk rationale and an explicit plan to review each baseline finding.

---

## Relationship to Phase 3B Semgrep Gate Behavior

Per the Phase 3B design:

> The Semgrep Gate is **baseline-aware**. Known baseline findings are treated as **REPORT-ONLY /
> manual-triage**. Findings that appear in the Semgrep output but are **not** in the baseline remain subject to
> standard blocking rules.

This governance document **is** the written baseline. The gate's behavior is implemented in:

- `platform-cicd/Jenkinsfile` — the Semgrep Gate stage logic
- `platform-cicd/scripts/security_notify.sh` — security summary generation (writes `Semgrep Gate Mode`)

Neither the gate logic nor the notification script are modified by this document. This document provides the
governance context for *why* the baseline exists and *how* each finding should be reviewed.

---

## Blocking vs. REPORT-ONLY Rules

| Category | Gate Behavior |
|---|---|
| **Known baseline findings** (listed below) | REPORT-ONLY / manual-triage |
| **New non-baseline findings** at ERROR or CRITICAL severity | **Blocking** — pipeline should fail |
| Findings at WARNING / INFO severity | REPORT-ONLY (existing pipeline behavior unchanged) |

**New non-baseline ERROR/CRITICAL findings should still block the pipeline.** The baseline is not a blanket
exemption; it applies only to the specific, enumerated findings in this document. Any previously unseen
ERROR/CRITICAL Semgrep result must be triaged and either fixed or added to the baseline through a documented
review process before it is accepted.

---

## Baseline Findings

### 1. Missing USER instruction in Dockerfile

| Field | Value |
|---|---|
| **Rule ID** | `dockerfile.security.missing-user.missing-user` |
| **File** | `source/vihire-backend/Dockerfile` |
| **Line** | 12 |
| **Severity / Treatment** | ERROR — REPORT-ONLY / manual-triage |
| **Risk Explanation** | The Dockerfile does not include a `USER` directive after installing dependencies. The container runs as root by default, which increases the blast radius of a container escape or compromised application process. |
| **Why Not Fixed Here** | This is a Phase 3C docs/governance task. Dockerfile changes are explicitly out of scope per task rules. A `USER` directive would need application-level validation (e.g., verifying that port bindings, file permissions, and entrypoint scripts work under a non-root user). |
| **Owner** | Project owner / DevSecOps reviewer |
| **Review Plan** | Assess feasibility of adding a non-root `USER` instruction. Test the application container under the proposed user before committing. |
| **Target Review Trigger** | Before production-readiness hardening; before enabling stricter Semgrep blocking. |

### 2. `app.run` with dangerous host parameter (source/app.py)

| Field | Value |
|---|---|
| **Rule ID** | `python.flask.security.audit.app-run-param-config.avoid_app_run_with_bad_host` |
| **File** | `source/app.py` |
| **Line** | 25 |
| **Severity / Treatment** | ERROR — REPORT-ONLY / manual-triage |
| **Risk Explanation** | `app.run(host='0.0.0.0')` binds the Flask development server to all network interfaces. In a development context this is common, but in production it exposes the built-in Werkzeug server (not a production-grade WSGI server) to external networks. |
| **Why Not Fixed Here** | This is a Phase 3C docs/governance task. `app.py` changes are explicitly out of scope per task rules. The development-server binding is acceptable for the current lab/development phase. Production deployment should use a production WSGI server (gunicorn, uwsgi) behind a reverse proxy. |
| **Owner** | Project owner / DevSecOps reviewer |
| **Review Plan** | Evaluate whether the lab phase should switch to a production WSGI server or bind to `127.0.0.1` behind a reverse proxy. |
| **Target Review Trigger** | Before production-readiness hardening; before enabling stricter Semgrep blocking; when Dockerfile/app.py ownership changes. |

### 3. `app.run` with dangerous host parameter (source/vihire-backend/app.py)

| Field | Value |
|---|---|
| **Rule ID** | `python.flask.security.audit.app-run-param-config.avoid_app_run_with_bad_host` |
| **File** | `source/vihire-backend/app.py` |
| **Line** | 25 |
| **Severity / Treatment** | ERROR — REPORT-ONLY / manual-triage |
| **Risk Explanation** | Same as finding #2. `app.run(host='0.0.0.0')` binds the Flask development server to all network interfaces. |
| **Why Not Fixed Here** | This is a Phase 3C docs/governance task. `app.py` changes are explicitly out of scope per task rules. Same rationale as finding #2. |
| **Owner** | Project owner / DevSecOps reviewer |
| **Review Plan** | Align with finding #2 — coordinate a single fix approach for both `app.py` files if applicable. |
| **Target Review Trigger** | Before production-readiness hardening; before enabling stricter Semgrep blocking; when Dockerfile/app.py ownership changes. |

---

## What This Document Is Not

- **This is NOT a `.trivyignore` file.** Trivy secret scanning and vulnerability scanning remain fully active and
  blocking at CRITICAL severity. This document does not suppress any Trivy findings.
- **This is NOT a Semgrep ignore rule** (no `.semgrepignore`, no `# nosemgrep` comments, no inline suppressions).
  Semgrep still reports these findings; the pipeline simply treats them as REPORT-ONLY instead of blocking.
- **This does NOT disable any scanner.** All security stages (Source Secret Scan via Trivy, Semgrep SAST,
  Container Vulnerability Scan via Trivy) continue to run every build. Only the *blocking behavior* of the
  specific baseline findings is relaxed, and only in the Semgrep stage.

---

## Scanners and Gates Not Affected

The following pipeline security controls are **not affected** by this governance document:

| Security Control | Status |
|---|---|
| Trivy --scanners secret (Source Secret Scan) | **Active, blocking** |
| Trivy --scanners vuln (Container Vulnerability Scan) | **Active, CRITICAL blocking** |
| Semgrep SAST scan execution | **Always runs** |
| Semgrep Gate (new non-baseline ERROR/CRITICAL findings) | **Active, blocking** |
| Security summary generation | **Always generated** |
| Telegram/Slack notification | **Unchanged (safe-skip preserved)** |

---

## Phase 3C Scope Note

**Dockerfile and app.py are not modified in Phase 3C.** This task creates governance documentation only. Any
changes to `source/vihire-backend/Dockerfile`, `source/app.py`, or `source/vihire-backend/app.py` are out of
scope for this phase.

---

## Review Cadence and Triggers

The baseline should be reviewed when any of the following occur:

1. **Before production-readiness hardening** — the baseline must be re-evaluated before the application is
   deployed in a production or production-like environment.
2. **Before enabling stricter Semgrep blocking** — if the pipeline is updated to block lower-severity findings
   or enforce additional rules, the baseline must be reviewed for completeness and accuracy.
3. **When Dockerfile/app.py ownership changes** — a new owner may have a different risk tolerance or may be in
   a position to fix the finding.
4. **If Semgrep introduces new non-baseline findings** — the presence of new findings may indicate that the
   baseline should be revisited or that a broader category needs governance.
5. **Every 90 days** — as a standing review cadence, the baseline should be confirmed as still valid or
   updated with current risk assessments.

---

## Version History

| Date | Version | Change |
|---|---|---|
| 2026-06-24 | 1.0 | Initial baseline governance document. |
