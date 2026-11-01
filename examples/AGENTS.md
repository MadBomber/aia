### Local Agent Context: examples

## Setup & Commands

- Run setup before other scripts: `bash 00_setup_aia.sh`. Requires `aia` installed and `ANTHROPIC_API_KEY` set.
- Execute the demo scripts sequentially, starting with: `bash 01_basic_usage.sh`.
- For complete execution, use `bash run_all.sh`. **Skips interactive and setups**: consult the header for details.
- If comparing outputs, redirect logs with `bash run_all.sh --no-save | tee my_run.log`.

## Implementation Details

### Key Infrastructure Steps

1. **Preparation**: Verify prerequisites and configure environment with `00_setup_aia.sh`.
   - Confirms `aia` and `ANTHROPIC_API_KEY`, and sets up the prompts directory.
2. **Config File Management**: Maintain `aia_config.yml` to dictate demos' environmental settings.
   - Modify models in the `models` section to change the default processing model.
3. **Models**: Demos use `claude-haiku-4-5` (default) and `claude-sonnet-4-6` (second model in multi-model demos).

### Script Execution

- Each script depends on a shared setup in `common.sh`, resetting environment before execution.
- `aia -c aia_config.yml --no-output <prompt>` command pattern used to run the main LLM interaction with defined configurations.
  
### Documentation

- Reference `README.md` for context and detail on prerequisites, script purpose, and usage guides.
- Change model provider in `aia_config.yml` for performance or cost reasons, using variables such as `ANTHROPIC_API_KEY`.
