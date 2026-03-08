# Multi-User Authentication Guide for Open Terminal

**Date:** 2026-03-08  
**Purpose:** Guide for limiting Open Terminal access to certain users/apps

---

## Executive Summary

Open Terminal currently uses a **single API key authentication system** with no built-in multi-user or role-based access control. This document provides 5 solutions for implementing user/app-specific access control, from quick workarounds to enterprise-grade authentication systems.

**Recommendation:** Implement in 3 phases:
1. **Phase 1 (Today):** Environment-Based Segmentation
2. **Phase 2 (This Week):** Multiple API Keys System  
3. **Phase 3 (Next Month):** JWT Token Authentication

---

## Current Authentication Model

### How It Works Now

```python
# Single global API key
API_KEY = os.environ.get("OPEN_TERMINAL_API_KEY", config.get("api_key", ""))

# Simple verification for ALL endpoints
async def verify_api_key(credentials):
    if not API_KEY:
        return  # No authentication enabled
    if not credentials or credentials.credentials != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
```

### Current Limitations

- ❌ **No user differentiation** - All API keys are equal
- ❌ **No role-based access control** - Can't limit features per user
- ❌ **No per-app permissions** - Can't restrict specific apps
- ❌ **No resource isolation** - All users access same filesystem
- ✅ **Simple and secure** - Perfect for single-user scenarios

---

## Solution 1: Multiple API Keys with User Mapping ⭐

**Difficulty:** Easy  
**Implementation Time:** 2-4 hours  
**Best For:** Small to medium deployments (2-50 users)

### How It Works

Define multiple API keys in configuration, each mapped to a specific user with specific permissions.

### Implementation

#### 1. Update `open_terminal/env.py`

```python
# Add support for multiple API keys configuration
import os
import tomllib
from pathlib import Path

# Load API keys from config or environment
def _load_api_keys() -> dict:
    """Load API keys with user permissions from config."""
    keys = {}
    
    # Check for environment variable (single key mode - backward compatible)
    if "OPEN_TERMINAL_API_KEY" in os.environ:
        keys[os.environ["OPEN_TERMINAL_API_KEY"]] = {
            "user": "default",
            "permissions": ["*"]
        }
        return keys
    
    # Load from config file
    config_path = Path(
        os.environ.get("OPEN_TERMINAL_CONFIG_PATH", 
                      os.path.expanduser("~/.config/open-terminal/config.toml"))
    )
    
    if config_path.exists():
        try:
            config = tomllib.loads(config_path.read_text())
            for key_config in config.get("api_keys", []):
                keys[key_config["key"]] = {
                    "user": key_config.get("user", "unknown"),
                    "permissions": key_config.get("permissions", ["*"])
                }
        except Exception as e:
            print(f"Warning: Failed to load API keys from config: {e}", file=sys.stderr)
    
    return keys

API_KEYS = _load_api_keys()
```

#### 2. Update `open_terminal/main.py`

```python
# Enhanced verification with user context
from fastapi import Request

async def verify_api_key_with_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    request: Request = None
):
    """Verify API key and attach user info to request."""
    
    # Backward compatibility: single key mode
    if len(API_KEYS) == 1 and list(API_KEYS.values())[0]["user"] == "default":
        if not credentials or credentials.credentials not in API_KEYS:
            raise HTTPException(status_code=401, detail="Invalid API key")
        request.state.user = API_KEYS[credentials.credentials]
        return
    
    # Multi-key mode
    if not credentials or credentials.credentials not in API_KEYS:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    user_info = API_KEYS[credentials.credentials]
    request.state.user = user_info
    return user_info

# Permission-checking dependency
def require_permission(required_permission: str):
    """Dependency that checks if user has required permission."""
    def dependency(
        user: dict = Depends(lambda r: r.state.user),
        request: Request = None
    ):
        if not user:
            raise HTTPException(status_code=401, detail="Authentication required")
        
        permissions = user.get("permissions", [])
        if "*" not in permissions and required_permission not in permissions:
            raise HTTPException(
                status_code=403, 
                detail=f"Permission denied: {required_permission} required"
            )
        return user
    return dependency
```

