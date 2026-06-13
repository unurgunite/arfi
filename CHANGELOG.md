## [Unreleased]

### v1.0.0 - 2026-06-13

#### Added

- **Database adapters**: MySQL, MariaDB, and Trilogy (Rails 7.1+) support — built-in, not a third-party gem
- **Multi-database Rails support**: iterate over all DB configs for the current environment; works with suffixed Rake tasks (`db:migrate:animals`) and non-suffixed tasks
- **Runtime recovery**: `PG::UndefinedFunction` auto-reload — catches the error, reloads function files on the same connection, retries the query once (thread-guarded)
- **CLI (Thor-based)**:
  - `arfi init` — bootstrap `db/functions/` directory structure
  - `arfi functions create/destroy` — manage function SQL files
  - `--template` option for custom Ruby templates (variables: `function_name`, `schema_name`, `qualified_name`, `original_ref`)
  - `--adapter postgresql|mysql|trilogy` for adapter-specific placement and skeletons
  - `--schema <name>` for PostgreSQL schema-qualified functions
  - Backward-compatible aliases: `arfi project create`, `arfi f_idx create/destroy`
- **Directory layout (1.0.0+)**: `db/functions/public/`, `db/functions/postgresql/{public,schema}/`, `db/functions/mysql/public/` with adapter-over-generic override resolution
- **Rake integration**: hooks into `db:migrate`, `db:prepare`, `db:setup`, `db:test:prepare`, `db:schema:load` for both single-DB and multi-DB
- **RBS type signatures** for all public and private methods (`sig/`)
- **Steep type checking** in CI
- **RuboCop** with sorted-methods-by-call enforcement
- **RSpec test suite** with Docker Compose (PostgreSQL + MySQL) for integration specs
- **GitHub Actions CI**: lint, typecheck, docscribe verification, matrix tests (Rails 6.0–8.1, Ruby 2.7–4.0, MariaDB)
- **Docscribe integration** for YARD documentation validation
- **Community files**: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue/PR templates

#### Fixed

- **Multi-DB connection restore**: `populate_multiple_db` now saves the original connection config before iterating databases and restores it in `ensure`, matching the pattern used in `run_with_connection_switch` (db.rake). Previously the original connection was never restored.

#### Changed

- **CLI architecture**: migrated from Rake-based commands to Thor CLI with `functions` and `init` command groups
- **YARD documentation**: auto-generated via docscribe with `--rbs-collection` flag
- **Dependency management**: unified Gemfile with versioned gemfiles for Rails 6.0–8.1

#### Removed

- SQL function versioning system (single-file-per-function current-state model replaces versioned SQL files)

### [0.5.1] - 2025-06-13

#### Fixed

- Connection creation with ActiveRecord (`sql_function_loader.rb`) — improved compatibility with various AR connection pool configurations (#11)

### [0.5.0] - 2025-05-25

#### Added

- **YARD documentation generator**: `rakelib/yard_docs_generator.rake` for automated YARD docs generation
- **RBS signatures** for CLI and project commands
- **CI improvements**: expanded GitHub Actions workflow with broader Ruby/Rails matrix coverage
- **README documentation**: expanded with configuration details and usage examples

#### Changed

- **CLI commands**: updated project and f_idx commands with improved output formatting
- **SQL function loader**: refined SQL content extraction logic
- **Database statements**: added annotation to PostgreSQL database_statements extension

### [0.4.0] - 2025-05-18

#### Added

- **Multi-database support**: iterate over all DB configs for the current environment; works with suffixed Rake tasks (`db:migrate:animals`) and non-suffixed tasks
- **Rake tasks for multi-DB**: `db.rake` handles multiple database configurations
- **RBS signatures**: complete RBS type signatures for all public modules and classes
- **Steepfile**: Steep type checking configuration
- **rbs_collection**: dependency management for RBS types

#### Changed

- **SQL function loader**: refactored to support multiple database connections
- **Railtie**: updated to register tasks for multi-DB environments
- **CI workflow**: expanded to test against Rails 6.0–8.0 across multiple Ruby versions
- **CLI commands**: updated to accept database configuration parameters

### [0.3.1] - 2025-05-06

#### Added

- **Custom SQL templates**: `--template` flag with Ruby evaluation for standardized function patterns (supports `function_name`, `schema_name`, `qualified_name`, `original_ref` variables)
- **RBS type signatures**: initial type signatures for commands, errors, extensions, and SQL function loader
- **RSpec test suite**: specs for CLI commands and functional index management
- **GitHub Actions CI**: automated linting, type checking, and test runs

#### Fixed

- **Rake task registration**: non-migration tasks (`db:create`, `db:drop`) no longer interfere with Rails' default task execution (#2)

#### Changed

- **Gem renamed to `arfi`**: `ActiveRecord Functions Integration` — previously had a different gem name
- **CLI migrated to Thor**: added `arfi` executable with `project` and `f_idx` command groups

## [0.1.0] - 2025-04-22

- Initial release
