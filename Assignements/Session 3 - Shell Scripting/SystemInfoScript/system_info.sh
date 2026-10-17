#!/bin/bash
# Session 3 - Shell Scripting: System Information Script
# Author: Kiran N | Roll No: 10446

# ---------- Variables ----------
OUTPUT_DIR="system_info_output"
LOG_FILE="$OUTPUT_DIR/process.log"

current_date=$(date)
current_host=$(hostname)
current_user=$(whoami)

# ---------- System information ----------
echo "========== SYSTEM INFORMATION =========="
echo "Date      : $current_date"
echo "Hostname  : $current_host"
echo "Username  : $current_user"
echo

echo "========== DISK USAGE =========="
df -h
echo

echo "========== RUNNING PROCESSES (top 10) =========="
ps aux | head -n 11
echo

# ---------- User input ----------
read -p "Enter your name: " name
read -p "Enter your roll number: " roll_no
read -p "Enter a comment: " comment
echo

# ---------- Directory and file ----------
mkdir -p "$OUTPUT_DIR"
touch "$LOG_FILE"
echo "Created directory : $OUTPUT_DIR"
echo "Created file      : $LOG_FILE"

# ---------- Save processes with > redirection ----------
ps aux > "$LOG_FILE"

# Append the user's details with >>
echo "" >> "$LOG_FILE"
echo "Saved by: $name (Roll No: $roll_no) on $current_date" >> "$LOG_FILE"
echo "Comment : $comment" >> "$LOG_FILE"

echo
echo "Hello $name (Roll No: $roll_no)!"
echo "Your comment: $comment"
echo "Process list saved to $LOG_FILE ($(wc -l < "$LOG_FILE") lines)"
