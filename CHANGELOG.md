# Changelog
## [0.10.1] - 2025-12-24

### New Features
- **Parallel MCP Connections**: Replaced serial MCP server connections with fiber-based parallel execution using SimpleFlow
  - MCP servers now connect concurrently instead of sequentially
  - Total connection time reduced from sum(timeouts) to max(timeouts)
  - Added `simple_flow` gem dependency for lightweight pipeline-based concurrency

### Improvements
- **MCP Failure Feedback**: Added per-server error messages when MCP connections fail
  - Users now see which specific server failed and why (e.g., "⚠️  MCP: 'iMCP' failed - Connection timed out")
  - Previously only showed generic timeout message without identifying the failing server

### Bug Fixes
- **Ruby 4.0 Compatibility**: Fixed `NameError` in `lib/extensions/ruby_llm/modalities.rb`
  - Added `require 'ruby_llm'` before extending `RubyLLM::Model::Modalities`
  - Resolves "uninitialized constant RubyLLM" error on Ruby 4.0.0-preview2

### Technical Changes
- Added `simple_flow` gem dependency to gemspec
- Refactored MCP connection code in `lib/aia/ruby_llm_adapter.rb`:
  - Added `support_mcp_with_simple_flow` method using SimpleFlow::Pipeline
  - Added `build_mcp_connection_step`, `register_single_mcp_client`, `extract_mcp_results`, `report_mcp_connection_results` helper methods
  - Removed old serial methods: `support_mcp_lazy`, `register_mcp_clients`, `start_mcp_clients`, `reconcile_mcp_server_status`, `check_mcp_client_status`
  - Net reduction of ~60 lines of code with cleaner architecture

## [0.10.0] - 2025-12-23

### Breaking Changes
- **Environment Variable Naming Convention**: Updated to use nested naming with double underscore (`__`)
  - `AIA_PROMPTS_DIR` → `AIA_PROMPTS__DIR`
  - `AIA_OUT_FILE` → `AIA_OUTPUT__FILE`
  - `AIA_VERBOSE` → `AIA_FLAGS__VERBOSE`
  - `AIA_DEBUG` → `AIA_FLAGS__DEBUG`
  - `AIA_CHAT` → `AIA_FLAGS__CHAT`
  - `AIA_TEMPERATURE` → `AIA_LLM__TEMPERATURE`
  - `AIA_MARKDOWN` → `AIA_OUTPUT__MARKDOWN`
  - Note: `AIA_MODEL` remains unchanged (top-level, not nested)

### Bug Fixes
- **MCP Tool Timeout Handling**: Fixed issue where MCP tool timeouts corrupted conversation history
  - Added `repair_incomplete_tool_calls` method to add synthetic tool results when timeouts occur
  - Prevents "assistant message with 'tool_calls' must be followed by tool messages" API errors
  - Conversation can now continue gracefully after tool timeouts

- **Tool Crash Handling**: Fixed crash when tools throw non-StandardError exceptions (e.g., LoadError)
  - Changed `rescue StandardError` to `rescue Exception` to catch all error types
  - Added `handle_tool_crash` method that logs errors with 5-line traceback
  - Tool crashes no longer crash AIA - conversation continues gracefully

## [0.9.24] 2025-12-17
### Fixes
- Ran into a problem with the `shared_tools` gem and the --require parameter of AIA which required changes to both gems.

### Improvements
- **`//tools` Directive Filter**: Added optional filter parameter to the `//tools` directive
  - Filter tools by name substring (case-insensitive)
  - Example: `//tools error` lists only tools with "error" in the name
  - Shows "No tools match the filter: [filter]" when no matches found
  - Header indicates when filtering is active: "Available Tools (filtered by 'filter')"

### Documentation
- Updated all shell completion scripts (`aia_completion.bash`, `aia_completion.zsh`, `aia_completion.fish`) to use new nested naming convention
- Updated `docs/configuration.md` with comprehensive environment variable documentation
- Updated `docs/cli-reference.md` environment variables section
- Updated `docs/prompt_management.md` with correct envar names
- Updated `docs/faq.md` with correct envar names
- Updated `docs/guides/basic-usage.md` shell setup examples

### Technical Changes
- Enhanced `lib/aia/ruby_llm_adapter.rb`:
  - Added `repair_incomplete_tool_calls` method for conversation integrity
  - Added `handle_tool_crash` method for graceful error handling
  - Removed debug statements

## [0.9.23] 2025-12-06

