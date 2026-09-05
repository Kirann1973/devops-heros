# 🐧 Session 2 — Linux Fundamental: Homework

---

## 📌 Task 1: Soft Link & Hard Link

### What Are Links in Linux?

Links in Linux are shortcuts or references to files. There are two types: **Soft Links** (symbolic) and **Hard Links**.

### Soft Link vs Hard Link

| Feature                  | Soft Link (Symbolic Link)         | Hard Link                          |
|--------------------------|------------------------------------|------------------------------------|
| Points to               | The original **file path**         | The file **inode** directly        |
| Cross file system        | ✅ Yes                             | ❌ No                              |
| Link to directories      | ✅ Yes                             | ❌ No (normally)                   |
| Original file deleted    | ❌ Link **breaks**                 | ✅ Link **still works**            |
| Created using            | `ln -s`                           | `ln`                               |

### Commands

```bash
# Create a file
touch file1.txt

# Create a Soft Link
ln -s file1.txt softlink.txt

# Create a Hard Link
ln file1.txt hardlink.txt

# View links with inode numbers
ls -li

# Delete Soft Link
rm softlink.txt

# Delete Hard Link
rm hardlink.txt

# Delete Original File
rm file1.txt
```

### ❓ Q: What is the difference between a soft link and a hard link?

> **Answer:** A **soft link** stores the path of the original file and **breaks** if the original file is deleted. A **hard link** points directly to the file's **inode**, so it **continues to work** even if the original file is deleted.

---

## 📌 Task 2: `adduser` vs `useradd`

### Difference

| Feature                        | `adduser`                        | `useradd`                        |
|--------------------------------|----------------------------------|----------------------------------|
| Type                           | User-friendly (high-level)       | Low-level command                |
| Creates home directory         | ✅ Automatically                 | ❌ Requires `-m` flag            |
| Prompts for password & details | ✅ Yes                           | ❌ No                            |
| Best used on                   | Ubuntu / Debian                  | Scripting / automation           |

> 💡 **Ubuntu recommends** using `adduser` for interactive user creation.

### Commands

```bash
# Create a new user
sudo adduser testuser

# Switch to the new user
su - testuser

# Delete the user
sudo deluser testuser
```

---

## 📌 Task 3: `journalctl`

### What is `journalctl`?

`journalctl` is a command-line tool used to **view and manage logs** collected by `systemd`'s journal service. It is essential for troubleshooting and monitoring system activity.

### Useful Commands

```bash
# View all logs
journalctl

# View the last 50 log entries
journalctl -n 50

# Follow logs in real time (like tail -f)
journalctl -f

# View logs from the current boot
journalctl -b

# View logs for a specific service (e.g., SSH)
journalctl -u ssh

# View logs for Docker
journalctl -u docker

# View logs since today
journalctl --since today

# View logs from the last hour
journalctl --since "1 hour ago"
```

---

## 📌 Task 4: Linux Command Cheat Sheet

### 📁 File & Directory Commands

| Command   | Description                              |
|-----------|------------------------------------------|
| `pwd`     | Print current working directory          |
| `ls`      | List directory contents                  |
| `ls -l`   | List with detailed info                  |
| `ls -a`   | List including hidden files              |
| `cd`      | Change directory                         |
| `mkdir`   | Create a new directory                   |
| `rmdir`   | Remove an empty directory                |
| `rm`      | Remove files or directories              |
| `cp`      | Copy files or directories                |
| `mv`      | Move or rename files                     |
| `touch`   | Create an empty file                     |
| `cat`     | Display file contents                    |

### 👁️ File Viewing Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `less`     | View file with backward navigation      |
| `more`     | View file page by page                  |
| `head`     | Display the first lines of a file       |
| `tail`     | Display the last lines of a file        |
| `tail -f`  | Follow a file in real time              |

### 🔍 Search Commands

| Command   | Description                              |
|-----------|------------------------------------------|
| `find`    | Search for files in a directory tree     |
| `grep`    | Search text patterns inside files        |
| `which`   | Locate a command's binary path           |

### 👤 User Management Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `whoami`   | Display current username                |
| `who`      | Show who is logged in                   |
| `id`       | Display user and group IDs              |
| `adduser`  | Add a new user (interactive)            |
| `useradd`  | Add a new user (low-level)              |
| `passwd`   | Change user password                    |

### ⚙️ Process Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `ps`       | List running processes                  |
| `top`      | Real-time process monitoring            |
| `htop`     | Interactive process viewer              |
| `kill`     | Terminate a process by PID              |
| `killall`  | Terminate all processes by name         |

### 💾 Disk Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `df -h`    | Show disk space usage (human-readable)  |
| `du -sh`   | Show directory size                     |

### 🔐 Permission Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `chmod`    | Change file permissions                 |
| `chown`    | Change file owner                       |
| `chgrp`    | Change file group                       |

### 🌐 Networking Commands

| Command    | Description                             |
|------------|-----------------------------------------|
| `ping`     | Test network connectivity               |
| `ip a`     | Show IP addresses                       |
| `ss`       | Display socket statistics               |
| `curl`     | Transfer data from/to a server          |
| `wget`     | Download files from the web             |

### 🖥️ System Information Commands

| Command      | Description                           |
|--------------|---------------------------------------|
| `uname -a`   | Display system information            |
| `hostname`   | Show or set the system hostname       |
| `uptime`     | Show how long the system has been up  |
| `free -h`    | Display memory usage (human-readable) |

---

> ✅ **End of Session 2 — Linux Fundamental Homework**
