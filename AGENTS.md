# AGENTS.md - Open Terminal Implementation & Context

**Date:** 2026-03-08  
**Purpose:** Complete understanding of Open Terminal setup, architecture, and implementation plans

---

## CRITICAL SYSTEM INFORMATION

### Server Details
- **Server Name:** unity87.hubgoo.com (NOT unity84)
- **Open Terminal Port:** 8017 (external) → 8000 (container internal)
- **Container Name:** `open-terminal`
- **Image:** `definitiontv/open-terminal:latest`
- **Status:** Running healthy

### Open WebUI Integration
- **Open WebUI Server:** Different server (141.147.119.39)
- **Integration URL:** `http://unity87.hubgoo.com:8017`
- **Current Status:** 401 Unauthorized (API key mismatch - now resolved)

---

## CURRENT IMPLEMENTATION STATE

### Docker Configuration

#### docker-compose.yml
```yaml
version: "3.8"

services:
  open-terminal:
    image: definitiontv/open-terminal:latest
    container_name: open-terminal
    restart: unless-stopped
    ports:
      - "8017:8000"
    env_file:
      - .env
    environment:
      - OPEN_TERMINAL_API_KEY=${OPEN_TERMINAL_API_KEY}
```

#### .env Configuration
```
OPEN_TERMINAL_API_KEY=zhczXD4jxZh-6wKcIZKU8jr-nFNU90aW
```

**IMPORTANT:** .env is in .gitignore (correctly not tracked)

### Container Environment Variables
```json
[
  "OPEN_TERMINAL_API_KEY=zhczXD4jxZh-6wKcIZKU8jr-nFNU90aW",
  "PATH=/home/user/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  "LANG=C.UTF-8",
  "GPG_KEY=7169605F62C751356D054A26A821E680E5FA6305",
  "PYTHON_VERSION=3.12.13",
  "PYTHON_SHA256=c08bc65a81971c1dd5783182826503369466c7e67374d1646519adf05207b684",
  "SHELL=/bin/bash"
]
```

---

## GIT WORKFLOW STRUCTURE

### Repository Setup
- **Origin (Your Fork):** `git@github.com:definitiontv/open-terminal.git`
- **Upstream (Official):** `https://github.com/open-webui/open-terminal.git`

### Branch Strategy

```
main           → Tracks upstream (vanilla Open Terminal)
  ↓ (rebase)
custom         → Your custom changes (docker-compose, auth, etc.)
  ↓ (deploy)
production     → (optional) What's currently deployed
```

### Current Branch: `custom`
- **Commit:** `16181c9` - "docs: add Git workflow strategy documentation"
- **Files in custom branch:**
  1. `docker-compose.yml` - Docker Compose configuration
  2. `IMPLEMENTATION_PLAN.md` - Step-by-step admin vs user integration plan
  3. `MULTI_USER_AUTHENTICATION_GUIDE.md` - 5 solutions for multi-user auth
  4. `PHASE1_STEP1.1_CURRENT_STATE_ANALYSIS.md` - Current state analysis
  5. `GIT_WORKFLOW.md` - Git workflow documentation

### Workflow for Upstream Updates
```bash
# 1. Update main with latest upstream
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# 2. Rebase custom on top of updated main
git checkout custom
git rebase main
git push origin custom
```

---

## OPEN TERMINAL ARCHITECTURE

### Performance Metrics
- **Total Size:** 1.4 MB (120 KB core code)
- **Max Sessions:** 16 concurrent sessions (configurable)
- **Process Auto-cleanup:** 5 minutes
- **Session Timeout:** 30 minutes
- **Async Functions:** 52 total (main.py: 34, notebooks.py: 6, runner.py: 12)
- **HTTP Endpoints:** 26 FastAPI endpoints
- **Buffer Size:** 4KB for PTY reads and port detection
- **Performance Score:** 8.5/10 (Production-ready)

### Key Architecture Characteristics
- **Fully Async:** 52 async functions, 11 asyncio.to_thread() calls for CPU-bound operations
- **Smart Resource Management:** Automatic cleanup, bounded output
- **Platform-Optimized:** Different execution paths for different OS
- **Configurable Limits:** Multiple timeout configurations (2s-300s)
- **Clean Separation:** Blocking vs non-blocking operations properly separated

---

## IMPLEMENTATION PLAN SUMMARY

### Phase 1: Open Terminal Enhancement (Admin vs User)
**Goal:** Implement role-based access control in Open Terminal

**Key Changes Required:**
1. Update `open_terminal/env.py`:
   - Add `OPEN_TERMINAL_ADMIN_KEY` configuration
   - Add `OPEN_TERMINAL_USER_KEY_*` configuration (support multiple user keys)
   - Implement `get_role(api_key)` function

2. Update `open_terminal/main.py`:
   - Modify `verify_api_key()` to include role detection
   - Create `require_admin()` dependency for admin-only endpoints
   - Create `require_user_or_admin()` dependency for shared endpoints
   - Update endpoints with role-based access control

**Proposed Permission Matrix:**
```
ADMIN ROLE:
- All file operations (read, write, delete, move)
- All execute operations (run any command)
- Terminal sessions (create, manage)
- Notebook execution
- Port detection and proxy
- Administrative functions

USER ROLE:
- Execute operations (with restrictions)
- File read operations
- File write operations (in allowed directories)
- Limited command execution time
- No terminal sessions (interactive terminals disabled)
- No notebook execution
- No port access
```

### Phase 2: Open WebUI Integration
**Goal:** Connect Open WebUI to Open Terminal with role-based access

**Steps:**
1. Configure Open WebUI admin connection with admin API key
2. Configure Open WebUI user connection with user API key
3. Test end-to-end integration
4. Verify permissions work correctly