### New Features
- **MCP Server Configuration**: Added native support for defining MCP (Model Context Protocol) servers in the config file
  - Configure MCP servers in `~/.aia/config.yml` under the `mcp_servers` key
  - Supports `name`, `command`, `args`, `env`, and `timeout` options per server
  - Automatic PATH resolution for commands (no absolute paths required)
  - Configurable timeouts for slow-starting servers (default: 8000ms)
  - Environment variable support for MCP server processes

### Improvements
- **Robot Display**: Added MCP server names to the robot ASCII art display
  - Shows "MCP: server1, server2, ..." when MCP servers are configured

### Technical Changes
- Added `load_mcp_servers` method to `lib/aia/config/base.rb` for automatic MCP client registration
- Added `resolve_command_path` method for PATH-based command resolution
- Added `mcp_servers?` and `mcp_server_names` helper methods to `lib/aia/utility.rb`
- Fixed `OpenStruct.merge` to skip nil values, preventing config file values from being overwritten
- Added `mcp_servers: nil` default to prevent merge issues with empty arrays

### Configuration Example
```yaml
# ~/.aia/config.yml
:mcp_servers:
  - name: "my-server"
    command: "my_mcp_server.rb"
    args: ["stdio"]
    timeout: 30000
    env:
      MY_VAR: "value"
```

## [0.9.22] 2025-11-12

### Bug Fixes
- **TEST SUITE**: Fixed all Mocha test isolation issues causing stub contamination between tests
  - Added proper teardown methods with `super` calls to 13 test files to ensure Mocha cleanup
  - Fixed PromptHandlerTest missing teardown and config fields (erb, shell, roles_dir)
  - Fixed ModelsDirectiveTest to use consistent stubbing approach instead of mixing real and stubbed config
  - Fixed MultiModelIsolationTest to use stubs instead of direct instance variable manipulation
  - Fixed AIAIntegrationTest, ChatProcessorServiceTest, ContextManagerTest, DirectiveProcessorTest, RubyLLMAdapterTest, SessionTest, LocalProvidersTest, UtilityTest, AIAMockingTest, and AIAPropertyBasedTest to include proper Mocha cleanup
  - Test results improved from 2 failures, 2 errors to 0 failures, 0 errors (325 runs, 1018 assertions)

### Technical Changes
- Enhanced test isolation by ensuring all tests using Mocha stubs properly clean up via `super` in teardown
- Standardized stub usage pattern across test suite for consistency
- Eliminated stub leakage that caused "unexpected invocation" and "AIA was instantiated in one test but receiving invocations in another" errors

## [0.9.21] 2025-10-08
### Bug Fixes
- **Checkpoint Directive Output**: Fixed `//checkpoint` directive to return empty string instead of status message (lib/aia/directives/configuration.rb:155)
  - Prevents checkpoint creation messages from entering AI context
  - Outputs confirmation to STDOUT instead for user feedback
  - Prevents potential AI manipulation of checkpoint system

## [0.9.20] 2025-10-06
### Added
- **Enhanced Multi-Model Role System (ADR-005)**: Implemented per-model role assignment with inline syntax
  - New inline syntax: `--model MODEL[=ROLE][,MODEL[=ROLE]]...`
  - Example: `aia --model gpt-4o=architect,claude=security,gemini=performance design_doc.md`
  - Support for duplicate models with different roles: `gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist`
  - Added `--list-roles` command to discover available role files
  - Display format shows instance numbers and roles: `gpt-4o #1 (optimist):`, `gpt-4o #2 (pessimist):`
  - Consensus mode drops role for neutral synthesis
  - Chat mode roles are immutable during session
  - Nested role path support: `--model gpt-4o=specialized/architect`
  - Full backward compatibility with existing `--role` flag

- **Config File Model Roles Support (ADR-005 v2)**:
  - Enhanced `model` key in config files to support array of hashes with roles
  - Format: `model: [{model: gpt-4o, role: architect}, {model: claude, role: security}]`
  - Mirrors internal data structure (array of hashes with `model`, `role`, `instance`, `internal_id`)
  - Supports models without roles: `model: [{model: gpt-4o}]`
  - Enables reusable model-role setups across sessions
  - Configuration precedence: CLI inline > CLI flag > Environment variable > Config file

- **Environment Variable Inline Syntax (ADR-005 v2)**:
  - Added support for inline role syntax in `AIA_MODEL` environment variable
  - Example: `export AIA_MODEL="gpt-4o=architect,claude=security,gemini=performance"`
  - Maintains backward compatibility with simple comma-separated model lists
  - Detects `=` to distinguish between formats

