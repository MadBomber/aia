# AIA v2.0.0 — Implementation Plan
## Date: 2026-03-27
## Source: Comprehensive Architecture Review (2026-03-27)
## Scope: 34 improvement items, sequenced for testable and releasable increments

Each section is independently testable and releasable. No section depends on unreleased work from a later section.

---

## Section 1 — Safety Net (P0 Critical Fixes) ✓ COMPLETED

**Release tag:** `v2.0.1.alpha` — tagged 2026-03-27

These are all small, self-contained fixes with no interdependencies. Each can be implemented and tested in isolation. Together they eliminate the critical production risks identified in the architecture review.

### 1.1 — MCPConnectionManager: Mutex on All Reads ✓
**Source:** C1 / P0-1 | **File:** `mcp_connection_manager.rb:72-83` | **Size:** S

`inject_into()` reads `@connected_clients` and `@connected_tools` without acquiring `@mutex`. Threads writing in `connect_one()` race with the main thread reading in `inject_into()`.

**Fix:** Wrap all reads of `@connected_clients` and `@connected_tools` in `@mutex.synchronize`. Snapshot state under lock before iteration.

**Test:** Write a test that runs `connect_one` threads concurrently with `inject_into` calls and asserts no partial state is observed.

---

### 1.2 — AIA.reset! for Test Isolation ✓
**Source:** C2 / P0-2 | **File:** `aia.rb:77-88` | **Size:** S

Six mutable class-level singletons (`config`, `client`, `session_tracker`, `turn_state`, `task_coordinator`, `decisions`, `rule_router`) with no reset mechanism. Tests must manually nil each one; forgetting one causes cross-test state leakage.

**Fix:**
```ruby
def self.reset!
  @config = @client = @session_tracker = @turn_state =
    @task_coordinator = @decisions = @rule_router = nil
end
```

Call `AIA.reset!` in every test `teardown`.

**Test:** Verify that state set in one test does not leak to the next when `reset!` is called in teardown.

---

### 1.3 — Decisions Schema: Reject nil Model ✓
**Source:** C3 / P0-3 | **File:** `decisions.rb:22-30` | **Size:** S

`decisions.add(:model_decision, model: nil)` is accepted silently. Downstream callers pass `nil` to `RobotLab.build(model: nil)` — crash with no indication of source.

**Fix:** In `add()`, validate required keys for known decision types. For `:model_decision`, assert `:model` is non-nil before storing.

**Test:** Assert that `decisions.add(:model_decision, model: nil)` raises `ArgumentError` with a meaningful message.

---

### 1.4 — HistoryManager: Raise Instead of exit(1) ✓
**Source:** C7 / P0-5 | **File:** `history_manager.rb:32,39,45` | **Size:** S

Any error during variable collection terminates the process via `exit(1)`. No way to handle gracefully in tests or non-CLI contexts.

**Fix:** Replace all `exit(1)` calls with `raise` (appropriate exception class). Let the CLI entry point in `bin/aia` catch and call `exit(1)`.

**Test:** Simulate error conditions in `HistoryManager` and assert they raise exceptions rather than calling `exit`.

---

### 1.5 — TFIDF Filter: Fix Undefined `logger` ✓
**Source:** C8 / P0-6 | **File:** `tool_filter/tfidf.rb:58` | **Size:** S

`logger.warn(...)` will raise `NoMethodError` on the error path. Currently masked because the error path is never hit in tests.

