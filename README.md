# ARFI

![Alt](https://repobeats.axiom.co/api/embed/324b4f481b219890ef5a26e3c6fb73fff8929c93.svg "Repobeats analytics image")

---

> [!WARNING]
> This project only supports PostgreSQL databases, however, MySQL usage will also be available in upcoming updates.
> Since SQLite3 does not support functional indexes with custom functions, support for this database will not be
> available for a while, however, you can help the project by contributing to the open source.

> [!NOTE]
> This project requires Ruby 3.1.0+, it has not yet been tested on other versions, however, at the time of writing,
> backward compatibility was maintained wherever possible.

---

ARFI – *ActiveRecord Functional Indexes*

ARFI gem brings you the ability to create and maintain functional indexes for your ActiveRecord models without
transition to `structure.sql` (SQL-based schema). There is a working example in
the [demo project](https://github.com/unurgunite/poc_arfi_72). All instructions are described in
the [README](https://github.com/unurgunite/poc_arfi_72/blob/master/README.md).

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
   | db:setup:db_name | In progress (see [limitations][1]) :arrows_counterclockwise: |

2. Database support

   | DB adapter     | Tested                                                |
   |----------------|-------------------------------------------------------|
   | PostgreSQL     | 9+ :white_check_mark:                                 |
   | MySQL          | :white_check_mark:                                    |
   | SQLite3        | In progress (not primarily) :arrows_counterclockwise: |

3. Rails support

   | Rails version | Tested                                |
   |---------------|---------------------------------------|
   | 8             | In progress :arrows_counterclockwise: |
   | 7             | :white_check_mark:                    |
   | 6             | In progress :arrows_counterclockwise: |

## Roadmap

1. ~~Custom template for SQL functions using `--template` flag;~~
2. ~~Multidb support (Rails 6+ feature);~~
3. Add support for 4+ ActiveRecord;
4. Add RSpec tests;
5. Add separate YARD doc page;
6. Update CI/CD;
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

| Option name | Description                  | Possible values   | Default value                                              |
|-------------|------------------------------|-------------------|------------------------------------------------------------|
| --revision  | Function revision to destroy | Integer           | 1                                                          |
| --adapter   | adapter specific function    | postgresql, mysql | nil (function will be destroyed in generic `db/functions`) |

## Development

### Build from source

The manual installation includes installation via command line interface. it is practically no different from what
happens during the automatic build of the project:

```shell
git clone https://github.com/unurgunite/arfi.git
cd arfi
bundle install
gem build arfi.gemspec
gem install arfi-0.4.0.gem
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
