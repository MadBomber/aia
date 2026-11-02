# Comprehensive Architecture Review — AIA v2.0.0
## Date: 2026-03-27
## Scope: Full codebase (69 Ruby source files, ~10K LOC)
## Method: Six parallel specialist reviewers — Core, KBS/Rules, MCP/Tools, Chat/Directives, Handlers/Network, Infrastructure

---

## 1. Overall Assessment

AIA v2.0.0 demonstrates thoughtful feature design and strong domain separation at the module level. The `robot_lab` + `kbs` adoption was the right call. The codebase is functionally correct and feature-rich.

The structural problems are at the **integration layer**: global state abuse, god-objects, missing handler protocol, silent error swallowing, and no dependency injection. These compound over time and make the codebase increasingly expensive to change.

---

## 2. Structural Strengths

- **Stateless extracted modules.** `FactAsserter`, `ToolLoader`, `SystemPromptAssembler`, `KBDefinitions`, `DynamicRuleBuilder` are all stateless with injected dependencies.
- **Good domain decomposition.** Most concerns are in the right file even if the files themselves are too large.
- **`RobotNamer`**, **`ModelAliasRegistry`**, **`PromptDecomposer`**, **`SimilarityScorer`** are exemplary — single responsibility, no external coupling, testable.
- **MCPConnectionManager connection logic** — the `connect_one`/threads/spinners architecture is solid; only reads are unsafe.
- **LoggerManager test mode** — proper test device injection shows good instincts.

---

## 3. Critical Issues (Fix Before Production)

### C1. Thread Safety — MCPConnectionManager Reads Without Mutex
**`mcp_connection_manager.rb:72-83`**

`inject_into()` reads `@connected_clients` and `@connected_tools` without acquiring `@mutex`. Threads writing in `connect_one()` race with the main thread reading in `inject_into()`. Robots can start with missing MCP tools.

**Fix:** Wrap all reads in `@mutex.synchronize` or snapshot state under lock before use.

### C2. No `AIA.reset!` — Tests Leak State
**`aia.rb:77-88`**

Six mutable class-level singletons (`config`, `client`, `session_tracker`, `turn_state`, `task_coordinator`, `decisions`, `rule_router`) with no reset mechanism. Tests must manually nil each one; forgetting one causes cross-test state leakage. Running tests in parallel is unsafe.

**Fix:** Add `AIA.reset!` that zeros all accessors. Call in every test teardown.

### C3. Decisions Schema Accepts nil Values
**`decisions.rb:22-30`**

`decisions.add(:model_decision, model: nil)` is accepted silently. Downstream callers do `decisions.model_decisions.first&.dig(:model)` and pass `nil` to `RobotLab.build(model: nil)` — crash with no indication of source.

**Fix:** Validate required keys in `add()`. Assert `:model` is non-nil for model decisions.

### C4. DecisionApplier Silent Fall-Through
**`decision_applier.rb:100-116`**

If `build_temp_robot` returns nil, the turn proceeds with the original robot and `context.model_overridden` is never set. User gets no feedback that the KBS recommendation was ignored.

### C5. Silent KBS Pipeline Failure
**`rule_router.rb:84-105`**

Missing KBs are skipped with `next unless kb` — no warning. If `:classify` is absent, `:model_select` receives zero `classification_decision` facts; all rules silently fail.

**Fix:** Validate pipeline completeness before evaluation. Warn if upstream KB was skipped.

### C6. Fact Assertion Has No Null Guards
**`fact_asserter.rb:17-32`**

`assert_model_facts` calls `config.models.each` without nil check. `assert_session_facts` accesses `AIA.session_tracker` with no null guard. If gate KB runs before session tracker initializes, all gate rules silently fail.

### C7. HistoryManager Calls `exit(1)` Directly
**`history_manager.rb:32, 39, 45`**

Any error during variable collection terminates the process. No way to handle gracefully in tests or non-CLI contexts.

**Fix:** Raise exceptions; let callers decide handling.

### C8. `logger` Undefined in TFIDF Filter
**`tool_filter/tfidf.rb:58`**

`logger.warn(...)` will raise `NoMethodError`. Currently masked because the error path is never hit in tests.

---

## 4. High Priority Issues (Fix in Next Release)