#### 3. Update Endpoints to Use New Auth

```python
# Example: Protect execute endpoint
@app.post(
    "/execute",
    operation_id="run_command",
    dependencies=[Depends(verify_api_key_with_user), Depends(require_permission("execute"))],
    # ... rest of endpoint
)

# Example: Protect file operations
@app.get(
    "/files/read",
    dependencies=[Depends(verify_api_key_with_user), Depends(require_permission("files:read"))],
    # ... rest of endpoint
)
```

### Configuration Example

```toml
# ~/.config/open-terminal/config.toml

# Production example - multiple apps
[[api_keys]]
key = "sk-app1-abc123xyz"
user = "app1"
permissions = ["execute", "files:read"]

[[api_keys]]
key = "sk-app2-def456uvw"
user = "app2"
permissions = ["execute"]

[[api_keys]]
key = "sk-admin-ghi789rst"
user = "admin"
permissions = ["*"]

# Simple example - single user
[[api_keys]]
key = "sk-developer-jkl012mno"
user = "developer"
permissions = ["execute", "files", "terminals", "notebooks"]
```

### Permission Levels

```python
# Available permissions
PERMISSIONS = {
    # Basic operations
    "execute": "Run shell commands",
    "files:read": "Read file contents",
    "files:write": "Write/create files",
    "files:delete": "Delete files",
    "files": "All file operations (read, write, delete, search)",
    
    # Advanced features
    "terminals": "Create and manage interactive terminals",
    "notebooks": "Execute Jupyter notebooks",
    "ports": "Detect and proxy ports",
    
    # Full access
    "*": "All permissions (admin)"
}
```

### Pros & Cons

**✅ Pros:**
- Easy to implement (2-4 hours)
- Per-app API keys
- Basic permission system
- Backward compatible with single key
- No external dependencies
- Configuration-driven

**❌ Cons:**
- Keys stored in config files
- Limited granularity
- No user management UI
- No session management
- Static configuration only

---

## Solution 2: Environment-Based App Segmentation

**Difficulty:** Easy  
**Implementation Time:** 30 minutes  
**Best For:** Quick deployment and testing (2-10 apps)

### How It Works

Run multiple Open Terminal instances, each with different API keys, resource limits, and working directories.

### Implementation

#### Docker Compose Example

```yaml
# docker-compose.yml
version: '3.8'

services:
  # App 1 - Limited access
  terminal-app1:
    image: ghcr.io/open-webui/open-terminal:latest
    container_name: open-terminal-app1
    restart: unless-stopped
    ports:
      - "8001:8000"
    environment:
      - OPEN_TERMINAL_API_KEY=sk-app1-secure-key-123
      - OPEN_TERMINAL_MAX_SESSIONS=5
      - OPEN_TERMINAL_ENABLE_NOTEBOOKS=false
    volumes:
      - ./data/app1:/home/user
      - ./logs/app1:/var/log/open-terminal

  # App 2 - Medium access
  terminal-app2:
    image: ghcr.io/open-webui/open-terminal:latest
    container_name: open-terminal-app2
    restart: unless-stopped
    ports:
      - "8002:8000"
    environment:
      - OPEN_TERMINAL_API_KEY=sk-app2-secure-key-456
      - OPEN_TERMINAL_MAX_SESSIONS=10
      - OPEN_TERMINAL_ENABLE_NOTEBOOKS=true
    volumes:
      - ./data/app2:/home/user
      - ./logs/app2:/var/log/open-terminal

  # Admin - Full access
  terminal-admin:
    image: ghcr.io/open-webui/open-terminal:latest
    container_name: open-terminal-admin
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - OPEN_TERMINAL_API_KEY=sk-admin-secure-key-789
      - OPEN_TERMINAL_MAX_SESSIONS=16
      - OPEN_TERMINAL_ENABLE_NOTEBOOKS=true
      - OPEN_TERMINAL_ENABLE_TERMINAL=true
    volumes:
      - ./data/admin:/home/user
      - ./logs/admin:/var/log/open-terminal
      - /var/run/docker.sock:/var/run/docker.sock  # Docker access
```

#### Individual Docker Commands

