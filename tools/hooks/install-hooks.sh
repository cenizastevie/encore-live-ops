#!/bin/sh
# Installs git hooks that run the containerized checks.
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

for stage in pre-commit pre-push; do
    cat > "$HOOKS_DIR/$stage" <<EOF
#!/bin/sh
exec "\$(git rev-parse --show-toplevel)/tools/hooks/run-hooks.sh" $stage
EOF
    chmod +x "$HOOKS_DIR/$stage"
done

echo "Installed pre-commit and pre-push hooks."
