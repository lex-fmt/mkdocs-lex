#!/usr/bin/env bash
set -e

# Change to the root directory of the project
cd "$(dirname "$0")/.."

echo "=> Cleaning up existing environments and caches..."
rm -rf .venv mkdocs_lex_plugin.egg-info .pytest_cache
find . -type d -name "__pycache__" -exec rm -rf {} +

echo "=> Creating a new Python virtual environment in .venv/"
python3 -m venv .venv
source .venv/bin/activate

echo "=> Upgrading pip..."
pip install --upgrade pip

echo "=> Installing mkdocs-lex in editable mode with dev dependencies..."
pip install -e '.[dev]'

echo "=> Development environment setup complete!"
echo "=> To activate the environment, run: source .venv/bin/activate"
