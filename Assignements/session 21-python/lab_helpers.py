# Kiran N | Roll No: 10446 - used by session21_lab.sh and security/security_gate.sh to turn
# long JSON scanner reports into short tables. Usage: <scanner> --format json | python3 lab_helpers.py <command>
import json
import sys


def trivy_image(d):  # trivy image --format json: count HIGH/CRITICAL, list the first ones; exit 1 if any
    if not d.get("ArtifactName"):
        print("  Trivy did not produce a report (scan error above), so the check fails")
        sys.exit(2)
    vulns = [v for r in d.get("Results", []) for v in (r.get("Vulnerabilities") or [])]
    high = sum(v["Severity"] == "HIGH" for v in vulns)
    crit = sum(v["Severity"] == "CRITICAL" for v in vulns)
    os_ = d.get("Metadata", {}).get("OS", {})
    print(f"  image {d.get('ArtifactName')}  os {os_.get('Family', '?')} {os_.get('Name', '')}")
    print(f"  HIGH: {high}  CRITICAL: {crit}  (only vulnerabilities that have a fixed version)")
    for v in sorted(vulns, key=lambda v: (v["Severity"] != "CRITICAL", v["PkgName"]))[:8]:
        print(f"    {v['Severity']:<9}{v['VulnerabilityID']:<17}{v['PkgName']:<16}"
              f"{v.get('InstalledVersion', ''):<14}-> {v.get('FixedVersion', '')}")
    if len(vulns) > 8:
        print(f"    ... and {len(vulns) - 8} more")
    sys.exit(1 if vulns else 0)


def trivy_config(d):  # trivy config --format json: misconfigurations per file
    total = 0
    print(f"  {'FILE':<52}{'HIGH+':>6}  CHECKS")
    for r in d.get("Results", []):
        m = r.get("Misconfigurations") or []
        if m:
            total += len(m)
            ids = sorted({x["ID"].replace("AVD-", "") for x in m})
            print(f"  {r['Target']:<52}{len(m):>6}  {', '.join(ids)}")
    print(f"  total HIGH/CRITICAL misconfigurations: {total}")
    for x in sorted({(x["ID"], x["Title"]) for r in d.get("Results", []) for x in (r.get("Misconfigurations") or [])}):
        print(f"    {x[0]}: {x[1]}")


if __name__ == "__main__":
    globals()[sys.argv[1]](json.loads(sys.stdin.read() or "{}"))
