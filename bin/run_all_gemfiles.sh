#!/usr/bin/env bash

set -euo pipefail

GEMFILES_DIR="gemfiles"

for gemfile in "$GEMFILES_DIR"/*.gemfile; do
  echo "============================================================"
  echo "Using Gemfile: $gemfile"
  echo "============================================================"

  BUNDLE_GEMFILE="$gemfile" bundle check || BUNDLE_GEMFILE="$gemfile" bundle install
  BUNDLE_GEMFILE="$gemfile" bundle exec rspec
done
