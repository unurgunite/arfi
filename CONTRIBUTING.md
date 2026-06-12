# Contributing

Bug reports and pull requests are welcome.

## Pull Requests

1. Fork the repository.
2. Create a feature branch from `master`: `git checkout -b feature/my-change`
3. Make your changes.
4. Run the tests: `bundle exec rspec`
5. Run the linter: `bundle exec rubocop`
6. Run the type checker: `bundle exec steep check`
7. If you changed any YARD-documented methods, regenerate docs:
   ```shell
   bundle exec docscribe lib spec --rbs-collection
   ```
8. Commit with a conventional commit message (e.g. `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
9. Push your branch and open a pull request.

## Development Setup

See [Development](README.md#development) in the README.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