### Bug Fixes
- **Multi-Model Chat Cross-Talk**: Fixed bug where model instances with different roles could see each other's conversation history
  - Updated Session to properly extract `internal_id` from hash-based model specs (lib/aia/session.rb:47-68)
  - Fixed `parse_multi_model_response` to normalize display names to internal IDs (lib/aia/session.rb:538-570)
  - Each model instance now maintains completely isolated conversation context
  - Fixes issue where models would respond as if aware of other models' perspectives

### Improvements
- **Robot ASCII Display**: Updated `robot` method to extract and display only model names from new hash format (lib/aia/utility.rb:24-53)
  - Handles string, array of strings, and array of hashes formats
  - Shows clean model list: "gpt-4o, claude, gemini" instead of hash objects

### Testing
- Added comprehensive test suite for config file and environment variable model roles
  - test/aia/config_model_roles_test.rb: 8 tests covering array processing, env var parsing, YAML config files
- Added 15 tests for role parsing with inline syntax (test/aia/role_parsing_test.rb)
- Fixed Mocha test cleanup in multi_model_isolation_test.rb
- Full test suite: 306 runs, 980 assertions, 0 failures (1 pre-existing Mocha isolation issue)

### Technical Implementation
- Modified `config.model` to support array of hashes with model metadata: `{model:, role:, instance:, internal_id:}`
- Added `parse_models_with_roles` method with fail-fast validation (lib/aia/config/cli_parser.rb)
- Added `validate_role_exists` with helpful error messages showing available roles
- Added `list_available_roles` and `list_available_role_names` methods for role discovery
- Added `load_role_for_model` method to PromptHandler for per-model role loading (lib/aia/prompt_handler.rb)
- Enhanced RubyLLMAdapter to handle hash-based model specs and prepend roles per model
  - Added `extract_model_names` to extract model names from specs
  - Added `get_model_spec` to retrieve full spec by internal_id
  - Added `prepend_model_role` to inject role content into prompts
  - Added `format_model_display_name` for consistent display formatting
- Updated Session initialization to handle hash-based model specs for context managers
- Updated display formatting to show instance numbers and roles
- Maintained backward compatibility with string/array model configurations
- Added `process_model_array_with_roles` method in FileLoader (lib/aia/config/file_loader.rb:91-116)
- Enhanced `apply_file_config_to_struct` to detect and process model arrays with role hashes
- Enhanced `envar_options` to parse inline syntax for `:model` key (lib/aia/config/base.rb:212-217)

## [0.9.19] 2025-10-06

