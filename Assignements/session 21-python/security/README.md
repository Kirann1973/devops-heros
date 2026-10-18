# DevSecOps: Security Scanning and Security Gate

**Name:** Kiran N | **Roll No:** 10446 | **Session 21 - Final project, DevSecOps part**

My final project is **StockPilot** ([Kirann1973/stockpilot-devops-capstone](https://github.com/Kirann1973/stockpilot-devops-capstone)): React + FastAPI + PostgreSQL, Docker, GitHub Actions, GHCR, Terraform (AWS VPC + EKS), Helm, Prometheus/Grafana and Argo CD.

Its GitHub Actions pipeline already scans both images with **Trivy** and blocks the push on HIGH/CRITICAL. That is the container image scanning part. The homework asks for more:
- **SAST**
- **SCA**
- **secret scanning**
- **image scanning**
- a **security gate**

This folder adds all of them as one gate, run on my VM against the real StockPilot code and images.

## Tools

| Check | Tool | What it looks at | Fails the gate when |
|---|---|---|---|
| **SAST** (static application security testing) | [Bandit](https://bandit.readthedocs.io) 1.9.4 | The backend Python source code, without running it | Any HIGH severity issue (e.g. shell injection, `eval`, weak crypto) |
| **SCA** (software composition analysis), Python | [pip-audit](https://pypi.org/project/pip-audit/) 2.10.1 | `backend/requirements.txt` against the PyPI / OSV advisory database | Any known vulnerability |
| **SCA**, JavaScript | `npm audit` (Node 22) | `frontend/package-lock.json`, production dependencies | HIGH or CRITICAL |
| **Secret scanning** | [Gitleaks](https://github.com/gitleaks/gitleaks) 8.28.0 | **Every commit** in the Git history, not only the current files | Any secret (API keys, tokens, private keys, passwords) |
| **Container image scanning** | [Trivy](https://trivy.dev) 0.67.2 | OS packages and libraries inside each image | HIGH or CRITICAL that has a fixed version |
| IaC misconfiguration (report only) | Trivy `config` | Helm templates, Terraform, Dockerfiles | Not gating, see the lab output |

Every tool runs in a Docker container (see [`Dockerfile.tools`](Dockerfile.tools)), so the VM only needs Docker.

## The gate

[`security_gate.sh`](security_gate.sh) runs all five checks and prints a PASS/FAIL table:

```text
bash security/security_gate.sh <repo-dir> <image> [image...]

================ SECURITY GATE ================
PASS  SAST: Bandit (Python code)
PASS  SCA: pip-audit (Python dependencies)
...
GATE PASSED: the image may be pushed and deployed        (exit code 0)
GATE FAILED: 4 check(s) failed, the pipeline stops here   (exit code 1)
```

The exit code is what makes it a **gate**: in CI, a step that exits with 1 stops the job, so nothing after it runs (image push, Helm deploy). StockPilot's pipeline already does this with Trivy (`--exit-code 1`). Its first run was blocked by 7 HIGH CVEs, which I fixed before the push.

Where it sits in the pipeline:

```text
code -> build -> unit tests -> SAST -> SCA -> secret scan -> docker build -> image scan -> GATE -> push to GHCR -> deploy (Helm / Argo CD)
                                                                                           |
                                                                                    FAIL: stop here
```

## The bad commit demo

[`bad-commit/export_report.py`](bad-commit/export_report.py) is a deliberately insecure file. Lab part 7 copies it into a **throw-away local clone** of StockPilot, together with:
- 2 old libraries (`requests==2.19.1`, `PyYAML==5.3`)
- a random, fake GitHub token generated at run time

It commits them and uses an old base image (`nginx:1.21.0-alpine`). The gate must fail on 4 of the 5 checks. Part 8 drops the commit and the gate passes again. Nothing from the bad clone is ever pushed.

How to run, and my real results, are in [`../resultReadme.md`](../resultReadme.md).
