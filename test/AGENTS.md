### Local Agent Context: test

## Setup & Commands

- Run all tests: `rake test`
- Run tests in a specific directory: `rake test TEST=test/aia`
- Run a specific test file: `bundle exec ruby -Ilib -Itest test/aia/some_test.rb`

## Code Style & Patterns

- Use descriptive test class names following the `ClassNameTest` pattern.
- Ensure all new tests include `require_relative '../test_helper'`.
- Prefer `mock` and `stub` methods from `Mocha` for mocking dependencies.
- Fixture files should be placed in relevant subdirectories, e.g., `test/aia/config_files/`.

## Mocha Cross-Test Contamination
- If code under test calls `AIA.config` and another test has stubbed it with `AIA.stubs(:config)`, Mocha will raise "unexpected invocation" in subsequent tests.
- **Fix**: Any test that directly or indirectly calls `AIA.config` must stub it explicitly with `AIA.stubs(:config).returns(...)` and unstub in `ensure`.

## Directive Test Patterns
- Tests for `/skill` and `/skills` directives live in `test/aia/directives/skill_directive_test.rb` and `test/aia/directives/web_and_file_directives_test.rb`.
- Stub the skills directory via `@instance.stubs(:aia_skills_dir).returns(tmpdir)` — do not swap the old `SKILLS_DIR` constant.
- Mock `AIA::LoggerManager.aia_logger` in setup to prevent errors when skill methods log: `AIA::LoggerManager.stubs(:aia_logger).returns(stub('logger', error: nil, warn: nil, info: nil, debug: nil))`.
- `/skill` returns `nil` on error (and prints to stdout). Assert `assert_nil result` and check `@captured_stdout.string` for the error message.
- `/llms` (model_directives) tests call `show_rubyllm_models(positive_terms, negative_terms)` with two array arguments. Tests for AND NOT filtering are in `test_show_rubyllm_models_excludes_by_negative_term` and related cases.
- `parse_search_terms` is on the `Directive` base class; it is exercised implicitly through `available_models`, `skills`, and `skill` method tests.

## Implementation Details

- **New Test Case**
  - Add the test case file in the closest logical directory, e.g., for a new tool, place under `test/aia/tools/`.
  - Ensure to include necessary `require_relative` statements for dependencies.
  - Follow existing patterns for structuring tests, using setup and teardown methods if applicable.

- **New Fixture**
  - Place configuration files in `test/aia/config_files/`.
  - For YAML fixtures, use naming conventions ending with `_test.yml`.

- **New Test Suite**
  - Create directory structure if needed, e.g., `test/aia/new_feature/`.
  - Add `test_helper.rb` to include setup for the new suite, ensuring `require_relative` calls align with the main directory.
