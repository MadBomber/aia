# Frequently Asked Questions

Common questions and answers about using AIA.

## Installation and Setup

### Q: What Ruby version is required for AIA?
**A:** AIA requires Ruby 3.0 or higher. You can check your Ruby version with `ruby --version`.

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
**A:** Yes, if you use local models through Ollama. Most AI models require internet access, but you can run models locally for offline use.

## Basic Usage

### Q: How do I create my first prompt?
**A:** Create a text file in your prompts directory:
```bash
echo "Explain this code clearly:" > ~/.prompts/explain_code.txt
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
**A:** The main configuration file is at `~/.aia/config.yml`. You can create it if it doesn't exist.

### Q: How do I change the default AI model?
**A:** Set it in your configuration file or use the command line:
```bash
# In config file
model: gpt-4

# Command line
aia --model gpt-4 my_prompt
```

### Q: How do I set a custom prompts directory?
**A:** Use the `--prompts_dir` option or set it in configuration:
```bash
# Command line
aia --prompts_dir /path/to/prompts my_prompt

# Environment variable
export AIA_PROMPTS_DIR="/path/to/prompts"
```

## Prompts and Directives

### Q: What are directives and how do I use them?
**A:** Directives are special commands in prompts that start with `//`. Examples:
```markdown
//config model gpt-4
//include my_file.txt
//shell ls -la
```

See the [Directives Reference](directives-reference.md) for all available directives.

### Q: How do I include files in prompts?
**A:** Use the `//include` directive:
```markdown
//include README.md
//include /path/to/file.txt
```

### Q: Can I use Ruby code in prompts?
**A:** Yes, use the `//ruby` directive:
```markdown
//ruby puts "Hello, #{ENV['USER']}!"
//ruby Time.now.strftime("%Y-%m-%d")
```

### Q: How do I create prompt workflows?
**A:** Use the `//pipeline` or `//next` directives:
```markdown
//pipeline "step1,step2,step3"
//next next_prompt_id
```

## Models and Performance

### Q: Which AI model should I use?
**A:** It depends on your needs:
- **GPT-3.5 Turbo**: Fast, cost-effective for simple tasks
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
- Choose appropriate models (GPT-3.5 for simple tasks)
- Use temperature settings wisely
- Clear chat context regularly with `//clear`

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
**A:** Use the `/save` command within chat:
```
You: /save conversation.md
```

### Q: Can I use tools in chat mode?
**A:** Yes, enable tools when starting chat:
```bash
aia --chat --tools ./tools/
```

### Q: How do I clear chat history?
**A:** Use the `/clear` command or `//clear` directive:
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
3. Test with: `aia --available_models`

### Q: "Permission denied" errors
**A:**
1. Check file permissions: `ls -la ~/.prompts/`
2. Ensure prompts directory is readable
3. Check tool file permissions if using custom tools

### Q: Prompts are slow or timing out
**A:**
1. Try a faster model like `gpt-3.5-turbo`
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
//config model gpt-4
//config temperature 0.3

Review this code for bugs, security issues, and best practices:
//include <%= file %>
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
ls $AIA_PROMPTS_DIR

# Verify prompt file exists
ls ~/.prompts/my_prompt.txt

# Use fuzzy search to find available prompts
aia --fuzzy
```

### Q: Model errors or "Model not available"
**A:** Check your model name and availability:
```bash
# List available models
aia --available_models

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
# Check current configuration
aia --config

# Debug configuration loading
aia --debug --config

# Test with verbose output
aia --debug --verbose my_prompt
```

### Q: Performance issues with slow responses
**A:** Try these optimizations:
```bash
# Use faster models
aia --model gpt-4o-mini my_prompt

# Reduce max tokens
aia --max_tokens 1000 my_prompt

# Lower temperature for faster responses
aia --temperature 0.1 my_prompt
```

### Q: Large prompt processing issues
**A:** Break down large prompts:
```bash
# Use pipelines for multi-stage processing
aia --pipeline "analyze,summarize,report" large_data.csv

# Use selective file inclusion
//include specific_section.txt

# Check model context limits
aia --available_models | grep context
```

### Q: Debug mode - how to get more information?
**A:** Enable debug output for detailed troubleshooting:
```bash
# Basic debug mode
aia --debug my_prompt

# Maximum debugging output
aia --debug --verbose my_prompt

# Check configuration in debug mode
aia --debug --config
```

### Q: Common error messages and solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Prompt not found" | Missing prompt file | Check file exists and spelling |
| "Model not available" | Invalid model name | Use `--available_models` to list valid models |
| "Shell command failed" | Invalid shell syntax | Test shell commands separately first |
| "Configuration error" | Invalid config syntax | Check config file YAML syntax |
| "API key missing" | No API key configured | Set environment variables for your models |
| "Permission denied" | File/directory permissions | Check file permissions and ownership |

---

Don't see your question here? Check the [documentation](index.md) or [open an issue](https://github.com/MadBomber/aia/issues) on GitHub!