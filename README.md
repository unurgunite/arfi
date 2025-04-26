# ARFI

![Alt](https://repobeats.axiom.co/api/embed/324b4f481b219890ef5a26e3c6fb73fff8929c93.svg "Repobeats analytics image")

---

**! WARNING !**

This project supports only PostgreSQL databases. In near future, ARFI will support MySQL databases. Since SQLite3 does
not support functional indexes with custom functions, this project won't support SQLite3 databases in near future.

---

ARFI – *ActiveRecord Functional Indexes*

ARFI gem brings you the ability to create and maintain functional indexes for your ActiveRecord models without
transition to `structure.sql` (SQL-based schema).

* [ARFI](#arfi)
    * [Installation](#installation)
    * [Usage](#usage)
        * [CLI](#cli)
        * [Project creation](#project-creation)
        * [Index creation](#index-creation)
        * [Index destroy](#index-destroy)
        * [Additional help](#additional-help)
    * [Development](#development)
        * [Build from source](#build-from-source)
    * [Requirements](#requirements)
    * [Contributing](#contributing)
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
`db/functions` directory under `function_name_v01.sql` name. Edit you index and run `bundle exec rails db:migrate`

### Index destroy

If you want to destroy your index, run `bundle exec arfi f_idx destroy function_name [revision (1 by default)]`

### Additional help

Run `bundle exec arfi` for additional help.

## Development

### Build from source

The manual installation includes installation via command line interface. it is practically no different from what
happens during the automatic build of the project:

```shell
git clone https://github.com/unurgunite/arfi.git
cd arfi
bundle install
gem build arfi.gemspec
gem install arfi-0.1.0.gem
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

## Roadmap

| Task           | Completed          |
|----------------|--------------------|
| db:migrate     | :white_check_mark: |
| db:setup       | :white_check_mark: |
| db:prepare     | :x:                |
| db:schema:load | :white_check_mark: |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/unurgunite/arfi. This project is intended to
be a safe, welcoming space for collaboration, and contributors are expected to adhere to
the [code of conduct](https://github.com/[USERNAME]/Arfi/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Arfi project's codebases, issue trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/[USERNAME]/Arfi/blob/master/CODE_OF_CONDUCT.md).
