#!/bin/bash

# check_docs.sh
# A lightweight script to find broken relative links in documentation files.

set -e

DOCS_DIR="docs"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Checking $DOCS_DIR for broken links..."

# Find all markdown files
find "$PROJECT_ROOT/$DOCS_DIR" -name "*.md" | while read -r file; do
    # Extract text that looks like [text](link)
    # Ignores http(s) links
    grep -o '\[[^]]*\]([^)]*)' "$file" | while read -r link_match; do
        target=$(echo "$link_match" | sed -E 's/.*\]\(([^)]*)\).*/\1/')
        
        # Skip external links and empty targets
        if [[ "$target" == http* ]] || [[ -z "$target" ]] || [[ "$target" == "#"* ]]; then
            continue
        fi

        # Determine path relative to the file containing the link
        file_dir=$(dirname "$file")
        
        # If the target path doesn't start with / it's relative
         if [[ "$target" != /* ]]; then
            target_path="$file_dir/$target"
        else
            target_path="$PROJECT_ROOT$target"
        fi
        
        # Remove any markdown section anchors (e.g. #section) for file checking
        target_path=$(echo "$target_path" | cut -d'#' -f1)

        if [ ! -f "$target_path" ]; then
            echo "❌ Broken link found in $(basename "$file"):"
            echo "   Line: $link_match"
            echo "   Target missing: $target_path"
            exit 1
        fi
    done
done

echo "✅ All internal document links are valid!"
exit 0
