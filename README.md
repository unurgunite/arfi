# ARFI

![Build status](https://img.shields.io/github/actions/workflow/status/unurgunite/arfi/main.yml "Build status")
[![Gem Version](https://badge.fury.io/rb/arfi.svg)](https://badge.fury.io/rb/arfi)

![Alt](https://repobeats.axiom.co/api/embed/324b4f481b219890ef5a26e3c6fb73fff8929c93.svg "Repobeats analytics image")

---

ARFI – *ActiveRecord Functions Integration*

ARFI helps Rails apps create and maintain **custom SQL functions** (often used for functional indexes and query helpers)
without switching from `schema.rb` to `structure.sql`.

ARFI follows a **"current state"** model: your repository contains the current function definitions in
`db/functions/**`, and ARFI loads them into the database automatically during common Rails DB tasks
(e.g., `db:prepare`, `db:test:prepare`, `db:migrate`, etc.).

PostgreSQL bonus: ARFI can recover at runtime from `PG::UndefinedFunction` by loading managed function files and
retrying the failed query once (thread-guarded).

ARFI supports both single-DB and multi-DB Rails setups.

Demo project: https://github.com/unurgunite/poc_arfi_72

---

* [ARFI](#arfi)
    * [Installation](#installation)
    * [Usage](#usage)
        * [Internal documentation](#internal-documentation)
        * [CLI](#cli)
        * [Project initialization](#project-initialization)
        * [Directory layout (1.0.0+)](#directory-layout-100)
        * [Function creation](#function-creation)
        * [Function destroy](#function-destroy)
        * [Additional help](#additional-help)
    * [Architecture](#architecture)
        * [Entry points](#entry-points)
        * [Decision flow](#decision-flow)
        * [Key design points](#key-design-points)
    * [Demo](#demo)
    * [Library features](#library-features)
    * [TODO](#todo)
    * [Commands](#commands)
        * [Function creation](#function-creation-1)
        * [Function destroy](#function-destroy-1)
            * [Options](#options)
                * [`--template` option](#--template-option)
                * [`--adapter` option](#--adapter-option)
                * [`--schema` option](#--schema-option)
                * [`--force` option](#--force-option)
    * [Limitations](#limitations)
    * [Development](#development)
        * [Run tests locally](#run-tests-locally)
        * [Build from source](#build-from-source)
    * [Requirements](#requirements)
    * [Contributing](#contributing)
    * [Miscellaneous](#miscellaneous)
    * [License](#license)
    * [Code of Conduct](#code-of-conduct)

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add arfi
```

## Usage

### Internal documentation

Internal documentation available at https://github.com/unurgunite/arfi_docs.

### CLI

ARFI uses Thor as a command line interface (CLI) instead of Rake, so it has a specific DSL.

### Project initialization

Run:

```bash
bundle exec arfi init
```

This ensures the directory structure exists:

```
db/functions/public
db/functions/postgresql/public
db/functions/mysql/public
```

Backwards-compatible alias:

```bash
bundle exec arfi project create
```

### Directory layout (1.0.0+)

Canonical layout (explicit `public`):

- Generic public: `db/functions/public/<function>.sql`
- PostgreSQL public: `db/functions/postgresql/public/<function>.sql`
- PostgreSQL schema: `db/functions/postgresql/<schema>/<function>.sql`
- MySQL / MariaDB / Trilogy public: `db/functions/mysql/public/<function>.sql`

Adapter-specific files override generic files by basename (same `<function>.sql`).
Files starting with `_` are ignored.

### Function creation

Run:

```bash
bundle exec arfi functions create function_name
```

The file location depends on adapter:

- PostgreSQL: `db/functions/postgresql/public/function_name.sql`
- MySQL/Trilogy: `db/functions/mysql/public/function_name.sql`
- Generic: `db/functions/public/function_name.sql`

Edit the function SQL and run your usual DB task (`db:migrate`, `db:prepare`, etc.).

You can also use a custom template for functions using the `--template` flag; this behaviour is described below.
Type `bundle exec arfi functions help create` for additional info.

Backwards-compatible alias:

```bash
bundle exec arfi f_idx create function_name
```

### Function destroy

Destroy deletes the function file from disk:

```bash
bundle exec arfi functions destroy function_name
```

Backwards-compatible alias:

```bash
bundle exec arfi f_idx destroy function_name
```

### Additional help

Run `bundle exec arfi` for additional help.

## Architecture

ARFI loads SQL function files into your database(s) during common Rails DB tasks. The flow depends on the entry point, database configuration, and adapter.

### Entry points

| Entry point                 | Description                                        |
|-----------------------------|----------------------------------------------------|
| `db:migrate` / `db:prepare` | Non-suffixed Rake tasks -> `_db:arfi_enhance`      |
| `db:migrate:animals`        | Suffixed Rake task -> `run_with_connection_switch` |
| Runtime retry               | `PG::UndefinedFunction` -> auto-reload             |
| Direct call                 | `SqlFunctionLoader.load!` from anywhere            |

### Decision flow

```mermaid
flowchart TD
    A(["SqlFunctionLoader.load!"]) --> B{"connection<br>passed?"}
    B -->|"Yes"| C["Use passed connection"]
    B -->|"No"| D{"multi_db?<br>AND<br>task_name nil?"}

    D -->|"No"| E["populate_db<br>(default_connection)"]
    D -->|"Yes"| F["populate_multiple_db"]

    F --> F1["Save original connection config"]
    F1 --> F2["For each DB config:"]
    F2 --> F3["establish_connection(config)"]
    F3 --> F4["populate_db(conn)"]
    F4 --> F2
    F2 --> F5["Restore original connection config"]

    C --> G["Check adapter support"]
    E --> G
    F5 --> G

    G --> H["Collect SQL files"]
    H --> I["db/functions/public/*.sql<br>(generic, priority 1-2)"]
    H --> J["db/functions/{pg,mysql}/**/*.sql<br>(adapter-specific, priority 8-10)"]

    I --> K["Override resolution:<br>higher priority wins"]
    J --> K
    K --> L["Ignore _prefixed files"]
    L --> M["Execute each SQL file"]

    M --> N{"clear_active_connections?"}
    N -->|"Yes"| O["connection_handler<br>.clear_active_connections!"]
    N -->|"No"| P["Skip cleanup"]

    subgraph Entry["Entry Points"]
        Q1["Rake: db:migrate"]
        Q2["Rake: db:migrate:animals"]
        Q3["Runtime: PG::UndefinedFunction"]
        Q4["Direct call"]
    end

    Q1 --> R1["_db:arfi_enhance<br>load!(task_name: nil)"]
    R1 --> A

    Q2 --> R2["_db:arfi_enhance:db:migrate:animals"]
    R2 --> R3["run_with_connection_switch"]
    R3 --> R4["Save original config"]
    R4 --> R5["establish_connection(animals)"]
    R5 --> A
    R5 --> R6["Restore original config"]

    Q3 --> R7["arfi_try_reload_and_retry?"]
    R7 --> R8["load!(task_name: 'arfi:runtime',<br>connection: self,<br>clear_active_connections: false)"]
    R8 --> A
```

### Key design points

- **Single-DB (default)**: loads functions into one connection, one `populate_db` call.
- **Multi-DB**: `populate_multiple_db` iterates over all configs for the current environment, loading functions into each. The original connection is saved before the loop and restored afterwards, matching the pattern used in `run_with_connection_switch`.
- **Suffixed tasks** (`db:migrate:animals`): switch to the named database, load functions, then restore the original connection.
- **Runtime retry**: triggered only for `PG::UndefinedFunction`, loads functions on the same connection without clearing other active connections.
- **File override**: adapter-specific files take priority over generic files. The highest priority file wins per schema+filename key.

## Demo

Demo available as separate project built with Rails 7.2 and PostgreSQL 14: https://github.com/unurgunite/poc_arfi_72.
README is also available.

## Library features

1. ARFI supports most Rails database initialization flows and respects your schema format and database configuration.

   | Task                     | Supported |
   |--------------------------|-----------|
   | db:migrate               | ✅         |
   | db:setup                 | ✅         |
   | db:prepare               | ✅         |
   | db:test:prepare          | ✅         |
   | db:schema:load           | ✅         |
   | db:migrate:db_name       | ✅         |
   | db:prepare:db_name       | ✅         |
   | db:schema:load:db_name   | ✅         |

2. Database support. ARFI supports PostgreSQL and MySQL-compatible databases, including multi-db setups.

   | DB adapter / client   | Tested                          |
   |-----------------------|---------------------------------|
   | PostgreSQL            | ✅                               |
   | MySQL (mysql2)        | ✅                               |
   | MariaDB (mysql2)      | ✅                               |
   | Trilogy (Rails 7.1+)  | ✅                               |
   | SQLite3               | Not supported (see Limitations) |

3. Rails support

   | Rails version | Tested |
   |---------------|--------|
   | 8             | ✅      |
   | 7             | ✅      |
   | 6             | ✅      |

## TODO

1. Add `functions validate` / `functions doctor` command group (planned for 1.1.0);
2. Add functions autoloader (v1.2.0);
3. Add more adapters (Oracle, MSSQL).

## Commands

ARFI has a set of commands to work with SQL functions. Type `bundle exec arfi help` for additional help. As noted above,
ARFI uses Thor as a command line interface.

### Function creation

To create a new function file, run:

```bash
bundle exec arfi functions create function_name
```

Also, there are some options:

| Option name  | Description                                                           | Possible values               | Default value                       |
|--------------|-----------------------------------------------------------------------|-------------------------------|-------------------------------------|
| `--template` | Use custom Ruby template that returns SQL                             | path within your filesystem   | nil                                 |
| `--adapter`  | Store function in adapter directory and use adapter skeleton/template | postgresql, mysql, trilogy    | nil (generic `db/functions/public`) |
| `--schema`   | PostgreSQL schema (alternative to `schema.function` form)             | schema name (postgresql only) | public                              |
| `--force`    | Overwrite existing function file if it already exists                 | true/false                    | false                               |

Backwards-compatible alias:

```bash
bundle exec arfi f_idx create function_name
```

### Function destroy

To destroy a function file, run:

```bash
bundle exec arfi functions destroy function_name
```

| Option name | Description                                          | Possible values               | Default value |
|-------------|------------------------------------------------------|-------------------------------|---------------|
| `--adapter` | Adapter-specific function directory                  | postgresql, mysql, trilogy    | nil (generic) |
| `--schema`  | PostgreSQL schema (alternative to `schema.function`) | schema name (postgresql only) | public        |

Backwards-compatible alias:

```bash
bundle exec arfi f_idx destroy function_name
```

#### Options

##### `--template` option

This option is used for creating an SQL function. In this case, the function will not be created with the default
template, but with a user-defined one. There are some rules for templates:

1. The template must be written in Ruby-compatible syntax: the function must be placed in a HEREDOC statement and must
   use interpolation for variables. You can use helper methods in the template file. The main rule is that the template
   must evaluate to a String with SQL.
2. ARFI supports dynamic variables in templates:
    - `index_name` (backward compatible) / `function_name`
    - `schema_name`
    - `qualified_name`
    - `original_ref`

   Default templates:

   PostgreSQL:
   ```ruby
   <<~SQL
     CREATE OR REPLACE FUNCTION #{qualified_name}() RETURNS TEXT[]
     LANGUAGE SQL
     IMMUTABLE AS
     $$
       -- Function body here
     $$
   SQL
   ```

   MySQL:
   ```ruby
   <<~SQL
     CREATE FUNCTION #{function_name} ()
     RETURNS return_type
     BEGIN
       -- Function body here
     END;
   SQL
   ```

3. By default, ARFI uses PostgreSQL template.

##### `--adapter` option

This option is used both when destroying and when creating an SQL function. In this case, the function will not be
created in the default directory `db/functions/public`, but in an adapter directory.

Supported adapters: `postgresql`, `mysql`, `trilogy`.

##### `--schema` option

PostgreSQL-only option that controls schema directory:

- `--adapter=postgresql --schema=audit` => `db/functions/postgresql/audit/<fn>.sql`

You can also pass schema-qualified names: `audit.my_fn`.

##### `--force` option

Overwrite existing function file if it already exists.

## Limitations

- SQLite3 is not supported for "stored functions from SQL files" because SQLite user-defined functions are typically
  registered per connection via the client library, not created via `CREATE FUNCTION` SQL.
- MySQL does not support `CREATE OR REPLACE FUNCTION` in the same way as PostgreSQL; plan function replacement strategy
  accordingly.

## Development

### Run tests locally

Start the required databases via Docker Compose:

```shell
docker compose up -d
```

Wait for both services to become healthy (check with `docker ps`). Then run the test suite:

```shell
bundle exec rspec
```

The test suite automatically detects available databases via environment variables:

| Variable            | Default value                                             |
|---------------------|-----------------------------------------------------------|
| `ARFI_POSTGRES_URL` | `postgresql://postgres:postgres@localhost:5432/arfi_test` |
| `ARFI_MYSQL_URL`    | `mysql2://root:password@127.0.0.1:3306/arfi_test`         |

Specs tagged with `:pgsql` or `:mysql` only run when the corresponding database is reachable;
untagged specs run with no external dependencies.

To stop the containers when done:

```shell
docker compose down
```

### Build from source

The manual installation includes installation via command line interface. It is practically no different from what
happens during the automatic build of the project:

```shell
git clone https://github.com/unurgunite/arfi.git
cd arfi
bundle install
gem build arfi.gemspec
gem install arfi-1.0.0.gem
```

Also, you can run `bin/setup` to automatically install everything needed.

## Requirements

ARFI is built on top of the following gems:

| Dependencies | Description                                                                                |
|--------------|--------------------------------------------------------------------------------------------|
| ActiveRecord | Used to patch `ActiveRecord::Base` module with new methods                                 |
| Rails        | Used for fetching project settings (database connection settings, Rails environment, etc.) |
| Thor         | For CLI development                                                                        |
| Rubocop      | For static code analysis                                                                   |
| Rake         | For patching built-in Rails Rake tasks                                                     |
| Steep        | For static type checking                                                                   |
| RBS          | For static type checking                                                                   |
| YARD         | For generating documentation                                                               |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/unurgunite/arfi. This project is intended to
be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [code of conduct](https://github.com/unurgunite/arfi/blob/master/CODE_OF_CONDUCT.md).

## Miscellaneous

ARFI differs by focusing on keeping functions in sync from the current repository state (and optional runtime recovery
on PostgreSQL).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ARFI project's codebases, issue trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/unurgunite/arfi/blob/master/CODE_OF_CONDUCT.md).
