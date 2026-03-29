# AIA CLI Options Audit

Audited against `bin/aia --help` output on 2026-03-28 (v2.0.0.alpha).

## Mode Options

| Flag | Status |
|------|--------|
| `--chat` | IMPLEMENTED |
| `-f, --fuzzy` | IMPLEMENTED |
| `--expert-routing` | IMPLEMENTED — `chat_loop.rb` checks `config.flags.expert_routing`, routes via `ExpertRouter` |
| `--track-pipeline` | IMPLEMENTED — `pipeline_orchestrator.rb` bridges to TrakFlow |
| `--concurrent-auto` | IMPLEMENTED — `pipeline_orchestrator.rb` builds concurrent MCP networks |
| `-A, --tool-filter-kbs` | REMOVED — KBS gem dependency removed; see ADR-010 |
| `-B, --tool-filter-tfidf` | IMPLEMENTED — `ToolFilter::TFIDF` via `tool_filter_registry.rb` |
| `-C, --tool-filter-zvec` | IMPLEMENTED — `ToolFilter::Zvec` via `tool_filter_registry.rb` |
| `-D, --tool-filter-sqlite-vec` | IMPLEMENTED — `ToolFilter::SqliteVec` via `tool_filter_registry.rb` |
| `-E, --tool-filter-lsi` | IMPLEMENTED — `ToolFilter::LSI` via `tool_filter_registry.rb` |
| `--load` | IMPLEMENTED — passed as `load_db:` to `-C/-D/-E` filter constructors |
| `--save` | IMPLEMENTED — passed as `save_db:` to `-C/-D/-E` filter constructors |

## Model Options

| Flag | Status |
|------|--------|
| `--available-models [QUERY]` | IMPLEMENTED |
| `-m, --model MODEL` | IMPLEMENTED |
| `--[no-]consensus` | IMPLEMENTED — controls multi-model consensus in `robot_factory.rb` |
| `--list-roles` | IMPLEMENTED — prints available roles and exits |
| `--sm, --speech-model MODEL` | STUB — stored in config, never read by business logic |
| `--tm, --transcription-model MODEL` | STUB — stored in config, never read by business logic |

## File & Output Options

| Flag | Status |
|------|--------|
| `-c, --config-file FILE` | IMPLEMENTED |
| `-o, --[no-]output [FILE]` | IMPLEMENTED |
| `-a, --[no-]append` | IMPLEMENTED |
| `--[no-]history-file [FILE]` | STUB — declared, but `ui_presenter.rb` uses a hardcoded constant |
| `--md, --[no-]markdown` | IMPLEMENTED |

## Prompt Options

| Flag | Status |
|------|--------|
| `--prompts-dir DIR` | IMPLEMENTED |
| `--roles-prefix PREFIX` | IMPLEMENTED |
| `-r, --role ROLE_ID` | IMPLEMENTED |
| `-n, --next PROMPT_ID` | IMPLEMENTED |
| `-p, --pipeline PROMPTS` | IMPLEMENTED |
| `--system-prompt PROMPT_ID` | IMPLEMENTED — `system_prompt_assembler.rb` reads it |

## Generation Parameters

| Flag | Status |
|------|--------|
| `-t, --temperature TEMP` | IMPLEMENTED |
| `--max-tokens TOKENS` | IMPLEMENTED |
| `--top-p VALUE` | IMPLEMENTED |
| `--frequency-penalty VALUE` | IMPLEMENTED |
| `--presence-penalty VALUE` | IMPLEMENTED |

## Audio & Image Options

| Flag | Status |
|------|--------|
| `--speak` | IMPLEMENTED — `AIA.speak?()` checked in `aia.rb` and `chat_loop.rb` |
| `--voice VOICE` | IMPLEMENTED |
| `--is, --image-size SIZE` | STUB — stored in config, no image generation logic |
| `--iq, --image-quality QUALITY` | STUB — stored in config, no image generation logic |
| `--style, --image-style STYLE` | STUB — stored in config, no image generation logic |

## Tool & Extension Options

| Flag | Status |
|------|--------|
| `--rq, --require LIBS` | IMPLEMENTED |
| `--tools PATH_LIST` | IMPLEMENTED |
| `--at, --allowed-tools TOOLS_LIST` | IMPLEMENTED |
| `--rt, --rejected-tools TOOLS_LIST` | IMPLEMENTED |
| `--list-tools` | IMPLEMENTED |

## Utility Options

| Flag | Status |
|------|--------|
| `--log-level LEVEL` | IMPLEMENTED |
| `-d, --debug` | IMPLEMENTED |
| `--no-debug` | IMPLEMENTED |
| `--log-to FILE` | IMPLEMENTED |
| `-v, --[no-]verbose` | IMPLEMENTED |
| `--refresh DAYS` | IMPLEMENTED |
| `--dump FILE` | IMPLEMENTED — `validator.rb` exports config to YAML and exits |
| `--completion SHELL` | IMPLEMENTED — `validator.rb` outputs shell completion script and exits |
| `--tokens` | IMPLEMENTED — token usage displayed in `chat_loop.rb` and `pipeline_orchestrator.rb` |
| `--cost` | IMPLEMENTED — cost calculations in `ui_presenter.rb`, implies `--tokens` |
| `--mcp FILE` | IMPLEMENTED |
| `--no-mcp` | IMPLEMENTED |
| `--mcp-list` | IMPLEMENTED — `validator.rb` lists configured MCP servers and exits |
| `--mu, --mcp-use NAMES` | IMPLEMENTED |
| `--ms, --mcp-skip NAMES` | IMPLEMENTED |
| `--version` | IMPLEMENTED |
| `-h, --help` | IMPLEMENTED |

## Summary

| Status | Count |
|--------|-------|
| IMPLEMENTED | 42 |
| STUB | 5 |
| REMOVED | 3 |

## Stubs (flags with no business logic)

These flags are parsed and stored in config but never read by any handler:

- `--sm / --speech-model` — awaiting TTS model selection implementation
- `--tm / --transcription-model` — awaiting transcription model selection implementation
- `--history-file` — `ui_presenter.rb` uses a hardcoded constant instead of this config value
- `--is / --image-size` — image generation not implemented
- `--iq / --image-quality` — image generation not implemented
- `--style / --image-style` — image generation not implemented

## Removed (2026-03-28)

These deprecated flags were removed from the codebase entirely:

- `--terse` — was a no-op warning; removed from `cli_parser.rb`, `utility_directives.rb`, and tests
- `--regex` — was a no-op warning; removed from `cli_parser.rb`, `validator.rb`, and tests
- `-A, --tool-filter-kbs` — KBS gem removed entirely (ADR-010); use `-B` TF-IDF filtering instead