**Fix:** Replace `logger.warn(...)` with `warn(...)` (Kernel#warn), or include the `LoggerManager` mixin, whichever is consistent with other tool filter classes.

**Test:** Trigger the error path in `ToolFilter::TFIDF` and assert the warning is emitted without raising `NoMethodError`.

---

## Section 2 — Correctness Completions (P0 + P1 Small Fixes) ✓ COMPLETED

**Release tag:** `v2.0.2.alpha` — tagged 2026-03-27
**Depends on:** Section 1 (requires `AIA.reset!` for test isolation)

### 2.1 — DecisionApplier: Surface Failed Temp Robot Build ✓
**Source:** C4 / P0-4 | **File:** `decision_applier.rb:100-116` | **Size:** S

If `build_temp_robot` returns nil, the turn proceeds silently with the original robot. `context.model_overridden` is never set.

**Fix:** Log a warning when `build_temp_robot` returns nil. Set `context.model_overridden = false` explicitly. Consider raising if this indicates a KBS misconfiguration.

**Test:** Stub `build_temp_robot` to return nil and assert the warning is emitted and the original robot is used.

---

### 2.2 — FactAsserter: Add Null Guards ✓
**Source:** P1-10 | **File:** `fact_asserter.rb:17-32` | **Size:** S

`assert_model_facts` calls `config.models.each` without nil check. `assert_session_facts` accesses `AIA.session_tracker` with no null guard.

**Fix:** Guard all `AIA.*` accesses with nil checks. Return early (no-op) if the resource is not yet initialized.

**Test:** Call fact asserter methods when `AIA.session_tracker` is nil and assert no exception is raised.

---

### 2.3 — RuleRouter: Validate Pipeline Completeness ✓
**Source:** C5 / P1-11 | **File:** `rule_router.rb:84-105` | **Size:** S

Missing KBs are skipped with `next unless kb` — no warning. If `:classify` is absent, downstream KBs receive zero facts and all rules silently fail.

**Fix:** Before pipeline evaluation, check that each expected KB exists. Emit a structured warning (`warn "[RuleRouter] KB :#{name} not found — downstream rules may fail"`) for any missing KB.

**Test:** Remove a KB from the pipeline and assert the warning is emitted.

---

### 2.4 — TaskCoordinator: Remove bridge.send(:db) ✓
**Source:** P1-14 | **File:** `task_coordinator.rb:14` | **Size:** S

`@db = bridge.send(:db)` bypasses private access. If `TrakFlowBridge` renames `db`, `TaskCoordinator` silently fails with `NoMethodError`.

**Fix:** Add a public `db` accessor (or a `with_db` yield method) to `TrakFlowBridge`. Remove `send(:db)` from `TaskCoordinator`.

**Test:** Verify `TaskCoordinator` accesses the database without using `send`.

---

### 2.5 — Extract CostCalculator Service ✓
**Source:** P1-15 | **Files:** `session_tracker.rb`, `ui_presenter.rb`, `prompt_handler.rb` | **Size:** S

Cost calculation (fetch price from RubyLLM, multiply tokens, divide by 1,000,000) is duplicated in three places.

**Fix:** Create `lib/aia/cost_calculator.rb` with a single `CostCalculator.calculate(model:, input_tokens:, output_tokens:)` method. Replace all three inline implementations.

**Test:** Unit test `CostCalculator` directly. Verify the three call sites use it.

---

## Section 3 — Handler Cleanup (P1 + P3) ✓ COMPLETED

**Release tag:** `v2.0.3.alpha` — tagged 2026-03-27
**Depends on:** Section 2 (uses `CostCalculator` from 2.5)

### 3.1 — Consolidate extract_reply into ContentExtractor ✓
**Source:** P1-9 | **Files:** `spawn_handler.rb`, `debate_handler.rb`, `delegate_handler.rb` | **Size:** S

Three identical `extract_reply` implementations. All three include `ContentExtractor` but don't use it.

**Fix:** Implement `ContentExtractor#extract_content` as the canonical method. Delete the three local copies. Each handler calls `extract_content(response)`.

**Test:** Verify each handler's reply extraction uses `ContentExtractor#extract_content`.

---

### 3.2 — Define HandlerProtocol: Unify 5 Handler Signatures ✓
**Source:** P1-8 | **Files:** `spawn_handler.rb`, `debate_handler.rb`, `delegate_handler.rb`, `mention_router.rb`, `model_switch_handler.rb` | **Size:** M

Five handlers, five incompatible signatures — no generic dispatch is possible.

**Fix:** Define `module HandlerProtocol` requiring a `handle(context)` method where `context` is a value object carrying `robot`, `prompt`, `decisions`, and `config`. Migrate all five handlers to this signature. Update all call sites.

**Test:** Verify all five handlers respond to `handle(context)` with the same interface. Test dispatch via a generic caller.

---

### 3.3 — Remove FZF Dead Code (tempfile_path) ✓
**Source:** P3-29 | **File:** `fzf.rb:63-73` | **Size:** S

`Fzf#tempfile_path` creates a tempfile that is never used.

**Fix:** Delete the method.

**Test:** Verify `Fzf` no longer defines `tempfile_path`.

---

### 3.4 — Move Cost Calculation out of UIPresenter ✓
**Source:** P3-34 | **File:** `ui_presenter.rb:284-310` | **Size:** S

Cost calculation lives in the display layer (depends on Section 2.5 `CostCalculator`).

**Fix:** Replace the inline cost logic in `UIPresenter` with a call to `CostCalculator.calculate(...)`.

**Test:** Verify `UIPresenter` does not contain cost calculation logic.

---

## Section 4 — Tool Infrastructure (P1 + P3) ✓ COMPLETED

**Release tag:** `v2.0.4.alpha` — tagged 2026-03-27
**Depends on:** Section 1 (thread safety groundwork)

### 4.1 — Convert ToolLoader to Instantiable Class ✓
**Source:** P1-12 | **File:** `lib/aia/tool_loader.rb` | **Size:** M

`module_function` with `@tool_cache` ivar is not thread-safe and leaks between tests. The module acts as a singleton with shared state.

**Fix:** Convert to a class with proper instance state. Inject dependencies (`config`) at construction time. Replace the `@tool_cache` module ivar with an instance ivar. Update all callers.

**Test:** Verify two `ToolLoader` instances have independent caches. Verify `clear_cache!` only affects the instance.

---

### 4.2 — Extract ToolFilterRegistry ✓
**Source:** P1-7 | **File:** `session.rb:26-392` | **Size:** M

Five identical `if/elsif` branches for tool filter initialization in `Session`.

```ruby
if AIA.config.flags.tool_filter_a
  kbs_filter = ToolFilter::KBS.new(...); kbs_filter.prep; @filters[:kbs] = kbs_filter
elsif ...
# repeated 4 more times
```

**Fix:** Create `ToolFilterRegistry.build_from_config(config, tools)` that returns a populated `@filters` hash. Session calls this one method.

**Test:** Unit test `ToolFilterRegistry` with each config flag. Verify correct filter type is returned.

---

### 4.3 — Fix SQLiteVec Rowid Mapping ✓
**Source:** P3-31 | **File:** `tool_filter/sqlite_vec.rb` | **Size:** S

Use explicit `tool_id` column instead of implicit rowid for SQLite-vec row mapping.

**Fix:** Add explicit `tool_id INTEGER` column to the virtual table schema. Update insert and query logic.

**Test:** Verify tool lookup by ID is stable after deletions/reinsertions.

---

### 4.4 — Extract Embedding Model Loader Mixin ✓
**Source:** P3-25 | **Files:** `tool_filter/zvec.rb:172-174`, `tool_filter/sqlite_vec.rb:160-162` | **Size:** S

Identical embedding model loading code in two files.

**Fix:** Create `module EmbeddingModelLoader` with `load_embedding_model` method. Include in both `ToolFilter::Zvec` and `ToolFilter::SqliteVec`.

**Test:** Verify both classes use the shared mixin.

---

### 4.5 — Cache TFIDF Vectorizer in do_prep ✓
**Source:** P3-24 | **File:** `tool_filter/tfidf.rb:37-56` | **Size:** S

`Classifier::TFIDF.new`, `fit`, and `transform` are called on every user turn.

**Fix:** Move vectorizer construction and fitting into `do_prep`. Cache the fitted vectorizer as an instance variable. Per-turn, only call `transform` on the query.

**Test:** Verify `do_prep` is called once and `Classifier::TFIDF.new` is not called during per-turn filtering.

---

## Section 5 — State Machine & Lifecycle (P1 + P2 + P3) ✓ COMPLETED

**Release tag:** `v2.0.5.alpha` — tagged 2026-03-27
**Depends on:** Section 3 (HandlerProtocol from 3.2)

### 5.1 — TurnState: Define Valid State Combinations ✓
**Source:** P1-13 | **File:** `turn_state.rb` | **Size:** M

Eight `force_*` flags with no state machine. Multiple flags can be true simultaneously. Flag clearing is distributed across `ChatLoop`, `SpecialModeHandler`, and individual directives.

**Fix:** Define a state machine or command queue. Directives enqueue a command object; `SpecialModeHandler` dequeues and executes. Enforce mutual exclusion at enqueue time (not after the fact). Centralize flag clearing.

**Test:** Attempt to set two conflicting `force_*` flags and assert only the later one is active. Verify flags are cleared after `SpecialModeHandler` executes.

---

### 5.2 — Manage Spawned Robot Lifecycle ✓
**Source:** P2-22 | **File:** `spawn_handler.rb:18,39` | **Size:** M

`@spawned = {}` caches specialist robots indefinitely. No cleanup on session end. No resource limits. Reuses cached specialist with accumulated history.

**Fix:** Add a max cache size (configurable, default 5). Add `cleanup!` method called on session end. Optionally clear conversation history when reusing a cached specialist.

**Test:** Verify spawned robots are evicted when cache exceeds max size. Verify `cleanup!` releases all cached robots.

---

### 5.3 — Improve Debate Convergence ✓
**Source:** P2-21 | **File:** `debate_handler.rb:96-98` | **Size:** M

Convergence check is a string match for `"CONVERGED"` — one robot mentioning the word ends the debate prematurely.

**Fix:** Replace keyword check with semantic similarity scoring (using `SimilarityScorer`) between consecutive rounds. Require a minimum round count before convergence is allowed.

**Test:** Verify a round containing "CONVERGED" incidentally does not end the debate before the minimum round count. Verify high similarity scores trigger convergence.

---

### 5.4 — MentionRouter: Strip Mentions from Prompt Before Sending ✓
**Source:** P3-26 | **File:** `mention_router.rb` | **Size:** S

Mentions (`@robot_name`) are parsed but not stripped from the prompt sent to the target robot.

**Fix:** After extracting the mention target, strip the `@robot_name` prefix from the prompt text before routing.

**Test:** Assert the prompt delivered to the target robot does not contain the `@mention` prefix.

---

### 5.5 — Cache model_exists? Lookups in ModelSwitchHandler ✓
**Source:** P3-27 | **File:** `model_switch_handler.rb` | **Size:** S

Repeated `model_exists?` calls with no caching.

**Fix:** Memoize results in a class-level or instance-level hash keyed by model name. Invalidate on config change if needed.

**Test:** Verify `model_exists?` for the same model name hits the provider once and uses cache on subsequent calls.

---

## Section 6 — Structural Decompositions (P2) ✓ COMPLETED

**Release tag:** `v2.0.6.alpha` — tagged 2026-03-28
**Depends on:** Sections 4 (ToolFilterRegistry), 3 (HandlerProtocol)

These are large refactors. Each produces a working, tested replacement before the original is removed.

### 6.1 — Split ConfigValidator into Composable Step Objects ✓
**Source:** P2-18 | **File:** `config/validator.rb` | **Size:** M

`tailor()` runs 14 sequential steps; some perform I/O, some cause early exit. `EarlyExit` exception used as `goto`.

**Fix:** Each step becomes a callable object (`ConfigStep`) with a `call(config) => Result` signature. `Result` is `:continue | :early_exit | raise`. `tailor()` iterates steps and checks result. Remove `EarlyExit` exception class.

**Test:** Unit test each step in isolation. Verify early-exit steps don't run subsequent steps. Verify I/O steps can be stubbed independently.

---

### 6.2 — Integrate or Remove ExpertRouter ✓
**Source:** P2-19 | **File:** `expert_router.rb` | **Size:** M

`ExpertRouter` compiles but is never instantiated or called. Also duplicates `DecisionApplier#build_temp_robot` logic.

**Fix:** Decision: integrate into `DecisionApplier` (preferred) or remove entirely. If integrating, use the `HandlerProtocol` context object from Section 3.2.

**Test:** If integrated: test the expert routing path end-to-end. If removed: verify no production code references `ExpertRouter`.

---

### 6.3 — Decouple DelegateHandler ✓
**Source:** P2-23 | **File:** `delegate_handler.rb` | **Size:** M

`DelegateHandler` mixes task decomposition, task execution, and TrakFlow coordination into one class.

**Fix:** Extract `TaskDecomposer` (breaks prompt into sub-tasks) and `TaskExecutor` (runs a sub-task against a specialist robot). `DelegateHandler` becomes a thin coordinator calling both.

**Test:** Unit test `TaskDecomposer` with various prompts. Unit test `TaskExecutor` with a stubbed robot. Test `DelegateHandler` as an integration.

---

### 6.4 — Split Session into PipelineOrchestrator + StartupCoordinator ✓
**Source:** P2-16 | **File:** `session.rb:26-392` | **Size:** L

`Session` has 10+ responsibilities including startup, MCP connection, tool loading, filter initialization, KBS evaluation, and turn orchestration.

**Fix:**
- `StartupCoordinator` — MCP connection, tool loading, filter initialization, KBS startup evaluation
- `PipelineOrchestrator` — per-turn pipeline: fact assertion, rule evaluation, decision application, robot dispatch
- `Session` becomes a thin shell that sequences `StartupCoordinator` then hands off to `PipelineOrchestrator` per turn

**Test:** Unit test `StartupCoordinator` with stubbed MCP/tool dependencies. Unit test `PipelineOrchestrator` with a stubbed robot and known facts. Integration test via `Session`.

---

### 6.5 — Split RobotFactory into Focused Builders ✓
**Source:** P2-17 | **File:** `robot_factory.rb` | **Size:** L

`RobotFactory` has 13 responsibilities: building robots, networks, concurrent networks, normalizing MCP config, managing network memory, setting up message bus, loading tools, assembling system prompts, configuring RobotLab globally, configuring local providers, resolving provider slugs, transferring history, generating run config.

**Fix:** Extract:
- `RobotBuilder` — single robot construction with system prompt and tools
- `NetworkAssembler` — wraps multiple robots into RobotLab networks (parallel, consensus, pipeline, concurrent-MCP)
- `MCPConfigNormalizer` — normalizes symbol/string key MCP server configs into uniform structs
- `NetworkMemoryManager` — attaches and manages memory backends for networks

`RobotFactory` becomes an orchestrator calling these in sequence.

**Test:** Unit test each builder in isolation. Verify `RobotFactory` integration test still passes.

---

## Section 7 — MCPDiscovery Decision (P2) ✓ COMPLETED

**Release tag:** `v2.0.7.alpha` — tagged 2026-03-28
**Depends on:** Section 6 (Session refactor from 6.4)

### 7.1 — Wire MCPDiscovery or Remove It ✓
**Source:** P2-20 | **Files:** `mcp_discovery.rb`, `mcp_grouper.rb` | **Size:** M

`MCPDiscovery` and `MCPGrouper` are fully implemented but never invoked. The KBS rule-based server selection path (`mcp_activations`) is never triggered because no caller populates it.

**Decision: Option A — Wire.**

**Fix (Option A — Wire):** After KBS evaluation in `StartupCoordinator` (Section 6.4), call `MCPDiscovery.servers_for(decisions)` and pass results to `MCPConnectionManager`. Ensure `MCPDiscovery` sees both RubyLLM::MCP and RobotLab::MCP servers.

**Fix (Option B — Remove):** Delete `mcp_discovery.rb` and `mcp_grouper.rb`. Update the dead code list in `architecture_review.md`.

**Decision criteria:** If the KBS-driven MCP activation feature is on the near-term roadmap, choose Option A. Otherwise, choose Option B and avoid carrying dead weight.

**Test (if Option A):** Verify KBS decisions that activate MCP servers result in those servers being connected. Verify servers not in decisions are skipped.

---

## Section 8 — Backlog Cleanup (P3) ✓ COMPLETED

**Release tag:** `v2.0.8.alpha` — tagged 2026-03-28
**Depends on:** Sections 4–7

These are housekeeping items. None are blocking; all improve long-term maintainability.

### 8.1 — Consolidate server_name Inline Patterns ✓
**Source:** P3-28 | **Files:** 5+ call sites | **Size:** S

`server[:name] || server['name']` appears inline in 5+ places. `Utility.server_name()` exists but is inconsistently used.

**Fix:** Replace all inline `server[:name] || server['name']` usages with `Utility.server_name(server)` (or `AIA::Utility.server_name(server)` where the module isn't in scope). Updated `fact_asserter.rb`, `config/validator.rb` (×2), and `mcp_discovery.rb` (×2).

---

### 8.2 — Split Utility into Domain-Specific Modules ✓
**Source:** P3-30 | **File:** `utility.rb` | **Size:** M

`Utility` was a grab-bag class with MCP, tool, and display methods mixed together.

**Fix:** Extracted `MCPUtility` module (`lib/aia/mcp_utility.rb`) for MCP server query methods, and `ToolUtility` module (`lib/aia/tool_utility.rb`) for tool query methods. Both are included into `Utility` via `class << self include`. `utility.rb` retains only display/banner and model-refresh methods.

---

### 8.3 — Pin robot_lab and kbs Version Constraints ✓
**Source:** P3-32 | **File:** `aia.gemspec` | **Size:** S

`robot_lab` and `kbs` used redundant double-constraint notation (`'~> 0.0', '>= 0.0.9'`).

**Fix:** Simplified to single pessimistic constraints: `robot_lab '~> 0.0.9'` and `kbs '~> 0.2.1'`.

---

### 8.4 — Rename HistoryManager → VariableInputCollector ✓
**Source:** P3-33 | **File:** `history_manager.rb` | **Size:** S

`HistoryManager` was named for a feature it doesn't implement. It only does input prompting for prompt variables.

**Fix:** Created `lib/aia/variable_input_collector.rb` with `VariableInputCollector` class and `HistoryManager = VariableInputCollector` alias. `history_manager.rb` is now a shim that requires the new file. Updated `input_collector.rb` and `lib/aia.rb` to use `VariableInputCollector`. New test file `test/aia/variable_input_collector_test.rb` covers all cases including the alias.

---

## Summary Table

| Section | Focus | Items | Size | Release |
|---------|-------|-------|------|---------|
| 1 | P0 Critical Safety | 5 | S×5 | v2.0.1.alpha |
| 2 | Correctness Completions | 5 | S×5 | v2.0.2.alpha |
| 3 | Handler Cleanup | 4 | S×3, M×1 | v2.0.3.alpha |
| 4 | Tool Infrastructure | 5 | S×4, M×1 | v2.0.4.alpha |
| 5 | State Machine & Lifecycle | 5 | S×3, M×2 | v2.0.5.alpha |
| 6 | Structural Decompositions | 5 | S×1, M×2, L×2 | v2.0.6.alpha |
| 7 | MCPDiscovery Decision | 1 | M×1 | v2.0.7.alpha |
| 8 | Backlog Cleanup | 4 | S×3, M×1 | v2.0.8.alpha |
| **Total** | | **34** | | |

### Key Dependencies

```
Section 1 → Section 2 (AIA.reset! enables test isolation for all subsequent work)
Section 2 → Section 3 (CostCalculator before UIPresenter cleanup)
Section 3 → Section 5 (HandlerProtocol before TurnState state machine)
Section 4 → Section 6 (ToolFilterRegistry before Session split)
Section 3+4 → Section 6 (HandlerProtocol + ToolFilterRegistry before Session/RobotFactory split)
Section 6 → Section 7 (Session refactor before MCPDiscovery wiring)
Sections 4–7 → Section 8 (cleanup after structural work is stable)
```

---

*Plan generated from: `.architecture/reviews/comprehensive-architecture-review-2026-03-27.md`*
