# Zed Config Justfile
# Run commands with: just <command>

# Default recipe
default:
    @just --list

# === Development Watchers ===

# Watch markdown files for changes
watch-md:
    @echo "Watching markdown files..."
    onchange "**/*.md" -- sh -c 'npx markdown-toc -i {{changed}} 2>/dev/null; npx prettier --write {{changed}}'

# Watch Python files for changes
watch-py:
    @echo "Watching Python files..."
    onchange "**/*.py" -- sh -c 'ruff format {{changed}} && ruff check --fix {{changed}}'

# Watch TypeScript/JavaScript files for changes
watch-ts:
    @echo "Watching TypeScript/JavaScript files..."
    onchange "**/*.{ts,tsx,js,jsx}" -- sh -c 'npx prettier --write {{changed}} && npx eslint --fix {{changed}}'

# Watch all supported files
watch-all:
    @echo "Watching all files..."
    just watch-md & just watch-py & just watch-ts

# === Quick Commands ===

# Run all linters
lint:
    @echo "=== Running Linters ==="
    -ruff check .
    -npx eslint .
    -npx tsc --noEmit
    -cargo clippy 2>/dev/null
    @echo "=== Done ==="

# Run all formatters
format:
    @echo "=== Running Formatters ==="
    -ruff format .
    -npx prettier --write .
    -cargo fmt 2>/dev/null
    @echo "=== Done ==="

# Format and lint
fix: format lint

# === Audits ===

# Full project audit
audit:
    @echo "=== Python Audit ==="
    -ruff check .
    -pyright .
    @echo ""
    @echo "=== JavaScript/TypeScript Audit ==="
    -npx tsc --noEmit
    -npx eslint .
    @echo ""
    @echo "=== Rust Audit ==="
    -cargo clippy -- -D warnings 2>/dev/null
    -cargo audit 2>/dev/null
    @echo ""
    @echo "=== Security Audit ==="
    -pip-audit 2>/dev/null
    -npm audit 2>/dev/null
    @echo ""
    @echo "=== Audit Complete ==="

# Security audit only
security:
    @echo "=== Security Audit ==="
    -pip-audit
    -npm audit
    -cargo audit 2>/dev/null

# === Django Commands ===

# Django check
django-check:
    python manage.py check
    python manage.py check --deploy

# Django migrations check
django-migrations:
    python manage.py makemigrations --check --dry-run

# === Git Commands ===

# Git status
gs:
    git status

# Git log
gl:
    git log --oneline --graph --decorate -20

# === Utilities ===

# Clean common cache directories
clean:
    @echo "Cleaning cache directories..."
    -find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    -find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null
    -find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null
    -find . -type d -name "node_modules/.cache" -exec rm -rf {} + 2>/dev/null
    @echo "Done"

# Show system info
info:
    @echo "=== System Info ==="
    @echo "Node: $(node --version 2>/dev/null || echo 'not installed')"
    @echo "npm: $(npm --version 2>/dev/null || echo 'not installed')"
    @echo "Python: $(python3 --version 2>/dev/null || echo 'not installed')"
    @echo "Rust: $(rustc --version 2>/dev/null || echo 'not installed')"
    @echo "Ruff: $(ruff --version 2>/dev/null || echo 'not installed')"
    @echo "Pyright: $(pyright --version 2>/dev/null || echo 'not installed')"

# === Zedconfig ===

# Install zedconfig to system
install:
    ./install.sh

# Verify prerequisites
verify:
    ./verify-setup.sh