### Phase 3: Documentation and Validation
**Goal:** Complete documentation and security best practices

**Deliverables:**
- Configuration documentation
- Security guidelines
- Final testing and validation

---

## CURRENT PROBLEM (RESOLVED)

### Issue: 401 Unauthorized Errors
**Root Cause:** 
- Open Terminal had `OPEN_TERMINAL_API_KEY=auto-generated`
- Container restart generated new random key
- Open WebUI was using old/unknown key
- Result: API key mismatch causing 401 errors

### Solution Implemented:
✅ Replaced `auto-generated` with fixed persistent key: `zhczXD4jxZh-6wKcIZKU8jr-nFNU90aW`
✅ Key stored in `.env` file (not tracked in git)
✅ docker-compose.yml configured to read from `.env`
✅ Container redeployed with persistent configuration

### Next Required Step:
- Update Open WebUI configuration with API key: `zhczXD4jxZh-6wKcIZKU8jr-nFNU90aW`
- Update Open WebUI URL: `http://unity87.hubgoo.com:8017`

---

## AVAILABLE DOCUMENTATION

### 1. IMPLEMENTATION_PLAN.md
**Purpose:** Step-by-step execution plan for admin vs user integration
**Sections:**
- Current state analysis
- Step-by-step implementation plan (3 phases)
- Risk assessment and mitigation strategies
- Rollback plan for each phase
- Success criteria
- Network architecture diagram

### 2. MULTI_USER_AUTHENTICATION_GUIDE.md
**Purpose:** 5 solutions for multi-user authentication with code examples
**Solutions Covered:**
1. Multiple API Keys with User Mapping (Easy, 2-4 hours)
2. Environment-Based App Segmentation (Easy, 30 minutes)
3. JWT Token Authentication with Roles (Advanced, 1-2 days)
4. Path-Based Access Control (Medium, 1-2 hours)
5. Open WebUI Integration (Easy, 1 hour)

**Additional Content:**
- Security best practices
- Troubleshooting guide
- Comparison matrix
- Phased implementation recommendation

### 3. PHASE1_STEP1.1_CURRENT_STATE_ANALYSIS.md
**Purpose:** Detailed analysis of current Open Terminal configuration
**Findings:**
- Container status and configuration
- Access logs analysis
- Authentication behavior documentation
- Open WebUI connection status
- Root cause analysis of 401 errors

### 4. GIT_WORKFLOW.md
**Purpose:** Git workflow strategy for maintaining custom changes
**Content:**
- Branch structure and workflow
- Commands for upstream updates
- Deployment workflow
- Troubleshooting git issues
- Best practices for commits and pushes

---

## TOOLS AND CAPABILITIES

### Developer Extension Tools
- `developer__shell` - Run shell commands
- `developer__text_editor` - View and edit files
- `developer__analyze` - Code analysis
- `developer__screen_capture` - Screenshots
- `developer__image_processor` - Image processing

### Context7 Tools
- `context7__resolve-library-id` - Find library documentation
- `context7__query-docs` - Query documentation for help

### Memory Tools
- `memory__remember_memory` - Store information
- `memory__retrieve_memories` - Retrieve stored info
- `memory__remove_*` - Remove memories

### Other Tools
- `subagent` - Delegate tasks to subagents
- `todo__todo_write` - Manage task lists
- `skills__loadSkill` - Load predefined skills

### Skills Available
- `brainstorming` - Creative and constructive work
- `concise-planning` - Generate actionable checklists
- `disk-cleanup` - Linux disk cleanup workflow
- `git-push-ssh` - Reliable git push with SSH agent
- `git-pushing` - Stage, commit, push changes
- `git-workflow` - Prevent merge conflicts
- `kaizen` - Continuous improvement
- `lint-and-validate` - Quality control and linting
- `movefileandcreatelink` - Safe file archiving to OneDrive
- `recursive-scan` - Large directory scanning
- `systematic-debugging` - Bug investigation

---

## CRITICAL REMINDERS

### Server Names
- ✅ **CORRECT:** unity87.hubgoo.com (Open Terminal is HERE)
- ❌ **WRONG:** unity84.hubgoo.com (DO NOT USE)

### API Key
- **Current Key:** `zhczXD4jxZh-6wKcIZKU8jr-nFNU90aW`
- **Status:** Persistent in .env file
- **Security:** NOT tracked in git (correct)

### Container Management
- **Always use:** `docker compose down` and `docker compose up -d`
- **Location:** `/code/open-terminal/`
- **Branch:** Work on `custom` branch, not `main`

### Git Workflow
- **Main branch:** Tracks upstream (open-webui/open-terminal)
- **Custom branch:** Your custom changes (docker-compose, auth, etc.)
- **Never:** Commit directly to main for custom changes
- **Always:** Rebase custom on top of updated main

---

## NEXT INSTRUCTIONS

**WAITING FOR USER INSTRUCTIONS**

Current status:
- ✅ Docker configuration set up with persistent API key
- ✅ Git workflow implemented (custom branch created)
- ✅ Documentation created (IMPLEMENTATION_PLAN.md, MULTI_USER_AUTHENTICATION_GUIDE.md, etc.)
- ✅ Container redeployed with new configuration
- ⏸️ **PAUSED** - Waiting for user to update Open WebUI with new API key

Pending work:
- Phase 1: Implement admin vs user distinction in Open Terminal code
- Phase 2: Configure Open WebUI integration with role-based access
- Phase 3: Finalize documentation and validation

---

**Document Purpose:** This AGENTS.md file ensures complete understanding of the Open Terminal implementation is not forgotten. Contains all critical context for future work.

**Status:** Current and accurate as of 2026-03-08 16:38:00  
**Maintenance:** Update as implementation progresses
