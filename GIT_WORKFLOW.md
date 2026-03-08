# Git Workflow Strategy for Open Terminal Fork

**Date:** 2026-03-08  
**Purpose:** Maintain custom changes while tracking upstream updates safely

---

## Branch Structure

```
main           → Tracks upstream (vanilla Open Terminal)
  ↓ (rebase)
custom         → Your custom changes (docker-compose, auth, etc.)
  ↓ (deploy)
production     → (optional) What's currently deployed
```

---

## Current Branches

### `main`
- **Purpose:** Tracks upstream (open-webui/open-terminal)
- **Status:** Clean, no local modifications
- **Action:** Pull upstream updates here

### `custom` ⭐
- **Purpose:** Your custom modifications
- **Status:** Active branch, contains:
  - `docker-compose.yml` (persistent API key config)
  - `IMPLEMENTATION_PLAN.md` (admin vs user integration plan)
  - `MULTI_USER_AUTHENTICATION_GUIDE.md` (5 solutions)
  - `PHASE1_STEP1.1_CURRENT_STATE_ANALYSIS.md` (current state docs)
- **Current Commit:** `7a05e8d` - "chore: add docker-compose and multi-user authentication docs"
- **Action:** Development happens here

---

## Workflow Commands

### Initial Setup (Already Done ✅)

```bash
# Create custom branch
git checkout -b custom

# Add custom files
git add docker-compose.yml IMPLEMENTATION_PLAN.md MULTI_USER_AUTHENTICATION_GUIDE.md PHASE1_STEP1.1_CURRENT_STATE_ANALYSIS.md

# Commit changes
git commit -m "chore: add docker-compose and multi-user authentication docs"

# Push to remote
git push -u origin custom
```

### Regular Workflow: Bringing in Upstream Updates

```bash
# 1. Switch to main branch
git checkout main

# 2. Fetch latest from upstream
git fetch upstream

# 3. Merge upstream changes into main
git merge upstream/main

# 4. Push main to your remote (sync upstream)
git push origin main

# 5. Switch back to custom branch
git checkout custom

# 6. Rebase your changes on top of latest main
git rebase main

# 7. Push updated custom branch
git push origin custom
```

### Making New Custom Changes

```bash
# 1. Ensure you're on custom branch
git checkout custom

# 2. Make your changes (file edits, etc.)

# 3. Review what changed
git status

# 4. Add changed files
git add <file1> <file2>

# 5. Commit with clear message
git commit -m "feat: description of changes"

# 6. Push to remote
git push origin custom
```

---

## Why This Workflow Works

### ✅ Safe
- Your custom changes are isolated on `custom` branch
- Upstream updates go to `main` first
- You control when to rebase/merge

### ✅ Clear
- Easy to see what you've modified: `git diff main..custom`
- Easy to see upstream changes: `git diff upstream/main main`
- Clean separation between vanilla and customized code

### ✅ Testable
- Test upstream updates on `main` before affecting your setup
- Rebase allows you to resolve conflicts incrementally
- Can always fall back to previous working state

### ✅ Reversible
- Can revert upstream merge: `git reset --hard HEAD~1` (on main)
- Can rebase again if something breaks
- Git history is clean and understandable

---

## Current File Status

### Files in `custom` branch (not in upstream):

1. **docker-compose.yml**
   - Docker Compose configuration
   - References `.env` for persistent API key
   - Maps port 8017→8000

2. **IMPLEMENTATION_PLAN.md**
   - Step-by-step plan for admin vs user integration
   - 3 phases: Enhancement → Integration → Documentation
   - Detailed permission matrix and rollback plan

3. **MULTI_USER_AUTHENTICATION_GUIDE.md**
   - 5 solutions for multi-user authentication
   - Code examples for each solution
   - Security best practices and troubleshooting

4. **PHASE1_STEP1.1_CURRENT_STATE_ANALYSIS.md**
   - Current state analysis
   - API key mismatch diagnosis
   - Network connectivity verification

### Environment Files (Not in git - correctly):

- **.env** (contains API key - NOT tracked)
- **.env1** (temporary file - NOT tracked)
- **.goose/** (goose internal - NOT tracked)

---

## Deployment Workflow

### To Deploy Current Custom Branch:

```bash
# 1. Ensure you're on custom branch
git checkout custom

# 2. Pull latest changes
git pull origin custom

# 3. Stop current container
docker compose down

# 4. Start with latest configuration
docker compose up -d

# 5. Verify deployment
docker ps
docker logs open-terminal
```

---

## Troubleshooting

### Merge Conflicts During Rebase

```bash
# If rebase has conflicts:
git rebase main

# Resolve conflicts in your editor
# Mark as resolved:
git add <resolved-files>

# Continue rebase:
git rebase --continue

# Or abort rebase and start over:
git rebase --abort
```

### Need to Undo a Rebase?

```bash
# Find the commit before rebase:
git reflog

# Reset to that commit:
git reset --hard HEAD@{1}
```

### Check What Changed Between Branches

```bash
# See custom changes vs main:
git diff main..custom

# See upstream changes vs main:
git diff upstream/main main

# See detailed log:
git log main..custom --oneline
git log upstream/main main --oneline
```

---

## Remote Repositories

### Origin (Your Fork)
- **URL:** `git@github.com:definitiontv/open-terminal.git`
- **Purpose:** Store your custom branch
- **Push:** `git push origin custom`

### Upstream (Original Open Terminal)
- **URL:** `https://github.com/open-webui/open-terminal.git`
- **Purpose:** Track official releases
- **Pull:** `git fetch upstream`
- **Merge:** `git merge upstream/main`

---

## Best Practices

### Commit Messages
```bash
# Good:
feat: add admin vs user role-based authentication
fix: resolve API key persistence issue
docs: update installation guide
chore: update docker-compose configuration

# Bad:
update files
fixed stuff
changes
```

### Before Pushing
```bash
# Always check what you're pushing:
git status
git diff --cached

# Ensure no sensitive data:
git diff | grep -i "key\|secret\|password"
```

### Regular Upstream Updates
```bash
# Do this regularly (e.g., weekly):
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
git checkout custom
git rebase main
git push origin custom
```

---

## Summary

✅ **Branches:** `main` (upstream tracking), `custom` (your changes)  
✅ **Workflow:** Pull upstream → update main → rebase custom → deploy  
✅ **Safety:** Custom changes never lost or overwritten  
✅ **Clarity:** Easy to see what's modified  
✅ **Flexibility:** Can test updates before merging  

---

**Status:** Workflow implemented and operational  
**Next Steps:** Make future custom changes on `custom` branch, regularly sync upstream on `main`  
**Documentation Version:** 1.0  
**Last Updated:** 2026-03-08