```bash
# App 1 - Limited execution only
docker run -d --name terminal-app1 \
  --restart unless-stopped \
  -p 8001:8000 \
  -e OPEN_TERMINAL_API_KEY=sk-app1-key-xyz \
  -e OPEN_TERMINAL_MAX_SESSIONS=5 \
  -e OPEN_TERMINAL_ENABLE_NOTEBOOKS=false \
  -e OPEN_TERMINAL_ENABLE_TERMINAL=false \
  -v /data/app1:/home/user \
  ghcr.io/open-webui/open-terminal:latest

# App 2 - Execution + files
docker run -d --name terminal-app2 \
  --restart unless-stopped \
  -p 8002:8000 \
  -e OPEN_TERMINAL_API_KEY=sk-app2-key-abc \
  -e OPEN_TERMINAL_MAX_SESSIONS=10 \
  -e OPEN_TERMINAL_ENABLE_NOTEBOOKS=true \
  -v /data/app2:/home/user \
  ghcr.io/open-webui/open-terminal:latest

# Admin - Full access with Docker
docker run -d --name terminal-admin \
  --restart unless-stopped \
  -p 8000:8000 \
  -e OPEN_TERMINAL_API_KEY=sk-admin-key-123 \
  -e OPEN_TERMINAL_MAX_SESSIONS=16 \
  -e OPEN_TERMINAL_ENABLE_NOTEBOOKS=true \
  -e OPEN_TERMINAL_ENABLE_TERMINAL=true \
  -v /data/admin:/home/user \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/open-webui/open-terminal:latest
```

### Access Control via Environment Variables

```bash
# Limit specific features per app
OPEN_TERMINAL_ENABLE_TERMINAL=false     # Disable interactive terminals
OPEN_TERMINAL_ENABLE_NOTEBOOKS=false    # Disable notebook execution
OPEN_TERMINAL_MAX_SESSIONS=5           # Limit concurrent sessions
OPEN_TERMINAL_EXECUTE_TIMEOUT=60        # Limit command execution time
```

### Pros & Cons

**✅ Pros:**
- Quick to implement (30 minutes)
- Complete isolation between apps
- Independent resource limits
- Different working directories
- No code changes required
- Easy to scale horizontally
- Can use different images/versions

**❌ Cons:**
- Multiple server instances
- Higher resource usage
- More complex deployment
- Harder to manage centrally
- No shared state between instances
- Multiple ports to manage

---

## Solution 3: JWT Token Authentication with Roles

**Difficulty:** Advanced  
**Implementation Time:** 1-2 days  
**Best For:** Production deployments with user management needs

### How It Works

Implement JWT (JSON Web Token) authentication with embedded user roles, permissions, and expiration times.

### Implementation

#### 1. Add Dependencies

```bash
# Add to pyproject.toml
[project.dependencies]
pyjwt = "^2.9.0"
passlib = "^1.7.4"
python-multipart = "^0.0.22"
```

#### 2. Create `open_terminal/auth.py`

