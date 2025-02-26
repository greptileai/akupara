#!/bin/bash

# Create a temporary directory for packaging
TEMP_DIR=$(mktemp -d)
PACKAGE_NAME="terraform.tar.gz"

# Copy files to temp directory, excluding .gitignore patterns
rsync -a --exclude-from=.gitignore . "$TEMP_DIR/"

# Create tarball from temp directory
tar -czf "$PACKAGE_NAME" -C "$TEMP_DIR" .

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "Created package: $PACKAGE_NAME"
