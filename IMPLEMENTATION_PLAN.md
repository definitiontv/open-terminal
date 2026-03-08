# Open Terminal + Open WebUI Integration Plan
## Admin vs User Distinction

**Status:** Planning Phase - Not Started  
**Date:** 2026-03-08  
**Objective:** Connect existing Open Terminal with existing Open WebUI (on different server), implement admin vs other users distinction

---

## Current State Analysis

### What We Have
- ✅ **Open Terminal running** on port 8017 (this server: unity84.hubgoo.com)
- ✅ **Docker container:** `definitiontv/open-terminal:latest`
- ✅ **Single API key** authentication (currently no multi-user support)
- ✅ **Open WebUI running** on different server
- ❌ **Admin vs user distinction** in Open Terminal
- ❌ **Integration between** Open WebUI and Open Terminal

### What We Need
- ✅ Open Terminal running on current server (port 8017) 
- ✅ Open WebUI running on different server
- ❌ **Open Terminal enhancement:** Admin vs user distinction
- ❌ **Open WebUI configuration:** Point to Open Terminal
- ❌ **Network configuration:** Ensure servers can communicate
- ❌ **Role-based permissions:** Admin vs user access levels

---

## STEP-BY-STEP IMPLEMENTATION PLAN

### **PHASE 1: Open Terminal Admin vs User Enhancement** 🔧
**Estimated Time:** 2-3 hours

#### Step 1.1: Analyze Current Authentication
- [ ] Review current `verify_api_key()` function
- [ ] Document single API key flow
- [ ] Identify all protected endpoints
- [ ] Test current authentication behavior

#### Step 1.2: Design Admin vs User Distinction
- [ ] Define admin permissions (full access)
- [ ] Define user permissions (limited access)
- [ ] Create role-based access control design
- [ ] Document permission matrix

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

#### Step 1.3: Implement Role-Based Authentication
- [ ] Update `env.py` to support roles
- [ ] Create admin API key configuration
- [ ] Create user API keys configuration
- [ ] Implement role detection in `verify_api_key()`

**Changes to `open_terminal/env.py`:**
```python
# Add role-based authentication
ADMIN_API_KEY = _resolve_file_env("OPEN_TERMINAL_ADMIN_KEY", "")
USER_API_KEYS = [
    _resolve_file_env(f"OPEN_TERMINAL_USER_KEY_{i}", "") 
    for i in range(1, 11)  # Support up to 10 user keys
]
USER_API_KEYS = [k for k in USER_API_KEYS if k]  # Filter empty keys

# Role detection
def get_role(api_key: str) -> str:
    """Determine role based on API key."""
    if api_key == ADMIN_API_KEY:
        return "admin"
    elif api_key in USER_API_KEYS:
        return "user"
    else:
        return None
```

#### Step 1.4: Update Main Authentication Logic
- [ ] Modify `verify_api_key()` in `main.py`
- [ ] Add role information to request state
- [ ] Create permission checking functions
- [ ] Update endpoints to use role-based access

**Changes to `open_terminal/main.py`:**
```python
# Enhanced authentication
async def verify_api_key_with_role(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    request: Request = None
):
    """Verify API key and attach role to request."""
    api_key = credentials.credentials if credentials else None
    role = get_role(api_key)
    
    if not role:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    request.state.role = role
    request.state.api_key = api_key

# Permission checking
def require_admin():
    """Dependency that requires admin role."""
    def dependency(request: Request):
        if getattr(request.state, 'role', None) != 'admin':
            raise HTTPException(status_code=403, detail="Admin access required")
    return dependency

def require_user_or_admin():
    """Dependency that allows both users and admins."""
    def dependency(request: Request):
        if getattr(request.state, 'role', None) not in ['admin', 'user']:
            raise HTTPException(status_code=401, detail="Authentication required")
    return dependency
```

#### Step 1.5: Apply Role-Based Access to Endpoints
- [ ] Update `/execute` endpoints (admin only)
- [ ] Update file operation endpoints (admin only)
- [ ] Update terminal session endpoints (admin only)
- [ ] Update notebook endpoints (admin only)
- [ ] Create user-restricted endpoint (limited execute)

