# 🐚 Session 3 — Shell Scripting: Homework

---

## 📌 Overview

This shell script displays basic **system information**, creates a directory and file, accepts **user input**, and stores running **process information** in a log file.

---

## 🛠️ Commands Used

| Command        | Description                                |
|----------------|--------------------------------------------|
| `mkdir -p`     | Create directories (including parents)     |
| `touch`        | Create an empty file                       |
| `echo`         | Print text to the terminal                 |
| `date`         | Display the current date and time          |
| `hostname`     | Display the system hostname                |
| `whoami`       | Display the current logged-in username     |
| `df`           | Display disk space usage                   |
| `ps`           | List running processes                     |
| `read -p`      | Read user input with a prompt              |

---

## 📂 Variables & Redirection

| Operator | Description                                      |
|----------|--------------------------------------------------|
| `>`      | Redirect output to a file (overwrites)           |
| `>>`     | Append output to a file (does not overwrite)     |

---

## ✨ Features

- ✅ Prints current **date**, **hostname**, and **username**
- ✅ Displays **disk usage** and **running processes**
- ✅ Creates `system_info_output/` directory
- ✅ Creates `process.log` file inside it
- ✅ Stores process information in `process.log`
- ✅ Takes user input — **name**, **roll number**, **comment**
- ✅ Appends user details to the log file

---

## 🚀 How to Run

```bash
# Make the script executable
chmod +x system_info.sh

# Run the script
./system_info.sh
```

---

## 📁 Output Files

```
system_info_output/
└── process.log
```

---

## 📋 Sample Output

```
Current Date: Mon Aug 31 20:00:00 IST 2026
Hostname: ubuntu
Username: kiran

Disk Usage:
...

My name is Kiran N
My roll number is 24bcs10446
My comment is: Shell scripting completed

Process information saved to system_info_output/process.log
```

---

## 👤 Author

**Kiran N** — `24bcs10446`

---

> ✅ **End of Session 3 — Shell Scripting Homework**