### Bug Fixes
- **CRITICAL BUG FIX**: Fixed multi-model cross-talk issue (#118) where models could see each other's conversation history
- **BUG FIX**: Implemented complete two-level context isolation to prevent models from contaminating each other's responses
- **BUG FIX**: Fixed token count inflation caused by models processing combined conversation histories

### Technical Changes
- **Level 1 (Library)**: Implemented per-model RubyLLM::Context isolation - each model now has its own Context instance (lib/aia/ruby_llm_adapter.rb)
- **Level 2 (Application)**: Implemented per-model ContextManager isolation - each model maintains its own conversation history (lib/aia/session.rb)
- Added `parse_multi_model_response` method to extract individual model responses from combined output (lib/aia/session.rb:502-533)
- Enhanced `multi_model_chat` to accept Hash of per-model conversations (lib/aia/ruby_llm_adapter.rb:305-334)
- Updated ChatProcessorService to handle both Array (single model) and Hash (multi-model with per-model contexts) inputs (lib/aia/chat_processor_service.rb:68-83)
- Refactored RubyLLMAdapter:
  - Added `@contexts` hash to store per-model Context instances
  - Added `create_isolated_context_for_model` helper method (lines 84-99)
  - Added `extract_model_and_provider` helper method (lines 102-112)
  - Simplified `clear_context` from 92 lines to 40 lines (56% reduction)
- Updated directive handlers to work with per-model context managers
- Added comprehensive test coverage with 6 new tests for multi-model isolation
- Updated LocalProvidersTest to reflect Context-based architecture

### Architecture
- **ADR-002-revised**: Complete Multi-Model Isolation (see `.architecture/decisions/adrs/ADR-002-revised-multi-model-isolation.md`)
- Eliminated global state dependencies in multi-model chat sessions
- Maintained backward compatibility with single-model mode (verified with tests)

### Test Coverage
- Added `test/aia/multi_model_isolation_test.rb` with comprehensive isolation tests
- Tests cover: response parsing, per-model context managers, single-model compatibility, RubyLLM::Context isolation
- Full test suite: 282 runs, 837 assertions, 0 failures, 0 errors, 13 skips ✅

### Expected Behavior After Fix
Previously, when running multi-model chat with repeated prompts:
- ❌ Models would see BOTH their own AND other models' responses
- ❌ Models would report inflated counts (e.g., "5 times", "6 times" instead of "3 times")
- ❌ Token counts would be inflated due to contaminated context

Now with the fix:
- ✅ Each model sees ONLY its own conversation history
- ✅ Each model correctly reports its own interaction count
- ✅ Token counts accurately reflect per-model conversation size

### Usage Examples
```bash
# Multi-model chat now properly isolates each model's context
bin/aia --chat --model lms/openai/gpt-oss-20b,ollama/gpt-oss:20b --tokens

> pick a random language and say hello
# LMS: "Habari!" (Swahili)
# Ollama: "Kaixo!" (Basque)

> do it again
# LMS: "Habari!" (only sees its own previous response)
# Ollama: "Kaixo!" (only sees its own previous response)

> do it again
> how many times did you say hello to me?

# Both models correctly respond: "3 times"
# (Previously: LMS would say "5 times", Ollama "6 times" due to cross-talk)
```

## [0.9.18] 2025-10-05

### Bug Fixes
- **BUG FIX**: Fixed RubyLLM provider error parsing to handle both OpenAI and LM Studio error formats
- **BUG FIX**: Fixed "String does not have #dig method" errors when parsing error responses from local providers
- **BUG FIX**: Enhanced error parsing to gracefully handle malformed JSON responses

### Improvements
- **ENHANCEMENT**: Removed debug output statements from RubyLLMAdapter for cleaner production logs
- **ENHANCEMENT**: Improved error handling with debug logging for JSON parsing failures

### Documentation
- **DOCUMENTATION**: Added Local Models entry to MkDocs navigation for better documentation accessibility

### Technical Changes
- Enhanced provider_fix extension to support multiple error response formats (lib/extensions/ruby_llm/provider_fix.rb)
- Cleaned up debug puts statements from RubyLLMAdapter and provider_fix
- Added robust JSON parsing with fallback error handling

## [0.9.17] 2025-10-04

### New Features
- **NEW FEATURE**: Enhanced local model support with comprehensive validation and error handling
- **NEW FEATURE**: Added `lms/` prefix support for LM Studio models with automatic validation against loaded models
- **NEW FEATURE**: Enhanced `//models` directive to auto-detect and display local providers (Ollama and LM Studio)
- **NEW FEATURE**: Added model name prefix display in error messages for LM Studio (`lms/` prefix)

### Improvements
- **ENHANCEMENT**: Improved LM Studio integration with model validation against `/v1/models` endpoint
- **ENHANCEMENT**: Enhanced error messages showing exact model names with correct prefixes when validation fails
- **ENHANCEMENT**: Added environment variable support for custom LM Studio API base (`LMS_API_BASE`)
- **ENHANCEMENT**: Improved `//models` directive output formatting for local models with size and modified date for Ollama
- **ENHANCEMENT**: Enhanced multi-model support to seamlessly mix local and cloud models

### Documentation
- **DOCUMENTATION**: Added comprehensive local model documentation to README.md
- **DOCUMENTATION**: Created new docs/guides/local-models.md guide covering Ollama and LM Studio setup, usage, and troubleshooting
- **DOCUMENTATION**: Updated docs/guides/models.md with local provider sections including comparison table and workflow examples
- **DOCUMENTATION**: Enhanced docs/faq.md with 5 new FAQ entries covering local model usage, differences, and error handling

### Technical Changes
- Enhanced RubyLLMAdapter with LM Studio model validation (lib/aia/ruby_llm_adapter.rb)
- Updated models directive to query local provider endpoints (lib/aia/directives/models.rb)
- Added provider_fix extension for RubyLLM compatibility (lib/extensions/ruby_llm/provider_fix.rb)
- Added comprehensive test coverage with 22 new tests for local providers
- Updated dependencies: ruby_llm, webmock, crack, rexml
- Bumped Ruby bundler version to 2.7.2

### Bug Fixes
- **BUG FIX**: Fixed missing `lms/` prefix in LM Studio model listings
- **BUG FIX**: Fixed model validation error messages to show usable model names with correct prefixes
- **BUG FIX**: Fixed Ollama endpoint to use native API (removed incorrect `/v1` suffix)

### Usage Examples
```bash
# Use LM Studio with validation
aia --model lms/qwen/qwen3-coder-30b my_prompt

# Use Ollama
aia --model ollama/llama3.2 --chat

# Mix local and cloud models
aia --model ollama/llama3.2,gpt-4o-mini,claude-3-sonnet my_prompt

# List available local models
aia --model ollama/llama3.2 --chat
> //models
```

## [0.9.16] 2025-09-26

### New Features
- **NEW FEATURE**: Added support for Ollama AI provider
- **NEW FEATURE**: Added support for Osaurus AI provider
- **NEW FEATURE**: Added support for LM Studio AI provider

### Improvements
- **ENHANCEMENT**: Expanded AI provider ecosystem with three new local/self-hosted model options
- **ENHANCEMENT**: Improved flexibility for users preferring local LLM deployments

## [0.9.15] 2025-09-21

### New Features
- **NEW FEATURE**: Added `//paste` directive to insert clipboard contents into prompts
- **NEW FEATURE**: Added `//clipboard` alias for the paste directive

### Technical Changes
- Enhanced DirectiveProcessor with clipboard integration using the clipboard gem
- Added comprehensive test coverage for paste directive functionality

## [0.9.14] 2025-09-19

### New Features
- **NEW FEATURE**: Added `//checkpoint` directive to create named snapshots of conversation context
- **NEW FEATURE**: Added `//restore` directive to restore context to a previous checkpoint
- **NEW FEATURE**: Enhanced `//context` (and `//review`) directive to display checkpoint markers in conversation history
- **NEW FEATURE**: Added `//cp` alias for checkpoint directive

### Improvements
- **ENHANCEMENT**: Context manager now tracks checkpoint positions for better context visualization
- **ENHANCEMENT**: Checkpoint system uses auto-incrementing integer names when no name is provided
- **ENHANCEMENT**: Restore directive defaults to last checkpoint when no name specified
- **ENHANCEMENT**: Clear context now also clears all checkpoints

### Bug Fixes
- **BUG FIX**: Fixed `//help` directive that was showing empty list of directives
- **BUG FIX**: Help directive now displays all directives from all registered modules
- **BUG FIX**: Help directive now shows proper descriptions and aliases for all directives
- **BUG FIX**: Help directive organizes directives by category for better readability

### Technical Changes
- Enhanced ContextManager with checkpoint storage and restoration capabilities
- Added checkpoint_positions method to track checkpoint locations in context
- Refactored help directive to collect directives from all registered modules
- Added comprehensive test coverage for checkpoint and restore functionality

## [0.9.13] 2025-09-02
### New Features
- **NEW FEATURE**: Added `--tokens` flag to show token counts for each model
- **NEW FEATURE**: Added `--cost` flag to enable cost estimation for each model

### Improvements
- **DEPENDENCY**: Removed versionaire dependency, simplifying version management
- **ENHANCEMENT**: Improved test suite reliability and coverage
- **ENHANCEMENT**: Updated Gemfile.lock with latest dependency versions

### Bug Fixes
- **BUG FIX**: Fixed version handling issues by removing external versioning dependency

### Technical Changes
- Simplified version management by removing versionaire gem
- Enhanced test suite with improved assertions and coverage
- Updated various gem dependencies to latest stable versions

## [0.9.12] 2025-08-28

### New Features
- **MAJOR NEW FEATURE**: Multi-model support - specify multiple AI models simultaneously with comma-separated syntax
- **NEW FEATURE**: `--consensus` flag to enable primary model consensus mode for synthesized responses from multiple models
- **NEW FEATURE**: `--no-consensus` flag to explicitly force individual responses from all models
- **NEW FEATURE**: Enhanced `//model` directive now shows comprehensive multi-model configuration details
- **NEW FEATURE**: Concurrent processing of multiple models for improved performance
- **NEW FEATURE**: Primary model concept - first model in list serves as consensus orchestrator
- **NEW FEATURE**: Multi-model error handling - invalid models reported but don't prevent valid models from working
- **NEW FEATURE**: Multi-model support in both batch and interactive chat modes
- **NEW FEATURE**: Comprehensive documentation website https://madbomber.github.io/aia/

### Improvements
- **ENHANCEMENT**: Enhanced `//model` directive output with detailed multi-model configuration display
- **ENHANCEMENT**: Improved error handling with graceful fallback when model initialization fails
- **ENHANCEMENT**: Better TTY handling in chat mode to prevent `Errno::ENXIO` errors in containerized environments
- **ENHANCEMENT**: Updated directive processor to use new module-based architecture for better maintainability
- **ENHANCEMENT**: Improved batch mode output file formatting consistency between STDOUT and file output

### Bug Fixes
- **BUG FIX**: Fixed DirectiveProcessor TypeError that prevented application startup with invalid directive calls
- **BUG FIX**: Fixed missing primary model output in batch mode output files
- **BUG FIX**: Fixed inconsistent formatting between STDOUT and file output in batch mode
- **BUG FIX**: Fixed TTY availability issues in chat mode for containerized environments
- **BUG FIX**: Fixed directive processing to use updated module-based registry system

### Technical Changes
- Fixed ruby_llm version to 1.5.1
- Added extra API_KEY configuration for new LLM providers
- Updated RubyLLMAdapter to support multiple model initialization and management
- Enhanced ChatProcessorService output handling for multi-model responses
- Improved Session class TTY error handling with proper exception catching
- Updated CLI parser to support multi-model flags and options
- Enhanced configuration system to support consensus mode settings

### Documentation
- **DOCUMENTATION**: Comprehensive README.md updates with multi-model usage examples and best practices
- **DOCUMENTATION**: Added multi-model section to README with detailed usage instructions
- **DOCUMENTATION**: Updated command-line options table with new multi-model flags
- **DOCUMENTATION**: Added practical multi-model examples for decision-making scenarios

### Usage Examples
```bash
# Basic multi-model usage
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo

# Enable consensus mode for synthesized response
aia my_prompt -m gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini --consensus

# Multi-model chat mode
aia --chat -m gpt-4o-mini,gpt-3.5-turbo

# View current multi-model configuration
//model  # Use in any prompt or chat session
```

### Migration Notes
- Existing single-model usage remains unchanged and fully compatible
- Multi-model is opt-in via comma-separated model names
- Default behavior without `--consensus` flag shows individual responses from all models
- Invalid model names are reported but don't prevent valid models from working

### TODO
- TODO: focus on log file consistency using Logger


## [0.9.11] 2025-07-31
- added a cost per 1 million input tokens to available_models query output
- updated ruby_llm to version 1.4.0
- updated all other gem dependencies to their latest versions

## [0.9.10] 2025-07-18
- updated ruby_llm-mcp to version 0.6.1 which solves problems with MCP tools not being installed

## [0.9.9] 2025-07-10
- refactored the Session and Config classes into more testable method_missing
- updated the test suire for both the Session and Config classes
- added support for MCP servers coming into AIA via the shared_tools gem
- added +RubyLLM::MCP.support_complex_parameters! to patch ruby_llm gem until such time as it supports the more complex optional parameters in tool calls
- added an examples/tools/mcp directory with 2 MCP client definitions
- updated to ruby_llm-mcp gem version 0.5.1
- //model directive now dumps full model details
- //available_models now has context window size and capabilities for each model returned


## [0.9.8] 2025-06-25
- fixing an issue with pipelined prompts
- now showing the complete modality of the model on the processing line.
- changed -p option from prompts_dir to pipeline
- found problem with simple cov and deep cov w/r/t their reported test coverage; they have problems with heredoc and complex conditionals.

## [0.9.7] 2025-06-20

- **NEW FEATURE**: Added `--available_models` CLI option to list all available AI models
- **NEW FEATURE**: Added `//tools` to show a list of available tools and their description
- **BUG FIX**: Fixed SharedTools compatibility issue with models that don't support function calling
- **BUG FIX**: Fixed problem with piped text through STDIN not being handled correctly.
- **BUG FIX**: Fixed issue with output going to the default out_file evenhen --no-out_file is specified.
- **BUG FIX**: Fixed issue with executable prompt files by adding the --exec option
- **DOCUMENTATION**: Updated README for better clarity and structure
- **DEPENDENCY**: Updated Gemfile.lock with latest dependency versions

## [0.9.6] 2025-06-13
- fixed issue 84 with the //llms directive
- changed the monkey patch to the RubyLLM::Model::Modalities class at the suggestions of the RubyLLM author in prep for a PR against that gem.
- added the shared_tools gem - need to add examples on how to use it with the --tools option
- added the ruby_llm-mcp gem in prep for MCP support in a later version
- added images/aia.png to README.md
- let claude code rewrite the README.md file.  Some details were dropped but overall in reads better.  Need to add the details to a wiki or other documentation site.

## [0.9.5] 2025-06-04
- changed the RubyLLM::Modalities class to use method_missing for mode query
- hunting for why the //llms query directive is not finding image_to_image LLMs.

## [0.9.4] 2025-06-03
- using RubyLLM v1.3.0
- setting up a docs infrastructure to behave like the ruby_llm gem's guides side
- fixed bug in the text-to-image workflow
- discovered that ruby_llm does not have high level support for audio modes
- need to pay attention to the test suite
- also need to ensure the non text2text modes are working

## [0.9.3rc1] 2025-05-24
- using ruby_llm v1.3.0rc1
- added a models database refresh based on integer days interval with the --refresh option
- config file now has a "last_refresh" String in format YYYY-MM-DD
- enhanced the robot figure to show more config items including tools
- fixed bug with the --require option with the specified libraries were not being loaded.
- fixed a bug in the prompt_manager gem which is now at v0.5.5


## [0.9.2] 2025-05-18
- removing the MCP experiment
- adding support for RubyLLM::Tool usage in place of the MCP stuff
- updated prompt_manager to v0.5.4 which fixed shell integration problem

## [0.9.1] 2025-05-16
- rethink MCP approach in favor of just RubyLLM::Tool
- fixed problem with //clear
- fixed a problem with a priming prompt in a chat loop

## [0.9.0] 2025-05-13
- Adding experimental MCP Client suppot
- removed the CLI options --erb and --shell but kept them in the config file with a default of true for both

## [0.8.6] 2025-04-23
- Added a client adapter for the ruby_llm gem
- Added the adapter config item and the --adapter option to select at runtime which client to use ai_client or ruby_llm

## [0.8.5] 2025-04-19
- documentation updates
- integrated the https://pure.md web service for inserting web pages into the context window
   - //include http?://example.com/stuff
   - //webpage http?://example.com/stuff

## [0.8.2] 2025-04-18
- fixed problems with pre-loaded context and chat repl
- piped content into `aia --chat` is now a part of the context/instructions
- content via "aia --chat < some_file" is added to the context/instructions
- `aia --chat context_file.txt context_file2.txt` now works
- `aia --chat prompt_id context)file.txt` also works

## [0.8.1] 2025-04-17
- bumped version to 0.8.1 after correcting merge conflicts

## [0.8.0] WIP - 2025-04-15
- Updated PromptManager to v0.5.1 which has some of the functionality that was originally developed in the AIA.
- Enhanced README.md to include a comprehensive table of configuration options with defaults and associated environment variables.
- Added a note in README.md about the expandability of configuration options from a config file for dynamic prompt generation.
- Improved shell command protection by ensuring dangerous patterns are checked and confirmed before execution.
- Ensured version consistency across `.version`, `aia.gemspec`, and `lib/aia/version.rb`.
- Verified and updated documentation to ensure readiness for release on RubyGems.org.

## [0.7.1] WIP - 2025-03-22
- Added `UIPresenter` class for handling user interface presentation.
- Added `DirectiveProcessor` class for processing chat-based directives.
- Added `HistoryManager` class for managing conversation and variable history.
- Added `ShellCommandExecutor` class for executing shell commands.
- Added `ChatProcessorService` class for managing conversation processing logic.
- Added `PromptProcessor` class for processing prompts.
- Enhanced `Session` class to manage interactive session logic.
- Updated `Config` class to handle new configuration options and defaults.
- Improved handling of chat prompts and AI interactions.
- Added support for dynamic content processing in prompts, including shell commands and ERB.
- Improved error handling and user feedback for directive processing.
- Enhanced logging and output options for chat sessions.

## [0.7.0] WIP - 2025-03-17
- Major code refactoring for better organization and maintainability:
  - Extracted `DirectiveProcessor` class to handle chat-based directives
  - Extracted `HistoryManager` class for conversation and variable history management
  - Extracted `UIPresenter` class for UI-related functionality
  - Extracted `ChatProcessorService` class for prompt processing and AI interactions
  - Significantly reduced complexity of the `Session` class by applying separation of concerns
- Enhanced the `//clear` directive to properly reset conversation context
- Improved output handling to suppress STDOUT when chat mode is off and output file is specified
- Updated spinner format in the process_prompt method for better user experience

## [0.6.?] WIP
- Implemented Tony Stark's Clean Slate Protocol on the develop branch

## [0.5.17] 2024-05-17
- removed replaced `semver` with `versionaire`

## [0.5.16] 2024-04-02
- fixed prompt pipelines
- added //next and //pipeline directives as shortcuts to //config [next,pipeline]
- Added new backend "client" as an internal OpenAI client
- Added --sm, --speech_model default: tts-1
- Added --tm, --transcription_model default: whisper-1
- Added --voice default: alloy (if "siri" and Mac? then uses cli tool "say")
- Added --image_size and --image_quality (--is --iq)

## [0.5.15] 2024-03-30
- Added the ability to accept piped in text to be appeded to the end of the prompt text: curl $URL | aia ad_hoc
- Fixed bugs with entering directives as follow-up prompts during a chat session

## [0.5.14] 2024-03-09
- Directly access OpenAI to do text to speech when using the `--speak` option
- Added --voice to specify which voice to use
- Added --speech_model to specify which TTS model to use

## [0.5.13] 2024-03-03
- Added CLI-utility `llm` as a backend processor

## [0.5.12] 2024-02-24
- Happy Birthday Ruby!
- Added --next CLI option
- Added --pipeline CLI option

## [0.5.11] 2024-02-18
- allow directives to return information that is inserted into the prompt text
- added //shell command directive
- added //ruby ruby_code directive
- added //include path_to_file directive

## [0.5.10] 2024-02-03
- Added --roles_dir to isolate roles from other prompts if desired
- Changed --prompts to --prompts_dir to be consistent
- Refactored common fzf usage into its own tool class

## [0.5.9] 2024-02-01
- Added a "I'm working" spinner thing when "--verbose" is used as an indication that the backend is in the process of composing its response to the prompt.

## [0.5.8] 2024-01-17
- Changed the behavior of the --dump option.  It must now be followed by path/to/file.ext where ext is a supported config file format: yml, yaml, toml

## [0.5.7] 2024-01-15
- Added ERB processing to the config_file

## [0.5.6] 2024-01-15
- Adding processing for directives, shell integration and erb to the follow up prompt in a chat session
- some code refactoring.

## [0.5.3] 2024-01-14
- adding ability to render markdown to the terminal using the "glow" CLI utility

## [0.5.2] 2024-01-13
- wrap response when its going to the terminal

## [0.5.1] 2024-01-12
- removed a wicked puts "loaded" statement
- fixed missed code when the options were changed to --out_file and --log_file
- fixed completion functions by updating $PROMPT_DIR to $AIA_PROMPTS_DIR to match the documentation.

## [0.5.0] 2024-01-05
- breaking changes:
    - changed `--config` to `--config_file`
    - changed `--env` to `--shell`
    - changed `--output` to `--out_file`
        - changed default `out_file` to `STDOUT`

## [0.4.3] 2023-12-31
- added --env to process embedded system environment variables and shell commands within a prompt.
- added --erb to process Embedded RuBy within a prompt because have embedded shell commands will only get you in a trouble.  Having ERB will really get you into trouble.  Remember the simple prompt is usually the best prompt.

## [0.4.2] 2023-12-31
- added the --role CLI option to pre-pend a "role" prompt to the front of a primary prompt.

## [0.4.1] 2023-12-31
- added a chat mode
- prompt directives now supported
- version bumped to match the `prompt_manager` gem

## [0.3.20] 2023-12-28
- added work around to issue with multiple context files going to the `mods` backend
- added shellwords gem to santize prompt text on the command line

## [0.3.19] 2023-12-26
- major code refactoring.
- supports config files \*.yml, \*.yaml and \*.toml
- usage implemented as a man page. --help will display the man page/
- added "--dump <yml|yaml|toml>" to send current configuration to STDOUT
- added "--completion <bash|fish|zsh>" to send a a completion function for the indicated shell to STDOUT
- added system environment variable (envar) over-rides of default config values uppercase environment variables prefixed with "AIA_" + config item name for example AIA_PROMPTS_DIR and AIA_MODEL.  All config items can be over-ridden by their cooresponding envars.
- config value hierarchy is:
    1. values from config file  over-rides ...
    2. command line values      over-rides ...
    3. envar values             over-rides ...
    4. default values

## [0.3.0] = 2023-11-23

- Matching version to [prompt_manager](https://github.com/prompt_manager) This version allows for the user of history in the entery of values to prompt keywords.  KW_HISTORY_MAX is set at 5.  Changed CLI enteraction to use historical selection and editing of prior keyword values.

## [0.1.0] - 2023-11-23

- Initial release