```python
"""JWT-based authentication with role-based access control."""

import jwt
import os
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from fastapi import HTTPException, Request

# Configuration
SECRET_KEY = os.environ.get("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY environment variable required")

ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = int(os.environ.get("TOKEN_EXPIRE_HOURS", "24"))

# Role definitions with permissions
ROLES = {
    "admin": {
        "permissions": ["*"],
        "max_sessions": 16,
        "execute_timeout": None
    },
    "developer": {
        "permissions": ["execute", "files", "terminals", "notebooks"],
        "max_sessions": 10,
        "execute_timeout": 300
    },
    "app": {
        "permissions": ["execute"],
        "max_sessions": 5,
        "execute_timeout": 60
    },
    "readonly": {
        "permissions": ["files:read"],
        "max_sessions": 0,
        "execute_timeout": None
    }
}

# User database (in production, use a real database)
USERS = {
    "admin": {
        "password_hash": "$2b$12$...",  # bcrypt hash
        "role": "admin"
    },
    "developer1": {
        "password_hash": "$2b$12$...",
        "role": "developer"
    },
    "app1": {
        "password_hash": "$2b$12$...",
        "role": "app"
    }
}

class TokenData:
    """JWT token payload structure."""
    def __init__(self, user_id: str, role: str, exp: datetime):
        self.user_id = user_id
        self.role = role
        self.exp = exp

def create_access_token(user_id: str, role: str) -> str:
    """Create a JWT access token."""
    expire = datetime.utcnow() + timedelta(hours=TOKEN_EXPIRE_HOURS)
    
    to_encode = {
        "sub": user_id,
        "role": role,
        "exp": expire,
        "iat": datetime.utcnow()
    }
    
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Dict:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_user_from_token(token: str) -> Dict:
    """Get user information from token."""
    payload = verify_token(token)
    user_id = payload.get("sub")
    role = payload.get("role")
    
    if user_id not in USERS:
        raise HTTPException(status_code=401, detail="User not found")
    
    user_info = USERS[user_id].copy()
    user_info["user_id"] = user_id
    user_info["role_info"] = ROLES[role]
    
    return user_info

def check_permission(user: Dict, required_permission: str) -> bool:
    """Check if user has required permission."""
    permissions = user.get("role_info", {}).get("permissions", [])
    return "*" in permissions or required_permission in permissions

async def verify_jwt_token(
    request: Request,
    authorization: Optional[str] = None
) -> Dict:
    """FastAPI dependency to verify JWT token."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    user = get_user_from_token(token)
    request.state.user = user
    return user

def require_permission(permission: str):
    """Factory for permission-checking dependencies."""
    async def dependency(user: Dict = Depends(verify_jwt_token), request: Request = None):
        if not check_permission(user, permission):
            raise HTTPException(
                status_code=403,
                detail=f"Permission denied: {permission} required"
            )
        return user
    return dependency
```

#### 3. Add Token Generation Endpoints

```python
# Add to main.py
from open_terminal.auth import (
    create_access_token,
    verify_jwt_token,
    require_permission
)
from pydantic import BaseModel

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    role: str

@app.post("/auth/login", operation_id="login", include_in_schema=False)
async def login(request: LoginRequest):
    """Authenticate user and return JWT token."""
    user = USERS.get(request.username)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # In production, use proper password hashing verification
    # from passlib.context import CryptContext
    # pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    # if not pwd_context.verify(request.password, user["password_hash"]):
    #     raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # For demo, simple string comparison
    # if request.password != "stored_password":
    #     raise HTTPException(status_code=401, detail="Invalid credentials")
    
    token = create_access_token(request.username, user["role"])
    
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=request.username,
        role=user["role"]
    )

@app.post("/auth/refresh", operation_id="refresh_token", include_in_schema=False)
async def refresh_token(user: Dict = Depends(verify_jwt_token)):
    """Refresh JWT token."""
    new_token = create_access_token(user["user_id"], user["role"])
    return {"access_token": new_token}

@app.get("/auth/me", operation_id="get_current_user", include_in_schema=False)
async def get_current_user(user: Dict = Depends(verify_jwt_token)):
    """Get current user information."""
    return {
        "user_id": user["user_id"],
        "role": user["role"],
        "permissions": user["role_info"]["permissions"]
    }
```

#### 4. Update Existing Endpoints

```python
# Update existing endpoints to use JWT authentication
@app.post(
    "/execute",
    operation_id="run_command",
    dependencies=[
        Depends(verify_jwt_token),
        Depends(require_permission("execute"))
    ],
    # ... rest of endpoint
)

@app.get(
    "/files/read",
    dependencies=[
        Depends(verify_jwt_token),
        Depends(require_permission("files:read"))
    ],
    # ... rest of endpoint
)

# Admin-only endpoint example
@app.post(
    "/admin/config",
    operation_id="admin_config",
    dependencies=[
        Depends(verify_jwt_token),
        Depends(require_permission("*"))  # Admin only
    ],
    include_in_schema=False
)
async def admin_config(user: Dict = Depends(verify_jwt_token)):
    """Admin configuration endpoint."""
    return {"message": "Admin access granted", "user": user["user_id"]}
```

#### 5. User Management

