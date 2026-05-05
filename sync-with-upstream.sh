#!/bin/bash
# sync-with-upstream.sh
# Automated git workflow for maintaining custom branches while tracking upstream
# 
# Usage:
#   ./sync-with-upstream.sh [branch-name]
#   ./sync-with-upstream.sh custom
#   ./sync-with-upstream.sh --dry-run custom
#   ./sync-with-upstream.sh --help

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CUSTOM_BRANCH="${1:-custom}"
DRY_RUN=false
PROMPT=true
STASH_CHANGES=true

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS] [branch-name]"
    echo ""
    echo "Automated git workflow for maintaining custom branches while tracking upstream"
    echo ""
    echo "Arguments:"
    echo "  branch-name    Name of your custom branch (default: custom)"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -n, --dry-run  Show what would be done without making changes"
    echo "  -y, --yes      Skip confirmation prompts"
    echo "  --no-stash     Don't stash local changes (will fail if dirty)"
    echo ""
    echo "Examples:"
    echo "  $0 custom                    # Sync 'custom' branch with prompts"
    echo "  $0 --dry-run custom          # Preview changes without executing"
    echo "  $0 --yes custom              # Sync without confirmation"
    echo "  $0 production                 # Sync 'production' branch"
    echo ""
}

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Run git command (or echo in dry-run mode)
git_cmd() {
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN: git $*"
        return 0
    else
        git "$@"
    fi
}

# Check if git repo is properly configured
check_repo_config() {
    print_info "Checking repository configuration..."
    
    # Check if we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    # Check for upstream remote
    if ! git remote get-url upstream > /dev/null 2>&1; then
        print_error "No 'upstream' remote configured"
        print_info "Add upstream with: git remote add upstream <upstream-url>"
        exit 1
    fi
    
    # Check for origin remote
    if ! git remote get-url origin > /dev/null 2>&1; then
        print_error "No 'origin' remote configured"
        print_info "Add origin with: git remote add origin <your-fork-url>"
        exit 1
    fi
    
    print_success "Repository properly configured"
    print_info "Origin: $(git remote get-url origin)"
    print_info "Upstream: $(git remote get-url upstream)"
}

# Stash local changes if needed
stash_changes() {
    if [ "$STASH_CHANGES" = false ]; then
        return
    fi
    
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_warning "Local changes detected"
        
        if [ "$PROMPT" = true ] && [ "$DRY_RUN" = false ]; then
            read -p "Stash local changes? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
                print_error "Aborting due to uncommitted changes"
                exit 1
            fi
        fi
        
        print_info "Stashing local changes..."
        git_cmd stash push -m "sync-with-upstream: $(date)"
        STASHED=true
    else
        STASHED=false
    fi
}

# Restore stashed changes
restore_stash() {
    if [ "$STASHED" = true ] && [ "$DRY_RUN" = false ]; then
        print_info "Restoring stashed changes..."
        git_cmd stash pop
    fi
}

# Check if custom branch exists
check_custom_branch() {
    print_info "Checking for custom branch: $CUSTOM_BRANCH"
    
    if git show-ref --verify --quiet "refs/heads/$CUSTOM_BRANCH"; then
        print_success "Custom branch '$CUSTOM_BRANCH' exists locally"
        BRANCH_EXISTS=true
    else
        print_warning "Custom branch '$CUSTOM_BRANCH' does not exist locally"
        
        if [ "$PROMPT" = true ] && [ "$DRY_RUN" = false ]; then
            read -p "Create '$CUSTOM_BRANCH' branch from current main? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
                print_error "Aborting"
                exit 1
            fi
        fi
        
        print_info "Creating '$CUSTOM_BRANCH' branch from main..."
        git_cmd checkout -b "$CUSTOM_BRANCH"
        BRANCH_EXISTS=false
    fi
}

# Sync main branch with upstream
sync_main_branch() {
    print_info "Syncing main branch with upstream..."
    
    # Save current branch
    CURRENT_BRANCH=$(git branch --show-current)
    
    # Checkout main
    print_info "Checking out main..."
    git_cmd checkout main
    
    # Fetch upstream
    print_info "Fetching upstream changes..."
    git_cmd fetch upstream
    
    # Merge upstream/main
    print_info "Merging upstream/main into main..."
    git_cmd merge upstream/main -m "chore: merge upstream changes"
    
    # Push to origin
    print_info "Pushing main to origin..."
    git_cmd push origin main
    
    # Return to current branch
    if [ "$CURRENT_BRANCH" != "main" ]; then
        print_info "Returning to $CURRENT_BRANCH..."
        git_cmd checkout "$CURRENT_BRANCH"
    fi
}

# Rebase custom branch on main
rebase_custom_branch() {
    print_info "Rebasing $CUSTOM_BRANCH on top of main..."
    
    # Checkout custom branch
    if [ "$(git branch --show-current)" != "$CUSTOM_BRANCH" ]; then
        git_cmd checkout "$CUSTOM_BRANCH"
    fi
    
    # Rebase main
    print_info "Rebasing $CUSTOM_BRANCH onto main..."
    if ! git_cmd rebase main; then
        print_error "Rebase conflict detected!"
        print_info "Resolve conflicts and run:"
        echo "  git add <resolved-files>"
        echo "  git rebase --continue"
        print_info "Or abort with:"
        echo "  git rebase --abort"
        exit 1
    fi
    
    # Push to origin
    print_info "Pushing $CUSTOM_BRANCH to origin..."
    if [ "$BRANCH_EXISTS" = true ]; then
        # Force push if rebased
        git_cmd push origin "$CUSTOM_BRANCH" --force-with-lease
    else
        git_cmd push -u origin "$CUSTOM_BRANCH"
    fi
}

# Main workflow
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--yes)
                PROMPT=false
                shift
                ;;
            --no-stash)
                STASH_CHANGES=false
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                CUSTOM_BRANCH="$1"
                shift
                ;;
        esac
    done
    
    # Print banner
    echo "=================================="
    echo "  Sync with Upstream"
    echo "=================================="
    echo "Custom Branch: $CUSTOM_BRANCH"
    echo "Dry Run: $DRY_RUN"
    echo "=================================="
    echo ""
    
    # Confirm execution
    if [ "$PROMPT" = true ] && [ "$DRY_RUN" = false ]; then
        read -p "Continue? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
            print_info "Aborted"
            exit 0
        fi
    fi
    
    # Execute workflow
    check_repo_config
    stash_changes
    check_custom_branch
    sync_main_branch
    rebase_custom_branch
    restore_stash
    
    # Success message
    echo ""
    print_success "Sync complete!"
    echo ""
    print_info "Summary:"
    echo "  ✓ Main branch synced with upstream"
    echo "  ✓ $CUSTOM_BRANCH rebased on main"
    echo "  ✓ Changes pushed to origin"
    echo ""
    print_info "Next steps:"
    echo "  1. Test your changes: cd $CUSTOM_BRANCH && git diff main"
    echo "  2. Deploy if ready: docker compose down && docker compose up -d"
    echo "  3. Commit any new changes on $CUSTOM_BRANCH"
}

# Run main function
main "$@"