### Session God-Object
**`session.rb:26-392`** — 10+ responsibilities including five identical tool filter initialization branches:

```ruby
if AIA.config.flags.tool_filter_a
  kbs_filter = ToolFilter::KBS.new(...); kbs_filter.prep; @filters[:kbs] = kbs_filter
elsif ...
# repeated 4 more times identically
```

**Fix:** `ToolFilterRegistry.build_from_config(config, tools)` — one call, returns `@filters` hash.

### RobotFactory Has 13 Responsibilities
**`robot_factory.rb`** — builds robots, networks, concurrent networks, normalizes MCP config, manages network memory, sets up message bus, loads tools, assembles system prompts, configures RobotLab globally, configures local providers, resolves provider slugs, transfers history, generates run config.

**Fix:** Extract `RobotBuilder`, `NetworkAssembler`, `MCPConfigNormalizer`, `NetworkMemoryManager`.

### ConfigValidator Does 14 Steps + EarlyExit Anti-Pattern
**`config/validator.rb`** — `tailor()` runs 14 sequential steps; some perform I/O, some cause early exit. `EarlyExit` is an exception used as `goto`.

**Fix:** Replace with result object: `tailor()` returns `:continue`, `:early_exit`, or raises real errors.

### No Handler Protocol
**`spawn_handler.rb`, `debate_handler.rb`, `delegate_handler.rb`, `mention_router.rb`, `model_switch_handler.rb`**

Five handlers, five incompatible signatures:
```ruby
SpawnHandler#handle(prompt, specialist_type: nil)
DebateHandler#handle(prompt)
DelegateHandler#handle(prompt)
MentionRouter#handle(robot, prompt)          # different parameter order
ModelSwitchHandler#handle(decisions, config) # completely different
```

Cannot build a generic dispatch mechanism. Adding a sixth handler requires understanding all five.

**Fix:** Define `HandlerProtocol` — a unified `handle(context)` where context carries robot, prompt, decisions, config.

### Content Extraction Duplicated in Three Handlers
`SpawnHandler#extract_reply`, `DebateHandler#extract_reply`, `DelegateHandler#extract_reply` are identical. All three include `ContentExtractor` but don't use it.

**Fix:** Make `ContentExtractor#extract_content` the canonical implementation and remove the local copies.

### TurnState Has No Invariants
**`turn_state.rb`** — eight attributes (`force_verify`, `force_decompose`, `force_concurrent_mcp`, `force_debate`, `force_delegate`, `force_spawn`, `active_mcp_servers`, `active_tools`) with no state machine. Multiple `force_*` flags can be true simultaneously. Behavior is undefined. Flag clearing is distributed across `ChatLoop`, `SpecialModeHandler`, and individual directives.

**Fix:** State machine or command queue. Directives enqueue commands; `SpecialModeHandler` dequeues.

### TaskCoordinator Accesses Bridge's Private Database
**`task_coordinator.rb:14`**

```ruby
@db = bridge.send(:db)  # Bypasses private access
```

Direct encapsulation break. If `TrakFlowBridge` renames `db`, `TaskCoordinator` silently fails with `NoMethodError`.

### Cost Calculation Duplicated Three Times
`SessionTracker`, `UIPresenter`, and `PromptHandler` each implement the same logic: fetch price from RubyLLM, multiply tokens, divide by 1,000,000.

**Fix:** Single `CostCalculator` service.

---

## 5. Medium Priority Issues

### ChatLoop `run_loop` Has 13 Conditional Branches
**`chat_loop.rb:84-188`** — handles input reading, directive dispatch, PM parse errors, KBS evaluation, model switching, quality gate, special modes, expert routing, mention routing, streaming, metrics, output, speech, MCP filter clearing. Untestable as a unit.

### ChatLoop Hardcodes Directive Names
**`chat_loop.rb:231-240`**
```ruby
if follow_up_prompt.strip.start_with?("/clear", "/checkpoint", "/restore", "/review", "/context")
```
Adding a new context directive requires editing this list. Open/Closed violation.

**Fix:** Directive registry with categories. Context directives self-register.

### ExpertRouter is Dead Code
**`expert_router.rb`** — compiles but is never instantiated or called from any production code path. Also duplicates `DecisionApplier#build_temp_robot` logic.

