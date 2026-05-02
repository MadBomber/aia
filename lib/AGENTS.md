### Local Agent Context: lib

## Setup & Commands

- To run the AIA application, use: `ruby lib/aia.rb`
- Set up configurations by editing `lib/aia/config/defaults.yml` or using environment variables prefixed with `AIA_`.

## Code Style & Patterns

- Use single source of truth for configs: defined in `lib/aia/config/defaults.yml`
- CLI flags are mapped to nested config locations using the `CLI_TO_NESTED_MAP` hash within `aia/config.rb`.
- Initialize new components within the AIA module using `AIA` namespace, e.g., `AIA::ChatLoop`.

## Implementation Details

### Entry Point - `lib/aia.rb`
- Main application entry starts by loading essential modules and patches.
- Use `AIA.run` as the entrypoint method which initializes configuration, validates it, and starts the session.

### Configuring AIA - `lib/aia/config.rb`
- Configurations are merged from sources in priority: defaults => user config => ENV => CLI.
- Use `Config.setup(cli_overrides)` to initialize configuration with CLI argument overrides.
- Ensure `lib/aia/config/model_spec.rb` is loaded for model specification handling.
- Top-level config sections include: `service`, `llm`, `prompts`, `roles`, `skills`, `output`, `audio`, `image`, `embedding`, `tools`, `flags`, `registry`, `paths`, `logger`, `rules`, `concurrency`, `tool_filter`.
- `roles` and `skills` are proper config sections; `AIA.config.skills.dir` returns the resolved skills directory.

### Directive System - `lib/aia/directive.rb` and `lib/aia/directives/`
- `AIA::Directive` (base class) inherits from `PM::Directive` and adds AIA-specific concerns.
- `DIRECTIVE_PREFIX = '/'` — all chat directives use a single slash, not `//`.
- The base class provides `parse_search_terms(args)` as a private instance method available to all directive subclasses. It splits args into `[positive_terms, negative_terms]`: bare terms and `+prefix` are positive (AND); `-`, `~`, or `!` prefix marks AND NOT terms.
- Directive subclasses live in `lib/aia/directives/`:
  - `web_and_file_directives.rb` — `/skill`, `/skills`, `/webpage`, `/paste`
  - `model_directives.rb` — `/llms` (and aliases), `/compare`
  - `context_directives.rb`, `execution_directives.rb`, `navigation_directives.rb`, `special_mode_directives.rb`, `config_directives.rb`

### `/skill` and `/skills` Directives - `lib/aia/directives/web_and_file_directives.rb`
- Skills directory resolves via `aia_skills_dir`: `AIA.config.skills.dir` → `$AIA_PROMPTS__DIR/$AIA_PROMPTS__SKILLS_PREFIX` → `~/.prompts/skills`.
- A skill is a subdirectory containing a `SKILL.md` file with YAML front matter (`name`, `description`).
- `/skill <id>` reads and returns the full `SKILL.md` content. On error, prints to stdout and returns `nil` (nothing injected into the AI prompt).
- `/skills [terms...]` prints `skill_id: name\n  description\n\n` to stdout for each matching skill; returns `nil`. Supports AND logic for positive terms and AND NOT for `-`/`~`/`!`-prefixed terms.

### `/llms` Directive - `lib/aia/directives/model_directives.rb`
- `available_models` (aliased as `/llms`, `/models`, etc.) parses args with `parse_search_terms` into `positive_terms` and `negative_terms`.
- Passes both to `show_rubyllm_models(positive_terms, negative_terms)`, `show_ollama_models(api_base, positive_terms, negative_terms)`, and `show_lms_models(api_base, positive_terms, negative_terms)`.
- Negative terms apply AND NOT filtering: models whose entry string contains any negative term are excluded.

### Chat Loop Operation - `lib/aia/chat_loop.rb`
- `AIA::ChatLoop` handles the interactive chat REPL loop.
- Initialize the chat loop with components: `robot`, `ui_presenter`, `directive_processor`.
- Start the chat loop with `ChatLoop#start`, which sets up the session, processes context, and runs the interactive loop.

### Error Handling
- Use `AIA.debug_warn(msg, exc: nil)` to log warnings with optional debug backtrace.
- Catch `AIA::ConfigurationError` and `AIA::Error` in the run method to handle config and general errors gracefully.

### Resetting State
- `AIA.reset!` reinitializes key components, suitable for stateful parts (e.g., `config`, `client`).