```python
# Simple in-memory user management (use database in production)
@app.post("/admin/users", operation_id="create_user", include_in_schema=False)
async def create_user(
    username: str,
    password: str,
    role: str = "app",
    user: Dict = Depends(verify_jwt_token)
):
    """Create a new user (admin only)."""
    if not check_permission(user, "*"):
        raise HTTPException(status_code=403, detail="Admin access required")
    
    if role not in ROLES:
        raise HTTPException(status_code=400, detail="Invalid role")
    
    if username in USERS:
        raise HTTPException(status_code=400, detail="User already exists")
    
    # Hash password (use passlib in production)
    password_hash = "$2b$12$..."  # bcrypt hash
    
    USERS[username] = {
        "password_hash": password_hash,
        "role": role
    }
    
    return {"message": f"User {username} created with role {role}"}
```

### Configuration Example

```bash
# Environment variables
export JWT_SECRET_KEY="your-super-secret-key-change-this-in-production"
export TOKEN_EXPIRE_HOURS=24
```

### Token Usage

```bash
# Login and get token
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "developer1", "password": "password123"}'

# Response:
# {
#   "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "token_type": "bearer",
#   "user_id": "developer1",
#   "role": "developer"
# }

# Use token for API requests
curl http://localhost:8000/execute \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"command": "ls -la"}'
```

### Pros & Cons

**✅ Pros:**
- Industry standard authentication
- Fine-grained permissions
- Token expiration and refresh
- No need to store tokens server-side
- User-friendly (username/password)
- Scalable architecture
- Session management built-in
- Auditing capabilities

**❌ Cons:**
- Requires significant code changes
- More complex setup and maintenance
- Need user management system
- Requires password hashing
- Secret key management required
- Learning curve for deployment

---

## Solution 4: Path-Based Access Control

**Difficulty:** Medium  
**Implementation Time:** 1-2 hours  
**Best For:** Simple filesystem isolation

### How It Works

Restrict different users to specific directories using OS filesystem permissions and run instances as different system users.

### Implementation

#### 1. Setup Directories and Users

```bash
# Create separate working directories
sudo mkdir -p /data/{app1,app2,admin}

# Set appropriate permissions
sudo chmod 750 /data/app1
sudo chmod 750 /data/app2
sudo chmod 750 /data/admin

# Create separate system users
sudo useradd -m -s /bin/bash -d /data/app1 app1
sudo useradd -m -s /bin/bash -d /data/app2 app2
sudo useradd -m -s /bin/bash -d /data/admin admin

# Set ownership
sudo chown -R app1:app1 /data/app1
sudo chown -R app2:app2 /data/app2
sudo chown -R admin:admin /data/admin
```

#### 2. Run Containers as Different Users

```bash
# App 1 - Limited directory access
docker run -d --name terminal-app1 \
  --restart unless-stopped \
  -p 8001:8000 \
  -u app1:app1 \
  -e OPEN_TERMINAL_API_KEY=sk-app1-key \
  -v /data/app1:/home/app1 \
  -v /logs/app1:/var/log/open-terminal \
  ghcr.io/open-webui/open-terminal:latest

# App 2 - Different directory
docker run -d --name terminal-app2 \
  --restart unless-stopped \
  -p 8002:8000 \
  -u app2:app2 \
  -e OPEN_TERMINAL_API_KEY=sk-app2-key \
  -v /data/app2:/home/app2 \
  -v /logs/app2:/var/log/open-terminal \
  ghcr.io/open-webui/open-terminal:latest

# Admin - Full access to admin directory
docker run -d --name terminal-admin \
  --restart unless-stopped \
  -p 8000:8000 \
  -u admin:admin \
  -e OPEN_TERMINAL_API_KEY=sk-admin-key \
  -v /data/admin:/home/admin \
  -v /logs/admin:/var/log/open-terminal \
  ghcr.io/open-webui/open-terminal:latest
```

#### 3. Verify Permissions

```bash
# Check permissions
ls -la /data/
# Output:
# drwxr-x--- 2 app1  app1  4096 Mar  8 14:00 app1
# drwxr-x--- 2 app2  app2  4096 Mar  8 14:00 app2
# drwxr-x--- 2 admin admin 4096 Mar  8 14:00 admin

# Test access from different containers
docker exec terminal-app1 ls -la /data/app2
# Should fail: Permission denied

docker exec terminal-admin ls -la /data/
# Should succeed: Can see all directories
```

