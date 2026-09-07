# 🔀 Session 5 — Git & GitHub: Homework

---

## 📌 Overview

This session focused on Git operations related to **staging**, **resetting**, **committing**, **branching**, and **selectively applying commits**.

The practical work documented in this session covers:

- `git reset README.md`
- `git commit -a -m`
- `git cherry-pick`

---

## 🛠️ Commands Used

| Command                          | Description                                                         |
|----------------------------------|---------------------------------------------------------------------|
| `git status`                     | Show the current state of the working directory and staging area    |
| `git add`                        | Stage changes for the next commit                                   |
| `git reset <file>`               | Unstage a file without discarding its changes                       |
| `git commit -m`                  | Commit staged changes with a message                                |
| `git commit -a -m`               | Auto-stage tracked modifications and commit in one step             |
| `git cherry-pick <hash>`         | Apply a specific commit from another branch                         |
| `git log --oneline --graph --all`| Visualize commit history across all branches                        |
| `git checkout -b <branch>`       | Create and switch to a new branch                                   |

---

## 1️⃣ Git Reset

### 🎯 Objective

To understand how `git reset README.md` affects a file that has already been staged.

### 📋 Commands Tested

**Step 1** — Modify `README.md` and check status:

```bash
git status
```

```
Changes not staged for commit:
    modified: README.md
```

**Step 2** — Stage the file:

```bash
git add README.md
```

```
Changes to be committed:
    modified: README.md
```

**Step 3** — Reset (unstage) the file:

```bash
git reset README.md
```

**Step 4** — Check status again:

```
Changes not staged for commit:
    modified: README.md
```

### ✅ Result

After running `git reset README.md`, the file moved from **"Changes to be committed"** back to **"Changes not staged for commit"**. The changes inside `README.md` were **not deleted**.

### 🔄 Visual Flow

```
Modified File
     │
     ▼
  git add
     │
     ▼
   Staged ✅
     │
     ▼
git reset README.md
     │
     ▼
  Unstaged 📝
```

> 💡 **Key Takeaway:** `git reset README.md` removes the file from the staging area but **keeps the changes** in the working directory.

---

## 2️⃣ git commit -a -m

### 🎯 Objective

To understand the difference between `git commit -m` and `git commit -a -m`.

### 📋 Regular `git commit -m`

The standard workflow requires changes to be staged **before** committing:

```bash
git add README.md
git commit -m "Update README"
```

`git commit -m` commits **only** the changes that have already been added to the staging area.

### 📋 `git commit -a -m`

The `-a` option **automatically stages** modified and deleted files that are already tracked by Git, then commits them:

```bash
git commit -a -m "Update README"
```

This is useful when working with files that Git is already tracking.

### ⚖️ Comparison

| Feature                                      | `git commit -m`           | `git commit -a -m`                          |
|----------------------------------------------|---------------------------|---------------------------------------------|
| What it commits                              | Staged changes only       | Auto-stages modified/deleted tracked files  |
| Requires `git add` first?                    | ✅ Yes                    | ❌ No (for tracked files)                   |
| Includes untracked (new) files?              | ❌ No                     | ❌ No                                       |
| Control over what is staged                  | Explicit                  | Automatic                                   |
| Best for                                     | Precise staging           | Quick commits of tracked files              |

> ⚠️ **Important:** The `-a` option does **not** add new untracked files.
>
> For example, if `newfile.txt` has never been tracked:
> ```bash
> git commit -a -m "Add new file"   # ❌ Will NOT include newfile.txt
> ```
> It must first be explicitly added:
> ```bash
> git add newfile.txt               # ✅ Now it's tracked
> ```

---

## 3️⃣ Git Cherry-Pick

### 🎯 Objective

To understand how a specific commit from another branch can be applied to the current branch **without merging** the entire branch.

### 🔄 Basic Workflow

```
main
 │
 ├── Commit A
 ├── Commit B
 └── Commit C
        │
        └── create new branch (feature)
              │
              ├── Commit D
              ├── Commit E
              └── Commit F
```

A specific commit can then be selected and applied to `main`:

```bash
git cherry-pick <commit-hash>
```

The result is conceptually:

```
main
 │
 ├── Commit A
 ├── Commit B
 ├── Commit C
 └── Commit D'    ← cherry-picked
```

where **Commit D'** contains the changes introduced by the selected commit.

### 📋 Useful Commands

```bash
# View the commit history
git log --oneline

# Create a new branch
git checkout -b feature

# After making commits on the branch, return to main
git checkout main

# Apply a specific commit
git cherry-pick <commit-hash>

# Verify the history
git log --oneline --graph --all
```

### 💡 Why Cherry-Pick Is Useful

Cherry-picking is useful when only a **particular commit** from another branch is required, instead of merging all the changes from that branch.

For example, if a branch contains:

| Commit   | Needed? |
|----------|---------|
| Commit D | ❌ No   |
| Commit E | ✅ Yes  |
| Commit F | ❌ No   |

Only the changes from **Commit E** can be cherry-picked into `main`, avoiding the other commits entirely.

---

## 📝 Key Takeaways

| Concept                   | Summary                                                                  |
|---------------------------|--------------------------------------------------------------------------|
| `git reset <file>`        | Unstages a file without deleting its changes                             |
| `git commit -m`           | Commits changes that have already been staged                            |
| `git commit -a -m`        | Auto-stages modifications/deletions to tracked files, then commits       |
| `-a` flag limitation      | Does **not** include new untracked files                                 |
| `git cherry-pick`         | Applies a specific commit to another branch without a full merge         |
| `git log --oneline --graph --all` | Useful for visualizing branch and commit history                |

---

## 🏁 Conclusion

This session covered practical Git operations that are essential when managing changes across branches and controlling what gets included in commits.

Understanding **staging**, **resetting**, **committing**, **branching**, and **cherry-picking** provides a stronger foundation for working with Git in collaborative development environments.

---

## 👤 Author

**Kiran N** — `24bcs10446`

---

> ✅ **End of Session 5 — Git & GitHub Homework**