**Endpoint Access Plan:**
```
ADMIN-ONLY ENDPOINTS:
- /execute (run commands)
- /files/delete (delete files)
- /files/move (move files)
- /api/terminals/* (manage terminals)
- /notebooks/* (execute notebooks)
- /ports/* (port detection)
- /proxy/* (port proxy)

USER ACCESS:
- /execute-limited (new endpoint - restricted commands)
- /files/read (read files)
- /files/write (write files - in allowed dirs)
- /files/list (list files)
- /files/grep (search files)
- /files/glob (search filenames)
```

#### Step 1.6: Testing Role-Based Access
- [ ] Test admin API key access
- [ ] Test user API key access
- [ ] Verify admin-only endpoints reject users
- [ ] Verify user endpoints work correctly
- [ ] Test permission edge cases

**PHASE 1 Completion Criteria:**
- ✅ Admin API key has full access
- ✅ User API keys have limited access
- ✅ Permission system works correctly
- ✅ No security bypasses possible

---

### **PHASE 2: Open WebUI Integration** 🔗
**Estimated Time:** 1-1.5 hours

#### Step 2.1: Verify Network Connectivity
- [ ] Test connectivity from Open WebUI server to Open Terminal
- [ ] Check firewall rules allow Open WebUI → Open Terminal
- [ ] Verify port 8017 is accessible from Open WebUI server
- [ ] Test basic API endpoint connectivity

#### Step 2.2: Open WebUI Terminal Configuration
- [ ] Access Open WebUI admin panel
- [ ] Navigate to Integrations → Open Terminal
- [ ] Add Open Terminal connection details
- [ ] Configure admin connection with admin API key
- [ ] Test admin terminal access from Open WebUI

**Open WebUI Configuration:**
```
Connection Name: Admin Terminal
URL: http://unity84.hubgoo.com:8017
API Key: [ADMIN_KEY]
Access Level: Admin
Allowed Users: [admin_user]
```

#### Step 2.3: Configure User Access in Open WebUI
- [ ] Create user groups in Open WebUI
- [ ] Assign user permissions for terminal access
- [ ] Configure user-specific terminal connection
- [ ] Configure user API key in Open WebUI
- [ ] Test user terminal access from Open WebUI

**Open WebUI User Configuration:**
```
User: regular_user
Role: User
Terminal Connection: User Terminal
API Key: [USER_KEY_1]
Permissions: Execute, Files (Read/Write)
Terminal URL: http://unity84.hubgoo.com:8017
```

#### Step 2.4: Test End-to-End Integration
- [ ] Admin login to Open WebUI
- [ ] Access terminal from Open WebUI interface
- [ ] Run admin-level commands through Open WebUI
- [ ] Test file operations (admin access)
- [ ] User login to Open WebUI
- [ ] Access terminal with user restrictions
- [ ] Verify user limitations work correctly

**PHASE 2 Completion Criteria:**
- ✅ Open WebUI connects to Open Terminal successfully
- ✅ Admin users have full terminal access
- ✅ Regular users have restricted terminal access
- ✅ Integration works end-to-end
- ✅ Network connectivity stable

---

### **PHASE 3: Documentation and Validation** 📋
**Estimated Time:** 30-45 minutes

#### Step 3.1: Create Configuration Documentation
- [ ] Document API key setup process
- [ ] Document role-based permissions
- [ ] Create Open WebUI integration guide
- [ ] Document network configuration
- [ ] Document troubleshooting steps

#### Step 3.2: Create Security Guidelines
- [ ] API key generation best practices
- [ ] Key rotation procedures
- [ ] Security audit checklist
- [ ] Network security recommendations
- [ ] Common security mistakes to avoid

#### Step 3.3: Final Testing and Validation
- [ ] Comprehensive security testing
- [ ] Permission boundary testing
- [ ] Multi-user concurrency testing
- [ ] Network stability testing
- [ ] Error handling validation
- [ ] Documentation review

**PHASE 3 Completion Criteria:**
- ✅ Complete documentation available
- ✅ Security guidelines established
- ✅ System fully tested and validated
- ✅ Ready for production use

---

## IMPLEMENTATION ORDER

### We will execute in this exact order:

1. **PHASE 1: Open Terminal Enhancement** (First)
   - Why: Need admin vs user distinction before integration
   - Risk: Medium - code changes to authentication
   - Dependencies: None (Open WebUI already running)

2. **PHASE 2: Open WebUI Integration** (Second)
   - Why: Connect both existing systems together
   - Risk: Low - configuration only
   - Dependencies: Phase 1 complete

