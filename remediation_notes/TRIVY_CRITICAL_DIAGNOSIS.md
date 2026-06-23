# Trivy CRITICAL Diagnosis

## Source Artifact
- File: `phase2_submission/raw/trivy-critical.json` and `.txt`
- Generated: Build #8, Trivy 0.71.2

## Target
- Image: `dat071104/vihire-backend:8`
- Base OS: **debian 13.5** ("trixie" — testing/unstable)
- Base image: `python:3.12-slim` (floating tag → trixie)

## CRITICAL CVEs Found: 2

### CVE-2026-42496
| Field | Value |
|---|---|
| Package | perl-base |
| Installed | 5.40.1-6 |
| Fixed Version | *(none — fix_deferred)* |
| Status | fix_deferred |
| Description | perl-archive-tar: Path traversal via crafted symlinks allows arbitrary file access |
| Layer | Debian base OS layer (not app dependency) |

### CVE-2026-8376
| Field | Value |
|---|---|
| Package | perl-base |
| Installed | 5.40.1-6 |
| Fixed Version | *(none — affected)* |
| Status | affected |
| Description | Perl heap buffer overflow when compiling |
| Layer | Debian base OS layer (not app dependency) |

## Root Cause
Both CVEs are in **perl-base** from the Debian **trixie (13.5)** distribution.  
The base image `python:3.12-slim` currently resolves to Debian trixie, and these perl-base CVEs have no published fixed version yet.

## Plan (Decision Rule A → B)
1. **Attempt 1:** Add `--pull` to Jenkinsfile `Build` stage to ensure freshest base image pull.
2. **Attempt 2 (if needed):** Change Dockerfile FROM to `python:3.12-slim-bookworm` (Debian 12 bookworm, stable release with maintained perl-base).
3. **Attempt 3 (if needed):** Alternative base image or minimal remediation.

## App Dependencies
- `Flask==3.0.3` — no CRITICAL CVEs found.
- No app dependency CVEs.
