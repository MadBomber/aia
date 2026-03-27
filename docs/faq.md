<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

- [Frequently Asked Questions](#frequently-asked-questions)
  - [Installation and Setup](#installation-and-setup)
    - [Q: What Ruby version is required for AIA?](#q-what-ruby-version-is-required-for-aia)
    - [Q: How do I install AIA?](#q-how-do-i-install-aia)
    - [Q: Where should I store my API keys?](#q-where-should-i-store-my-api-keys)
    - [Q: Can I use AIA without internet access?](#q-can-i-use-aia-without-internet-access)
    - [Q: How do I list available local models?](#q-how-do-i-list-available-local-models)
    - [Q: What's the difference between Ollama and LM Studio?](#q-whats-the-difference-between-ollama-and-lm-studio)
    - [Q: Can I mix local and cloud models?](#q-can-i-mix-local-and-cloud-models)
    - [Q: Why does my lms/ model show an error?](#q-why-does-my-lms-model-show-an-error)
  - [Basic Usage](#basic-usage)
    - [Q: How do I create my first prompt?](#q-how-do-i-create-my-first-prompt)
    - [Q: What's the difference between batch mode and chat mode?](#q-whats-the-difference-between-batch-mode-and-chat-mode)
    - [Q: How do I use fuzzy search for prompts?](#q-how-do-i-use-fuzzy-search-for-prompts)
  - [Configuration](#configuration)
    - [Q: Where is the configuration file located?](#q-where-is-the-configuration-file-located)
    - [Q: How do I change the default AI model?](#q-how-do-i-change-the-default-ai-model)
    - [Q: How do I set a custom prompts directory?](#q-how-do-i-set-a-custom-prompts-directory)
  - [Prompts and Directives](#prompts-and-directives)
    - [Q: What are directives and how do I use them?](#q-what-are-directives-and-how-do-i-use-them)
    - [Q: How do I include files in prompts?](#q-how-do-i-include-files-in-prompts)
    - [Q: Can I use Ruby code in prompts?](#q-can-i-use-ruby-code-in-prompts)
    - [Q: How do I create prompt workflows?](#q-how-do-i-create-prompt-workflows)
  - [Models and Performance](#models-and-performance)
    - [Q: Which AI model should I use?](#q-which-ai-model-should-i-use)
    - [Q: How do I use multiple models simultaneously?](#q-how-do-i-use-multiple-models-simultaneously)
    - [Q: How do I reduce token usage and costs?](#q-how-do-i-reduce-token-usage-and-costs)
    - [Q: What's consensus mode?](#q-whats-consensus-mode)
  - [Tools and Integration](#tools-and-integration)
    - [Q: What are RubyLLM tools?](#q-what-are-rubyllm-tools)
    - [Q: How do I use tools with AIA?](#q-how-do-i-use-tools-with-aia)
    - [Q: What's the difference between tools and MCP clients?](#q-whats-the-difference-between-tools-and-mcp-clients)
    - [Q: How do I create custom tools?](#q-how-do-i-create-custom-tools)
  - [Chat Mode](#chat-mode)
    - [Q: How do I start a chat session?](#q-how-do-i-start-a-chat-session)
    - [Q: How do I save chat conversations?](#q-how-do-i-save-chat-conversations)
    - [Q: Can I use tools in chat mode?](#q-can-i-use-tools-in-chat-mode)
    - [Q: How do I send a message to just one robot in a multi-model session?](#q-how-do-i-send-a-message-to-just-one-robot-in-a-multi-model-session)
    - [Q: Can I save my place in a conversation and return to it later?](#q-can-i-save-my-place-in-a-conversation-and-return-to-it-later)
    - [Q: How do I clear chat history?](#q-how-do-i-clear-chat-history)
  - [Troubleshooting](#troubleshooting)
    - [Q: "Command not found: aia"](#q-command-not-found-aia)
    - [Q: "No models available" error](#q-no-models-available-error)
    - [Q: "Permission denied" errors](#q-permission-denied-errors)
    - [Q: Prompts are slow or timing out](#q-prompts-are-slow-or-timing-out)
    - [Q: "Tool not found" errors](#q-tool-not-found-errors)
  - [Advanced Usage](#advanced-usage)
    - [Q: How do I use AIA for code review?](#q-how-do-i-use-aia-for-code-review)
    - [Q: Can I use AIA for data analysis?](#q-can-i-use-aia-for-data-analysis)
    - [Q: How do I integrate AIA into my development workflow?](#q-how-do-i-integrate-aia-into-my-development-workflow)
    - [Q: How do I backup my prompts?](#q-how-do-i-backup-my-prompts)
  - [Getting Help](#getting-help)
    - [Q: Where can I find more examples?](#q-where-can-i-find-more-examples)
    - [Q: How do I report bugs or request features?](#q-how-do-i-report-bugs-or-request-features)
    - [Q: Is there a community or forum?](#q-is-there-a-community-or-forum)
    - [Q: Where can I find the latest documentation?](#q-where-can-i-find-the-latest-documentation)
  - [Tips and Best Practices](#tips-and-best-practices)
    - [Q: What are some general best practices for prompts?](#q-what-are-some-general-best-practices-for-prompts)
    - [Q: How do I optimize for performance?](#q-how-do-i-optimize-for-performance)
    - [Q: Security considerations?](#q-security-considerations)
  - [Troubleshooting](#troubleshooting-1)
    - [Q: "Prompt not found" error](#q-prompt-not-found-error)
    - [Q: Model errors or "Model not available"](#q-model-errors-or-model-not-available)
    - [Q: Shell integration not working](#q-shell-integration-not-working)
    - [Q: Configuration issues](#q-configuration-issues)
    - [Q: Performance issues with slow responses](#q-performance-issues-with-slow-responses)
    - [Q: Large prompt processing issues](#q-large-prompt-processing-issues)
    - [Q: Debug mode - how to get more information?](#q-debug-mode---how-to-get-more-information)
    - [Q: Common error messages and solutions](#q-common-error-messages-and-solutions)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

# Frequently Asked Questions

Common questions and answers about using AIA.

## Installation and Setup

### Q: What Ruby version is required for AIA?
**A:** AIA requires Ruby 3.2 or higher. You can check your Ruby version with `ruby --version`.

### Q: How do I install AIA?
**A:** The easiest way is through RubyGems:
```bash
gem install aia
```

See the [Installation Guide](installation.md) for other installation methods.

### Q: Where should I store my API keys?
**A:** Store API keys as environment variables in your shell profile (`.bashrc`, `.zshrc`, etc.):
```bash
export OPENAI_API_KEY="your_key_here"
export ANTHROPIC_API_KEY="your_key_here"
```

### Q: Can I use AIA without internet access?
**A:** Yes! AIA supports two local model providers for complete offline operation:

1. **Ollama**: Run open-source models locally
   ```bash
   # Install and use Ollama
   brew install ollama
   ollama pull llama3.2
   aia --model ollama/llama3.2 --chat
   ```

2. **LM Studio**: GUI-based local model runner
   ```bash
   # Download from https://lmstudio.ai
   # Load a model and start local server
   aia --model lms/your-model-name --chat
   ```

Both options provide full AI functionality without internet connection, perfect for:
- 🔒 Private/sensitive data processing
- ✈️ Offline/travel use
- 💰 Zero API costs
- 🏠 Air-gapped environments

### Q: How do I list available local models?
**A:** Use the `/models` directive in a chat session or prompt:

```bash
# Start chat with any local model
aia --model ollama/llama3.2 --chat

# In the chat session
> /models

# Output shows:
# - Ollama models from local installation
# - LM Studio models currently loaded
# - Cloud models from RubyLLM database
```

For Ollama specifically: `ollama list`
For LM Studio: Check the Models tab in the LM Studio GUI

### Q: What's the difference between Ollama and LM Studio?
**A:**
- **Ollama**: Command-line focused, quick model switching, multiple models available
- **LM Studio**: GUI application, visual model management, one model at a time

Choose **Ollama** if you prefer CLI tools and automation.
Choose **LM Studio** if you want a visual interface and easier model discovery.

Both work great with AIA!

### Q: Can I mix local and cloud models?
**A:** Absolutely! This is a powerful feature:

```bash
# Compare local vs cloud responses
aia --model ollama/llama3.2,gpt-4o-mini my_prompt

# Get consensus across local and cloud models
aia --model ollama/mistral,lms/qwen-coder,claude-3-sonnet --consensus decision

# Use local for drafts, cloud for refinement
aia --model ollama/llama3.2 --output draft.md initial_analysis
aia --model gpt-4 --include draft.md final_report
```

### Q: Why does my lms/ model show an error?
**A:** Common causes:

1. **Model not loaded in LM Studio**: Load a model first
2. **Wrong model name**: AIA validates against available models and shows the exact names to use
3. **Server not running**: Start the local server in LM Studio
4. **Wrong prefix**: Always use `lms/` prefix with full model name

If you get an error, AIA will show you the exact model names to use:
```
❌ 'wrong-name' is not a valid LM Studio model.

Available LM Studio models:
  - lms/qwen/qwen3-coder-30b
  - lms/llama-3.2-3b-instruct
```

## Basic Usage

### Q: How do I create my first prompt?
**A:** Create a text file in your prompts directory:
```bash
echo "Explain this code clearly:" > ~/.prompts/explain_code.md
aia explain_code my_script.py
```

### Q: What's the difference between batch mode and chat mode?
**A:**
- **Batch mode** (default): Processes prompts once and exits
- **Chat mode** (`--chat`): Interactive conversation that maintains context

### Q: How do I use fuzzy search for prompts?
**A:** Install `fzf` and use the `--fuzzy` flag:
```bash
# Install fzf (macOS)
brew install fzf

# Use fuzzy search
aia --fuzzy
```

## Configuration

### Q: Where is the configuration file located?
**A:** The main configuration file is at `~/.config/aia/aia.yml` (following XDG Base Directory Specification). You can create it if it doesn't exist.

### Q: How do I change the default AI model?
**A:** Set it in your configuration file or use the command line:
```yaml
# In config file (~/.config/aia/aia.yml)
models:
  - name: gpt-4
```

```bash
# Command line
aia --model gpt-4 my_prompt
```

### Q: How do I set a custom prompts directory?
**A:** Use the `--prompts-dir` option or set it in configuration:
```bash
# Command line
aia --prompts-dir /path/to/prompts my_prompt

# Environment variable (uses nested naming convention)
export AIA_PROMPTS__DIR="/path/to/prompts"
```

## Prompts and Directives

### Q: What are directives and how do I use them?
**A:** Directives are special commands in prompts that start with `/`. Examples:
```markdown
/config model gpt-4
/include my_file.md
/shell ls -la
```

See the [Directives Reference](directives-reference.md) for all available directives.

### Q: How do I include files in prompts?
**A:** Use the `/include` directive:
```markdown
/include README.md
/include /path/to/file.md
```

### Q: Can I use Ruby code in prompts?
**A:** Yes, use the `/ruby` directive for one-liners:
```markdown
/ruby puts "Hello, my name is#{ENV['USER']}"

# Or for multi-line or conditional code use ERB

<%=
  puts "Hello, my name is #{ENV['USER']}"
  puts "Today is #{Time.now.strftime('%Y-%m-%d')}"
%>
```

### Q: How do I create prompt workflows?
**A:** Use the `/pipeline` or `/next` directives:
```markdown
/pipeline
/next
```

## Models and Performance

### Q: Which AI model should I use?
**A:** It depends on your needs:
- **GPT-4o Mini**: Fast, cost-effective for simple tasks
- **GPT-4**: Best quality for complex reasoning
- **Claude-3 Sonnet**: Great for long documents and analysis
- **Claude-3 Haiku**: Fast and economical

### Q: How do I use multiple models simultaneously?
**A:** Use comma-separated model names:
```bash
aia --model "gpt-4,claude-3-sonnet" my_prompt
```

### Q: How do I reduce token usage and costs?
**A:**
- Use shorter prompts when possible
- Choose appropriate models (`gpt-4o-mini` for simple tasks)
- Use temperature settings wisely
- Clear chat context regularly with `/clear`

### Q: What's consensus mode?
**A:** Consensus mode combines responses from multiple models into a single, refined answer:
```bash
aia --model "gpt-4,claude-3-sonnet" --consensus my_prompt
```

## Tools and Integration

### Q: What are RubyLLM tools?
**A:** Tools are Ruby classes that extend AI capabilities with custom functions like file operations, web requests, or data analysis.

### Q: How do I use tools with AIA?
**A:** Use the `--tools` option:
```bash
aia --tools my_tool.rb my_prompt
aia --tools ./tools/ my_prompt
```

### Q: What's the difference between tools and MCP clients?
**A:**
- **Tools**: Ruby-based extensions that run in the same process
- **MCP clients**: External services using Model Context Protocol

### Q: How do I create custom tools?
**A:** Create a Ruby class inheriting from `RubyLLM::Tool`:
```ruby
class MyTool < RubyLLM::Tool
  description "What this tool does"

  def my_method(param)
    # Implementation
    "Result"
  end
end
```

## Chat Mode

### Q: How do I start a chat session?
**A:** Use the `--chat` flag:
```bash
aia --chat
aia --chat --model gpt-4
```

### Q: How do I save chat conversations?
**A:** Use the `--output` flag to save responses to a file:
```bash
aia --chat --output conversation.md
```

### Q: Can I use tools in chat mode?
**A:** Yes, enable tools when starting chat:
```bash
aia --chat --tools ./tools/
```

### Q: How do I send a message to just one robot in a multi-model session?
**A:** Use @mention syntax: prefix the robot's name with `@` (e.g., `@tobor explain this`). Use `/robots` to see the active robots and their names. Only the mentioned robot responds; others stay silent.

### Q: Can I save my place in a conversation and return to it later?
**A:** Yes, use `/checkpoint name` to create a named checkpoint and `/restore name` to return to it. Use `/checkpoints` to list all checkpoints. `/clear` removes all history and checkpoints.

### Q: How do I clear chat history?
**A:** Use the `/clear` command or `/clear` directive:
```
You: /clear
```

## Troubleshooting

### Q: "Command not found: aia"
**A:**
1. Make sure Ruby's bin directory is in your PATH
2. Try reinstalling: `gem uninstall aia && gem install aia`
3. Check if using `--user-install`: `gem install aia --user-install`

### Q: "No models available" error
**A:**
1. Check your API keys are set correctly
2. Verify internet connection
3. Test with: `aia --available-models`

### Q: "Permission denied" errors
**A:**
1. Check file permissions: `ls -la ~/.prompts/`
2. Ensure prompts directory is readable
3. Check tool file permissions if using custom tools

### Q: Prompts are slow or timing out
**A:**
1. Try a faster model like `gpt-4o-mini`
2. Reduce prompt length or complexity
3. Check your internet connection
4. Use `--debug` to see what's happening

### Q: "Tool not found" errors
**A:**
1. Verify tool file paths with `--tools`
2. Check Ruby syntax in tool files
3. Use `--debug` to see tool loading details
4. Ensure tools inherit from `RubyLLM::Tool`

## Advanced Usage

### Q: How do I use AIA for code review?
**A:** Create a code review prompt:
```markdown
/config model gpt-4
/config temperature 0.3

Review this code for bugs, security issues, and best practices:
/include <%= file %>
```

### Q: Can I use AIA for data analysis?
**A:** Yes, create data analysis tools and prompts:
```bash
aia --tools data_analyzer.rb analyze_data dataset.csv
```

### Q: How do I integrate AIA into my development workflow?
**A:**
1. Create project-specific prompts
2. Use tools for code analysis
3. Set up workflows with pipelines
4. Use chat mode for interactive development

### Q: How do I backup my prompts?
**A:** Use version control:
```bash
cd ~/.prompts
git init
git add .
git commit -m "Initial prompt collection"
git remote add origin your-repo-url
git push -u origin main
```

## Getting Help

### Q: Where can I find more examples?
**A:** Check the [Examples](examples/index.md) directory for real-world use cases and templates.

### Q: How do I report bugs or request features?
**A:** Open an issue on GitHub: [https://github.com/MadBomber/aia/issues](https://github.com/MadBomber/aia/issues)

### Q: Is there a community or forum?
**A:** Check the GitHub repository for discussions and community contributions.

### Q: Where can I find the latest documentation?
**A:** The most up-to-date documentation is available in this docs site and the [GitHub repository](https://github.com/MadBomber/aia).

## Tips and Best Practices

### Q: What are some general best practices for prompts?
**A:**
1. Be specific and clear in your instructions
2. Provide necessary context and examples
3. Use appropriate models for different tasks
4. Organize prompts logically in directories
5. Version control your prompt collection

### Q: How do I optimize for performance?
**A:**
1. Choose the right model for each task
2. Use caching for expensive operations
3. Batch similar requests when possible
4. Monitor token usage and costs
5. Use shorter prompts when sufficient

### Q: Security considerations?
**A:**
1. Don't commit API keys to version control
2. Use environment variables for secrets
3. Be cautious with shell commands in prompts
4. Review tool permissions and access
5. Use restricted tool access in shared environments

## Troubleshooting

### Q: "Prompt not found" error
**A:** This usually means AIA can't locate your prompt file:
```bash
# Check prompts directory
ls $AIA_PROMPTS__DIR

# Verify prompt file exists
ls ~/.prompts/my_prompt.md

# Use fuzzy search to find available prompts
aia --fuzzy
```

### Q: Model errors or "Model not available"
**A:** Check your model name and availability:
```bash
# List available models
aia --available-models

# Check model name spelling
aia --model gpt-4o-mini  # Correct
aia --model gpt4         # Incorrect
```

### Q: Shell integration not working
**A:** Verify your shell patterns and permissions:
```bash
# Test shell patterns separately
echo "Test: $(date)"  # Should show current date
echo "Home: $HOME"    # Should show home directory

# Check if shell commands work in your environment
which date
which git
```

### Q: Configuration issues
**A:** Debug your configuration setup:
```bash
# Dump current configuration to a file for inspection
aia --dump config_snapshot.yml

# Test with verbose and debug output
aia --debug --verbose my_prompt
```

### Q: Performance issues with slow responses
**A:** Try these optimizations:
```bash
# Use faster models
aia --model gpt-4o-mini my_prompt

# Reduce max tokens
aia --max-tokens 1000 my_prompt

# Lower temperature for faster responses
aia --temperature 0.1 my_prompt
```

### Q: Large prompt processing issues
**A:** Break down large prompts:
```bash
# Use pipelines for multi-stage processing
aia --pipeline "analyze,summarize,report" large_data.csv

# Use selective file inclusion
/include specific_section.md

# Check model context limits
aia --available-models | grep context
```

### Q: Debug mode - how to get more information?
**A:** Enable debug output for detailed troubleshooting:
```bash
# Basic debug mode
aia --debug my_prompt

# Maximum debugging output
aia --debug --verbose my_prompt

# Dump configuration for inspection
aia --dump config_snapshot.yml
```

### Q: Common error messages and solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Prompt not found" | Missing prompt file | Check file exists and spelling |
| "Model not available" | Invalid model name | Use `--available-models` to list valid models |
| "Shell command failed" | Invalid shell syntax | Test shell commands separately first |
| "Configuration error" | Invalid config syntax | Check config file YAML syntax |
| "API key missing" | No API key configured | Set environment variables for your models |
| "Permission denied" | File/directory permissions | Check file permissions and ownership |

---

Don't see your question here? Check the [documentation](index.md) or [open an issue](https://github.com/MadBomber/aia/issues) on GitHub!
