#!/bin/bash
# Session 16 build step - Kiran N | Roll No: 10446
# Packages the application into build/ with a build-info.txt (uploaded as an artifact by the pipeline).
set -e
echo "================================="
echo "Starting Application Build"
echo "================================="
rm -rf build
mkdir -p build/app
cp app/__init__.py app/calculator.py app/web.py build/app/
cp Dockerfile build/
cat > build/build-info.txt <<EOF
Application: Session 16 Calculator
Built for:   Kiran N - Roll No 10446
Build Status: SUCCESS
Build Date:  $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Commit:      ${GITHUB_SHA:-local}
Run:         ${GITHUB_RUN_NUMBER:-local}
Runner:      ${RUNNER_OS:-$(uname -s)} / ${RUNNER_ARCH:-$(uname -m)}
EOF
echo ""
echo "Build files:"
find build -type f | sort
echo ""
echo "Build completed successfully."