3. **PHASE 3: Documentation** (Last)
   - Why: Document complete solution
   - Risk: None - documentation only
   - Dependencies: Phases 1 & 2 complete

---

## RISK ASSESSMENT

### Low Risk Steps
- ✅ Open WebUI configuration (existing system)
- ✅ Network connectivity verification (non-invasive)
- ✅ Documentation creation
- ✅ Testing and validation

### Medium Risk Steps
- ⚠️ Authentication code modifications
- ⚠️ Permission system implementation
- ⚠️ Integration testing across servers

### Mitigation Strategies
1. **Backup current state** before code changes
2. **Test in development** before production deployment
3. **Gradual rollout** with validation at each step
4. **Rollback plan** if issues arise
5. **Network testing** before final integration

---

## ROLLBACK PLAN

If any phase fails, here's how to revert:

### Phase 1 Rollback (Open Terminal Changes)
```bash
# Restore original files
git checkout -- open_terminal/env.py
git checkout -- open_terminal/main.py

# Restart container with original code
docker restart open-terminal

# Revert environment variables if needed
unset OPEN_TERMINAL_ADMIN_KEY
unset OPEN_TERMINAL_USER_KEY_1
```

### Phase 2 Rollback (Integration)
```bash
# Remove Open WebUI terminal connection
# Access Open WebUI admin panel
# Navigate to Integrations → Open Terminal
# Delete the terminal connection
# Open Terminal unaffected, continues running
```

### Phase 3 Rollback (Documentation)
```bash
# Remove updated documentation
# No system changes to revert
# Keep old documentation for reference
```

---

## SUCCESS CRITERIA

### Phase Completion Checklist

**Phase 1 Success:**
- [ ] Admin API key works with full permissions
- [ ] User API keys work with limited permissions
- [ ] Permission system enforced correctly
- [ ] No security vulnerabilities
- [ ] Open Terminal container stable

**Phase 2 Success:**
- [ ] Open WebUI connects to Open Terminal successfully
- [ ] Admin users have full terminal access through Open WebUI
- [ ] Regular users have restricted terminal access through Open WebUI
- [ ] Integration works seamlessly
- [ ] Network connectivity stable
- [ ] No CORS or firewall issues

**Phase 3 Success:**
- [ ] Complete documentation exists
- [ ] Security guidelines established
- [ ] System validated and production-ready
- [ ] User guides available
- [ ] Troubleshooting documented

### Overall Success:
- [ ] Multi-user Open Terminal system operational
- [ ] Admin vs user distinction working correctly
- [ ] Open WebUI integration functional across servers
- [ ] Security and permissions validated
- [ ] Documentation complete and accessible
- [ ] Production-ready deployment

---

## ESTIMATED TOTAL TIME

- **Phase 1 (Open Terminal Enhancement):** 2-3 hours
- **Phase 2 (Integration):** 1-1.5 hours
- **Phase 3 (Documentation):** 30-45 minutes

**Total Estimated Time:** 3.5-5 hours

---

## NETWORK ARCHITECTURE

### Current Setup:
```
Open WebUI Server (Different Server)
    ↓ HTTP/WebSocket
    ↓
Open Terminal Server (unity84.hubgoo.com:8017)
    ↓ Docker Container
    ↓
Terminal API (port 8017)
```

### Required Configuration:
1. **Open WebUI Server → Open Terminal Server:**
   - Firewall rules allow connections
   - CORS configured properly
   - SSL/TLS if needed
   - Network latency acceptable

2. **Open Terminal Server:**
   - Container port 8017 exposed
   - API keys configured
   - Role-based authentication working
   - Ready for external connections

---

## NEXT STEP

**When you're ready to begin, we will start with:**

### Phase 1, Step 1.1: Analyze Current Authentication

This will involve:
1. Reviewing current `verify_api_key()` function in main.py
2. Documenting single API key flow
3. Identifying all protected endpoints
4. Testing current authentication behavior

**Do you want to proceed with Phase 1, Step 1.1?**

---

## NOTES

- This is a working document - will be updated as we progress
- Each phase has clear completion criteria
- Rollback plans defined for each phase
- Risk assessment provided for informed decisions
- Success criteria clearly defined
- Both systems already running (no deployment needed)
- Focus on integration and permission enhancement

**Document Status:** Ready for Implementation  
**Last Updated:** 2026-03-08 15:05  