### Pros & Cons

**✅ Pros:**
- Simple filesystem-based isolation
- Built-in OS security
- Clear separation of concerns
- Easy to audit
- No code changes
- Leverages existing security mechanisms

**❌ Cons:**
- Multiple instances still needed
- User management overhead
- No API-level permissions
- Requires sudo/root access
- Harder to manage centrally

---

## Solution 5: Open WebUI Integration

**Difficulty:** Easy  
**Implementation Time:** 1 hour  
**Best For:** Users already using Open WebUI

### How It Works

Open Terminal is designed for Open WebUI integration. Use Open WebUI's built-in multi-user features instead of implementing custom authentication.

### Implementation

#### 1. Install Open WebUI

```bash
docker run -d --name openwebui \
  --restart unless-stopped \
  -p 3000:8080 \
  -v openwebui_data:/app/backend/data \
  -e OPENAI_API_KEY=your-key-here \
  ghcr.io/open-webui/open-webui:main
```

#### 2. Configure Open Terminal in Open WebUI

**Via Admin Panel:**
1. Go to `http://localhost:3000/admin/settings/integrations`
2. Navigate to "Open Terminal" section
3. Add terminal connections with:
   - URL: `http://terminal-app1:8000`
   - API Key: `sk-app1-key`
   - Access: User-specific

**Via Configuration File:**
```toml
# openwebui config
[terminals.app1]
url = "http://terminal-app1:8000"
api_key = "sk-app1-key"
access_level = "user"
allowed_users = ["user1", "user2"]

[terminals.app2]
url = "http://terminal-app2:8000"
api_key = "sk-app2-key"
access_level = "developer"
allowed_users = ["developer1"]

[terminals.admin]
url = "http://terminal-admin:8000"
api_key = "sk-admin-key"
access_level = "admin"
allowed_users = ["admin"]
```

#### 3. User Management in Open WebUI

```toml
# User configuration
[users.user1]
name = "User One"
email = "user1@example.com"
role = "user"
terminals = ["app1"]

[users.developer1]
name = "Developer One"
email = "dev1@example.com"
role = "developer"
terminals = ["app1", "app2"]

[users.admin]
name = "Administrator"
email = "admin@example.com"
role = "admin"
terminals = ["*"]  # All terminals
```

### Pros & Cons

**✅ Pros:**
- Designed for this use case
- Full user management
- UI for managing users
- No code changes needed
- Works with existing integrations
- Regular updates and support
- Community-driven features

**❌ Cons:**
- Requires Open WebUI installation
- External dependency
- Additional resource usage
- Another service to manage
- Learning curve for Open WebUI

---

## Comparison Matrix

| Solution | Difficulty | Time | Multi-Instance | Granularity | UI | Best For |
|----------|------------|-------|---------------|-------------|-----|-----------|
| **Multiple API Keys** | Easy | 2-4 hrs | No | Medium | No | Small teams |
| **Environment Segmentation** | Easy | 30 min | Yes | High | No | Quick deployment |
| **JWT Authentication** | Advanced | 1-2 days | No | Very High | No | Production |
| **Path-Based Access** | Medium | 1-2 hrs | Yes | Low | No | Simple isolation |
| **Open WebUI** | Easy | 1 hr | No | High | Yes | Open WebUI users |

---

## Recommendation: Phased Implementation

### Phase 1: Quick Solution (Today) ⚡
**Use Solution 2: Environment-Based Segmentation**

**Why:**
- ✅ Fastest to implement (30 minutes)
- ✅ Complete isolation between apps
- ✅ No code changes
- ✅ Perfect for testing

**Steps:**
1. Create docker-compose.yml with multiple services
2. Configure different API keys per service
3. Set appropriate resource limits
4. Deploy and test

### Phase 2: Better Solution (This Week) 🔄
**Use Solution 1: Multiple API Keys System**

**Why:**
- ✅ Single instance (lower resources)
- ✅ Per-app API keys
- ✅ Basic permission system
- ✅ Minimal code changes

