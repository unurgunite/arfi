# ARFI

![Build status](https://img.shields.io/github/actions/workflow/status/unurgunite/arfi/main.yml "Build status")
[![Gem Version](https://badge.fury.io/rb/arfi.svg)](https://badge.fury.io/rb/arfi)

![Alt](https://repobeats.axiom.co/api/embed/324b4f481b219890ef5a26e3c6fb73fff8929c93.svg "Repobeats analytics image")

---

> [!WARNING]
> This project only supports PostgreSQL and MySQL databases. SQLite3 will be supported in the future as well as other
> databases supported by Rails.

> [!NOTE]
> This project requires Ruby 3.1.0+, in future updated 2.6+ Ruby versions will be supported.

---

ARFI – *ActiveRecord Functional Indexes*

The ARFI gem provides the ability to create and maintain custom SQL functions for ActiveRecord models without switching
to `structure.sql` (an SQL-based schema). You can use your own SQL functions in any part of the project, from migrations
and models to everything else. There is a working example in
the [demo project](https://github.com/unurgunite/poc_arfi_72). All instructions are described
in [README](https://github.com/unurgunite/poc_arfi_72/blob/master/README.md). ARFI supports all types of database
architectures implemented in Rails, suitable for both working with single databases and for simultaneous work with
multiple databases in the same environment.

* [ARFI](#arfi)
    * [Installation](#installation)
    * [Usage](#usage)
        * [CLI](#cli)
        * [Project creation](#project-creation)
        * [Index creation](#index-creation)
        * [Index destroy](#index-destroy)
        * [Additional help](#additional-help)
    * [Demo](#demo)
    * [Library features](#library-features)
    * [Roadmap](#roadmap)
    * [Commands](#commands)
        * [Function creation](#function-creation)
        * [Function destroy](#function-destroy)
            * [Options](#options)
                * [`--template` option](#--template-option)
                * [`--adapter` option](#--adapter-option)
    * [Limitations](#limitations)
    * [Development](#development)
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

### CLI

ARFI uses Thor as a command line interface (CLI) instead of Rake, so it has a specific DSL.

### Project creation

Firstly, run `bundle exec arfi project create` to create a new project. This command will create `db/functions`
directory. ARFI uses `db/functions` directory to store your functional indexes.

### Index creation

Run `bundle exec arfi f_idx create function_name` to create a new functional index. New index will be created in
`db/functions` directory under `function_name_v01.sql` name. Edit you index and run `bundle exec rails db:migrate`. You
can also use custom template for index. Type `bundle exec arfi f_idx help create` for additional info.

### Index destroy

If you want to destroy your index, run `bundle exec arfi f_idx destroy function_name [revision (1 by default)]`

### Additional help

Run `bundle exec arfi` for additional help.

## Demo

Demo available as separate project built with Rails 7.2 and PostgreSQL 14: https://github.com/unurgunite/poc_arfi_72.
README is also available.

## Library features

1. ARFI supports about all types of database initialization. It respects your database schema format and database
   configuration.

   | Task             | Completed                                                    |
   |------------------|--------------------------------------------------------------|
   | db:migrate       | :white_check_mark:                                           |
   | db:setup         | :white_check_mark:                                           |
   | db:prepare       | :white_check_mark:                                           |
   | db:schema:load   | :white_check_mark:                                           |
   | db:reset         | :white_check_mark:                                           |
   | db:setup:db_name | In progress (see [limitations][1]) :arrows_counterclockwise: |

2. Database support. ARFI supports PostgreSQL and MySQL databases and projects with multiple databases at the same time.

   | DB adapter | Tested                                |
   |------------|---------------------------------------|
   | PostgreSQL | :white_check_mark:                    |
   | MySQL      | :white_check_mark:                    |
   | SQLite3    | In progress :arrows_counterclockwise: |

3. Rails support

   | Rails version | Tested                                |
   |---------------|---------------------------------------|
   | 8             | :white_check_mark:                    |
   | 7             | :white_check_mark:                    |
   | 6             | In progress :arrows_counterclockwise: |

## Roadmap

1. ~~Custom template for SQL functions using `--template` flag;~~
2. ~~Multidb support (Rails 6+ feature);~~
3. Add support for 4+ ActiveRecord;
4. Add RSpec tests;
5. Add separate YARD doc page;
6. ~~Update CI/CD;~~
7. Add support for Ruby 2.6+.

## Commands

ARFI has a set of commands to work with SQL functions. Type `bundle exec arfi help` for additional help. As noted above,
ARFI uses Thor as a command line interface.

### Function creation

ARFI supports creation of SQL functions. To create a new function, run `bundle exec arfi f_idx create function_name`.
Also, there are some options:

| Option name  | Description                                                                          | Possible values            | Default value                                                 |
|--------------|--------------------------------------------------------------------------------------|----------------------------|---------------------------------------------------------------|
| `--template` | use custom template                                                                  | path within you filesystem | nil (will be used default template for each type of adapters) |
| `--adapter`  | adapter specific function creation due to syntax differences between different RDBMS | postgresql, mysql          | nil (function will be stored in generic `db/functions`)       |

### Function destroy

ARFI supports destroy of SQL functions. To destroy a function, run
`bundle exec arfi f_idx destroy function_name [revision (1 by default)]`.

| Option name  | Description                  | Possible values   | Default value                                              |
|--------------|------------------------------|-------------------|------------------------------------------------------------|
| `--revision` | Function revision to destroy | Integer           | 1                                                          |
| `--adapter`  | adapter specific function    | postgresql, mysql | nil (function will be destroyed in generic `db/functions`) |

#### Options

##### `--template` option

This option is used for creating an SQL function. In this case, the function will not be created with the default
template, but with user defined. There are some rules for templates:

1. The template must be written in a Ruby-compatible syntax: the function must be placed in a HEREDOC statement and must
   use interpolation for variables. If you need to take a more comprehensive approach to the issue of function
   generation, you can try using your own methods in the template file. No matter what you write there, the main rule is
   that your main method should return a string with a function template, as described below.
2. ARFI supports dynamic variables in templates, but only one at the moment. You need to specify `index_name`
   variable as below. In feature updated ARFI will support more variables. Here are default templates in ARFI for
   PostgreSQL and MySQL:

   PostgreSQL:
    ```ruby
    <<~SQL
      CREATE OR REPLACE FUNCTION #{index_name}() RETURNS TEXT[]
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
      CREATE FUNCTION #{index_name} ()
      RETURNS return_type
      BEGIN
        -- Function body here
      END;
    SQL
    ```
3. By default ARFI uses PostgreSQL template.

##### `--adapter` option

This option is used both when destroying and when creating an SQL function. In this case, the function will not be
created in the default directory `db/functions`, but in the child `db/functions/#{adapter}`. Supported adapters:
`postgresql`and `mysql`, but there will be more in the future.

## Limitations

Currently, ARFI has a limitation for `db:setup:db_name` task due to the fact how Rails manage this rake task. More info
here: [limitations][1]. This command will work, but it is not recommended to use it. Note that this limitation applies
only to multi-db setup, default `db:setup` will work as expected.

## Development

### Build from source

The manual installation includes installation via command line interface. it is practically no different from what
happens during the automatic build of the project:

```shell
git clone https://github.com/unurgunite/arfi.git
cd arfi
bundle install
gem build arfi.gemspec
gem install arfi-0.5.0.gem
```

Also, you can run `bin/setup` to automatically install everything needed.

## Requirements

ARFI is built on top of the following gems:

| Dependencies | Description                                                                                |
|--------------|--------------------------------------------------------------------------------------------|
| ActiveRecord | Used to patch `ActiveRecord::Base` module with new methods.                                |
| Rails        | Used for fetching project settings (database connection settings, Rails environment, etc.) |
| Thor         | For CLI development.                                                                       |
| Rubocop      | For static code analysis.                                                                  |
| Rake         | For patching built-in Rails Rake tasks.                                                    |
| Steep        | For static type checking.                                                                  |
| RBS          | For static type checking.                                                                  |
| YARD         | For generating documentation.                                                              |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/unurgunite/arfi. This project is intended to
be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [code of conduct](https://github.com/unurgunite/arfi/blob/master/CODE_OF_CONDUCT.md).

## Miscellaneous

ARFI is highly inspired by https://github.com/teoljungberg/fx project.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ARFI project's codebases, issue trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/unurgunite/arfi/blob/master/CODE_OF_CONDUCT.md).

[1]: https://blog.saeloun.com/2021/10/27/rails-7-adds-database-specific-setup/#limitation
