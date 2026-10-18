# Kiran N | Roll No: 10446 - Session 21
# DELIBERATELY INSECURE file, used only by the security gate demo (session21_lab.sh part 6).
# The lab copies it into a throw-away clone of StockPilot to simulate a bad commit. It is never deployed.
import subprocess

import yaml


def export_report(product_name):
    # B602 (HIGH): user input goes into a shell command -> command injection, e.g. "x; rm -rf /"
    subprocess.call("tar czf /tmp/report.tgz reports/" + product_name, shell=True)


def load_settings(text):
    # B506 (MEDIUM): yaml.load without SafeLoader can construct arbitrary Python objects
    return yaml.load(text)