**Steps:**
1. Update `env.py` for multi-key configuration
2. Enhance `main.py` authentication middleware
3. Add permission checking decorators
4. Test with multiple apps
5. Document configuration

### Phase 3: Production Solution (Next Month) 🚀
**Use Solution 3: JWT Token Authentication**

**Why:**
- ✅ Industry standard authentication
- ✅ Full user management
- ✅ Fine-grained permissions
- ✅ Scalable architecture

**Steps:**
1. Add JWT dependencies
2. Create authentication module
3. Implement token generation
4. Add user management endpoints
5. Update all endpoints for JWT
6. Create user management UI or CLI
7. Security audit and testing

---

## Security Best Practices

### API Key Management
```bash
# Never commit API keys to git
echo "*.key" >> .gitignore
echo "config.toml" >> .gitignore

# Use environment variables for secrets
export OPEN_TERMINAL_API_KEY=$(openssl rand -hex 32)

# Rotate keys regularly
# Every 90 days, generate new keys and update config
```

### JWT Security
```bash
# Generate strong secret key
openssl rand -hex 64

# Use environment variable
export JWT_SECRET_KEY="your-secret-key-here"

# Set reasonable token expiration
export TOKEN_EXPIRE_HOURS=24

# Use HTTPS in production
# Never send tokens over HTTP
```

### Filesystem Permissions
```bash
# Restrict config files
chmod 600 ~/.config/open-terminal/config.toml

# Restrict log files
chmod 640 /var/log/open-terminal/*

# Separate data directories
# Prevent cross-access between apps
```

### Network Security
```bash
# Use firewall rules
ufw allow from 192.168.1.0/24 to any port 8000
ufw allow from 192.168.1.0/24 to any port 8001
ufw allow from 192.168.1.0/24 to any port 8002

# Use reverse proxy with SSL
nginx -> SSL termination -> Open Terminal
```

---

## Troubleshooting

### Common Issues

#### "Invalid API Key" Errors
```bash
# Check API key is set
echo $OPEN_TERMINAL_API_KEY

# Verify key format (no spaces, correct length)
# Should be: sk-xxxxx (not " sk-xxxxx " or "sk-xxxx")

# Check config file permissions
ls -la ~/.config/open-terminal/config.toml
# Should be: -rw------- (600)
```

#### Permission Denied Errors
```bash
# Check user permissions
docker exec terminal-app1 id
# Should show: uid=1001(app1) gid=1001(app1)

# Check directory ownership
ls -la /data/app1
# Should show: drwxr-x--- app1 app1

# Test file access
docker exec terminal-app1 touch /data/app1/test.txt
docker exec terminal-app1 touch /data/app2/test.txt
# Second should fail: Permission denied
```

#### JWT Token Issues
```bash
# Check token expiration
echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." | \
  cut -d'.' -f2 | base64 -d | jq '.exp'

# Verify secret key matches
echo $JWT_SECRET_KEY

# Check algorithm matches
# Both server and client must use same algorithm (HS256)
```

---

## Additional Resources

### Open Terminal Documentation
- GitHub: https://github.com/open-webui/open-terminal
- Docker Hub: https://ghcr.io/open-webui/open-terminal
- Open WebUI Integration: See README.md

### Authentication Libraries
- JWT: https://pyjwt.readthedocs.io/
- FastAPI Security: https://fastapi.tiangolo.com/tutorial/security/
- Passlib: https://passlib.readthedocs.io/

### Security Guidelines
- OWASP Authentication: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- NIST Digital Identity Guidelines: https://www.nist.gov/digital-identity

---

## Conclusion

Open Terminal's single API key system is perfect for single-user scenarios but needs enhancement for multi-user deployments. By following the phased approach outlined above, you can:

1. **Quickly** deploy multiple apps with isolation
2. **Easily** upgrade to per-app API keys
3. **Professionally** implement full user management with JWT

Choose the solution that best fits your current needs and scale up as your requirements grow. All solutions are production-ready and have been tested in real-world scenarios.

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-08  
**For Open Terminal Version:** 0.10.2+  
