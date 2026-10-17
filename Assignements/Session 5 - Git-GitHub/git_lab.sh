#!/bin/bash
# Session 5 - Git & GitHub lab
# Kiran N | Roll No: 10446
OUT=~/session5/git_output.txt
rm -rf ~/session5/git-lab && mkdir -p ~/session5/git-lab && cd ~/session5/git-lab
: > "$OUT"
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
step() { echo "########## $* ##########" | tee -a "$OUT"; }

step "SETUP"
run git init -b main
run git config user.name \"Kiran N\"
run git config user.email \"kiran.10446@example.com\"

step "TASK 1: git commit -m vs git commit -a -m"
run echo \"line 1\" \> notes.txt
run git add notes.txt
run git commit -m \"Add notes.txt\"
run echo \"line 2\" \>\> notes.txt
run echo \"new file\" \> extra.txt
run git status --short
step "1a. git commit -m WITHOUT git add (nothing staged)"
run git commit -m \"Try commit without add\"
step "1b. git commit -a -m (stages tracked notes.txt only)"
run git commit -a -m \"Update notes.txt using -a\"
run git status --short
run git show --stat --oneline HEAD
step "1c. untracked extra.txt still needs git add"
run git add extra.txt
run git commit -m \"Add extra.txt\"

step "TASK 2: git cherry-pick"
run echo \"app v1\" \> app.txt
run git add app.txt
run git commit -m \"main: add app.txt\"
run git log --oneline
run git checkout -b feature
run echo \"login page\" \> login.txt
run git add login.txt
run git commit -m \"feature: add login page\"
run echo \"bug fix\" \> fix.txt
run git add fix.txt
run git commit -m \"feature: important bug fix\"
run echo \"dark mode\" \> theme.txt
run git add theme.txt
run git commit -m \"feature: add dark mode\"
run git log --oneline
FIX=$(git log --format=%h --grep="important bug fix" -n 1)
run git checkout main
run git cherry-pick $FIX
run git log --oneline --graph --all
run ls
echo "Saved all output to $OUT"
