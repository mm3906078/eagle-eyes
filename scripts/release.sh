#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get current version from mix.exs
get_current_version() {
    grep 'version:' mix.exs | head -1 | sed 's/.*version: "\(.*\)".*/\1/'
}

# Function to update version in mix.exs
update_version() {
    local new_version=$1
    sed -i "s/version: \".*\"/version: \"$new_version\"/" mix.exs
    print_info "Updated version to $new_version in mix.exs"
}

# Function to increment version
increment_version() {
    local version=$1
    local type=$2
    
    IFS='.' read -ra VERSION_PARTS <<< "$version"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    
    case $type in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid version type: $type"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Main script
main() {
    local version_type=${1:-patch}
    
    if [[ ! "$version_type" =~ ^(major|minor|patch)$ ]]; then
        print_error "Invalid version type. Use: major, minor, or patch"
        echo "Usage: $0 [major|minor|patch]"
        exit 1
    fi
    
    # Check if we're on main branch
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ]; then
        print_warning "You are not on the main branch (current: $current_branch)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Aborting release"
            exit 0
        fi
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_error "You have uncommitted changes. Please commit or stash them first."
        exit 1
    fi
    
    # Get current version and calculate new version
    current_version=$(get_current_version)
    new_version=$(increment_version "$current_version" "$version_type")
    
    print_info "Current version: $current_version"
    print_info "New version: $new_version"
    
    # Confirm with user
    read -p "Proceed with release? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborting release"
        exit 0
    fi
    
    # Update version
    update_version "$new_version"
    
    # Commit version bump
    git add mix.exs
    git commit -m "Bump version to $new_version"
    
    # Create and push tag
    tag_name="v$new_version"
    git tag -a "$tag_name" -m "Release $new_version"
    
    print_info "Created tag: $tag_name"
    print_info "Pushing changes and tag..."
    
    git push origin main
    git push origin "$tag_name"
    
    print_info "Release $new_version has been initiated!"
    print_info "Check GitHub Actions for build progress: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
}

# Run main function with all arguments
main "$@"