**Fix:** Integrate into `DecisionApplier` or remove.

### MCPDiscovery and MCPGrouper are Unused
**`mcp_discovery.rb`**, **`mcp_grouper.rb`** — fully implemented, never invoked. The KBS rule-based server selection path (`mcp_activations`) is never triggered because no caller populates it.

**Fix:** Wire `MCPDiscovery` into `Session#connect_mcp_servers` after KBS evaluation, or remove.

### TFIDF Rebuilds Vectorizer Per Query
**`tool_filter/tfidf.rb:37-56`** — calls `Classifier::TFIDF.new`, `fit`, and `transform` on every user turn.

**Fix:** Pre-compute in `do_prep`, cache vectors.

### Debate Convergence is a Keyword Match
**`debate_handler.rb:96-98`**
```ruby
round_results.any? { |r| r[:content].to_s.include?("CONVERGED") }
```
One robot mentioning "CONVERGED" anywhere ends the debate. No consensus check, no semantic similarity, no minimum round count.

### Spawned Robot Lifecycle Unmanaged
**`spawn_handler.rb:18, 39`** — `@spawned = {}` caches specialist robots indefinitely. No cleanup on session end. No resource limits. Reuses cached specialist with accumulated conversation history.

### PromptHandler Mutates Global Config
**`prompt_handler.rb:104-122, 173-221`** — `apply_metadata_config` and `apply_root_shorthands` write directly to `AIA.config`. No transaction semantics.

### UIPresenter Contains Business Logic
**`ui_presenter.rb:284-310`** — cost calculation (`RubyLLM::Models.find`, price × tokens / 1,000,000) lives in the display layer.

---

## 6. Duplication Inventory

| Pattern | Locations | Count |
|---------|-----------|-------|
| `extract_reply` | SpawnHandler, DebateHandler, DelegateHandler | 3× identical |
| `collect_mcp_tools` traversal (robot → first network robot → RubyLLM::MCP fallback) | Session, FactAsserter, Utility | 3× identical |
| `output_to_file` | ChatLoop, Session, SpecialModeHandler | 3× identical |
| Cost calculation | SessionTracker, UIPresenter, PromptHandler | 3× near-identical |
| Post-execution block (extract → track → display → output → metrics → speak → separator) | ChatLoop#run_loop, route_to_expert, process_initial_context, SpecialModeHandler (4 handlers) | ~7× near-identical |
| `build_opts` hash in network builders | build_parallel_network, build_consensus_network, build_pipeline_network, build_concurrent_mcp_network | 4× similar |
| Embedding model loading | zvec.rb:172-174, sqlite_vec.rb:160-162 | 2× identical |
| MCP server name extraction (`server[:name] \|\| server['name']`) | 5+ call sites across config, factory, utility | 5× inline |

---

## 7. Dead Code / Unused Features

| Item | File | Status |
|------|------|--------|
| `ExpertRouter` | `expert_router.rb` | Compiles, never called |
| `MCPDiscovery` KBS path | `mcp_discovery.rb:23-31` | Code exists, never triggered |
| `MCPGrouper` | `mcp_grouper.rb` | Implemented, never called |
| `Fzf#tempfile_path` | `fzf.rb:63-73` | Creates tempfile that is never used |
| `HistoryManager` history features | `history_manager.rb` | Named "history manager" but only does input prompting |

---

## 8. Cross-Cutting Issues

### No Dependency Injection
Every class hardwires dependencies via `AIA.*` globals. Unit tests for `Session`, `ChatLoop`, `RuleRouter`, `FactAsserter`, and all handlers are actually integration tests requiring a full AIA stack.

### Silent Error Swallowing is the Default
`rescue StandardError; warn "Warning: #{e.message}"; return nil` appears in 20+ locations. No backtraces. No structured logging. Cannot distinguish "expected degradation" from "bug."

### Two MCP Systems Not Fully Unified
`RubyLLM::MCP` (--require path) and `RobotLab::MCP` (config file path) are bridged via `absorb_ruby_llm_mcp_clients`, but `MCPDiscovery` and `MCPGrouper` only see the config-file path. Tools loaded via `--require` are invisible to rule-based server selection.

### Config Precedence Bug
**`config.rb:357-362`** — documented precedence says CLI > env vars, but `apply_models_env_var()` runs *after* CLI overrides are applied.

### MCP Server Name Extraction Scattered
`server[:name] || server['name']` appears inline in 5+ places. `Utility.server_name()` exists but is inconsistently used.

**Fix:** `MCPServerConfig` value object that normalizes on construction.

---

## 9. Test Coverage Gaps

| Component | Estimated Coverage | Risk |
|-----------|--------------------|------|
| `ChatLoop#run_loop` | ~39% | High — core REPL, 13 branches |
| `SpecialModeHandler` | ~17% | High — 6 mode handlers |
| `MentionRouter` | ~22% | Medium |
| `StreamingRunner` | ~21% | Medium |
| `ExpertRouter` | ~0% | N/A (dead code) |
| KBS network turn recording | Low | Medium |

---

## 10. Priority Recommendations

### P0 — Fix Before Production

| # | Item | Location |
|---|------|----------|
| 1 | MCPConnectionManager race condition (reads without mutex) | `mcp_connection_manager.rb:72-83` |
| 2 | Add `AIA.reset!` for test isolation | `aia.rb` |
| 3 | Decisions schema — reject nil model | `decisions.rb:22-30` |
| 4 | DecisionApplier — log/surface failed temp robot build | `decision_applier.rb:100-116` |
| 5 | HistoryManager — raise instead of exit | `history_manager.rb:32,39,45` |
| 6 | Fix undefined `logger` in TFIDF filter | `tool_filter/tfidf.rb:58` |

### P1 — Next Release

| # | Item | Effort |
|---|------|--------|
| 7 | Extract `ToolFilterRegistry` — eliminate 5 if-branches in Session | Medium |
| 8 | Define `HandlerProtocol` — unify 5 handler signatures | Medium |
| 9 | Consolidate `extract_reply` into `ContentExtractor` | Small |
| 10 | Add null guards to FactAsserter fact assertion methods | Small |
| 11 | Add pipeline validation to RuleRouter (warn on missing KB) | Small |
| 12 | Convert ToolLoader to instantiable class (fix module cache) | Medium |
| 13 | Fix TurnState — define valid state combinations | Medium |
| 14 | Fix TaskCoordinator — remove `bridge.send(:db)` | Small |
| 15 | Extract `CostCalculator` service | Small |

### P2 — Near Term

| # | Item | Effort |
|---|------|--------|
| 16 | Split Session into `PipelineOrchestrator` + `StartupCoordinator` | Large |
| 17 | Split RobotFactory into `RobotBuilder` + `NetworkAssembler` + `MCPConfigNormalizer` | Large |
| 18 | Split ConfigValidator into composable step objects | Medium |
| 19 | Integrate or remove ExpertRouter | Medium |
| 20 | Wire MCPDiscovery into session startup, or remove | Medium |
| 21 | Improve debate convergence (semantic similarity, minimum rounds) | Medium |
| 22 | Manage spawned robot lifecycle (cleanup, resource limits) | Medium |
| 23 | Decouple DelegateHandler (extract TaskDecomposer + TaskExecutor) | Medium |

### P3 — Backlog

| # | Item |
|---|------|
| 24 | Cache TFIDF vectorizer in `do_prep` |
| 25 | Extract embedding model loader mixin (Zvec + SqliteVec) |
| 26 | Fix MentionRouter — strip mentions from prompt before sending |
| 27 | Cache `model_exists?` lookups in ModelSwitchHandler |
| 28 | Extract `MCPServerConfig` value object (normalize symbol/string keys once) |
| 29 | Fix FZF dead code (`tempfile_path` creates but never uses temp file) |
| 30 | Split Utility into domain-specific managers |
| 31 | Fix SQLiteVec rowid mapping (use explicit tool_id column) |
| 32 | Pin `robot_lab` and `kbs` version constraints once they reach 0.1.0 |
| 33 | Rename `HistoryManager` → `VariableInputCollector` |
| 34 | Move cost calculation out of UIPresenter into CostCalculator |

---

## 11. Full Review

See `.architecture/reviews/comprehensive-architecture-review-2026-03-27.md` for the complete six-domain analysis with file-level citations and code examples.
