# Executable Prompts

Transform your prompts into standalone executable scripts that can be run directly from the command line, integrated into shell workflows, and used as command-line tools. You can also pipe or redirect any prompt file to AIA without making it executable.

## What Are Executable Prompts?

Executable prompts are prompt files with a shebang line (`#!`) and executable permission (`chmod +x`) that can be run directly from the command line. When you run an executable prompt, AIA strips the shebang, parses YAML front matter for configuration, processes directives, and sends the body to the AI model.

Any prompt file can also be piped or redirected to AIA without a shebang line or executable permission — see [Piping and Redirection](#piping-and-redirection) below.

## Creating Executable Prompts

### Basic Structure

```markdown
#!/usr/bin/env aia --no-output
---
description: What this prompt does
---
Your prompt content here...
```

### Key Components

1. **Shebang Line**: `#!/usr/bin/env aia` followed by any AIA CLI options
2. **YAML Front Matter** (optional): Configuration between `---` delimiters
3. **Prompt Body**: The actual text sent to the AI model
4. **Executable Permission**: `chmod +x your_prompt.md`

### Minimal Example

```markdown
#!/usr/bin/env aia --no-output
Tell me today's date and what historical events occurred on this day.
```

Save as `daily_history`, make executable, and run:

```bash
chmod +x daily_history
./daily_history
```

## Shebang Options

The shebang line accepts any AIA CLI option. Common patterns:

```bash
#!/usr/bin/env aia --no-output                    # Output to STDOUT
#!/usr/bin/env aia --no-output --no-mcp           # No MCP servers
#!/usr/bin/env aia --no-output -m claude-sonnet-4  # Specific model
#!/usr/bin/env aia -o report.md                   # Output to file
#!/usr/bin/env aia --no-output --chat             # Start chat after prompt
```

## Adding CLI Options at Runtime

When running an executable prompt, you can append additional AIA options:

```bash
# Run with defaults from the shebang
./weather_report

# Override the model
./weather_report -m gpt-4

# Add verbose output
./weather_report --verbose

# Disable MCP servers for this run
./weather_report --no-mcp

# Send output to a file instead of STDOUT
./weather_report -o weather.md
```

Options specified at runtime override those in the shebang line.

## YAML Front Matter

Use front matter for prompt metadata and configuration:

```markdown
#!/usr/bin/env aia --no-output
---
description: Analyze code quality
model: claude-sonnet-4
temperature: 0.3
---
Review the following code for quality, security, and best practices.
```

Supported front matter keys include `model`, `temperature`, `top_p`, `next`, `pipeline`, `shell`, and `erb`. See [Configuration](../configuration.md) for details.

## Piping and Redirection

Prompt files do not need a shebang line or executable permission to be processed by AIA. Any prompt file — plain text, YAML front matter, ERB, directives — can be piped or redirected directly:

### Pipe a Prompt File

```bash
cat my_prompt.md | aia --no-output
cat my_prompt.md | aia --no-output --no-mcp
cat my_prompt.md | aia --no-output -m gpt-4
```

### STDIN Redirection

```bash
aia --no-output < my_prompt.md
aia --no-output --no-mcp < my_prompt.md
```

### Inline Prompts

```bash
echo "Explain the theory of relativity in one paragraph." | aia --no-output
```

When content is piped or redirected, AIA automatically detects it and processes it as the prompt — no prompt ID argument is needed. The shebang line is only required when making a file directly executable with `chmod +x`. If piped content happens to start with a shebang line (`#!`), that line is stripped before processing.

## Practical Examples

### Weather Report

```markdown
#!/usr/bin/env aia --no-output
---
description: Atlantic storm activity summary
model: gpt-4o-mini
temperature: 0.3
---
Summarize the tropical storm outlook for the Atlantic, Caribbean Sea and
Gulf of America.

/webpage https://www.nhc.noaa.gov/text/refresh/MIATWOAT+shtml/MIATWOAT.shtml
```

### System Status Monitor

```markdown
#!/usr/bin/env aia --no-output
---
description: System health check
temperature: 0.3
---
Analyze the current system status and provide recommendations:

System Information:
<%= `uname -a` %>

Disk Usage:
<%= `df -h` %>

Top Processes:
<%= `ps aux | head -20` %>

Provide analysis and recommendations for system optimization.
```

### Daily Standup Generator

```markdown
#!/usr/bin/env aia --no-output
---
description: Generate standup report from git activity
model: gpt-4o-mini
temperature: 0.5
---
Generate a daily standup report based on recent git activity:

Yesterday's Commits:
<%= `git log --since="1 day ago" --author="$(git config user.name)" --oneline` %>

Current Branch Status:
<%= `git status --short` %>

Based on the above activity, what should be the key focus areas for today?
Provide a structured standup report.
```

### Code Quality Checker

```markdown
#!/usr/bin/env aia --no-output
---
description: Analyze code quality for the current directory
model: gpt-4
temperature: 0.3
---
Review the code structure and quality in this project:

Project Structure:
<%= `find . -type f -name "*.rb" -o -name "*.py" -o -name "*.js" | head -20` %>

Git Status:
<%= `git status --short 2>/dev/null || echo "Not a git repository"` %>

Recent Commits:
<%= `git log --oneline -10 2>/dev/null || echo "No git history available"` %>

Provide code quality assessment and improvement recommendations.
```

## Integration with Shell Workflows

### Piping Output

```bash
# Pipe to a markdown viewer
./weather_report | glow

# Save and view
./code_review > review.md && open review.md

# Chain with other tools
./summarize_logs | mail -s "Daily Summary" team@example.com
```

### In Makefiles

```makefile
analyze-code:
	@./scripts/code_analyzer

deploy-check:
	@./scripts/deployment_check | tee deploy-report.md

.PHONY: analyze-code deploy-check
```

### As Git Hooks

```markdown
#!/usr/bin/env aia --no-output
---
description: Pre-commit code review
temperature: 0.2
---
Analyze the staged changes and suggest improvements:

Staged Changes:
<%= `git diff --cached --stat` %>

<%= `git diff --cached` %>

Provide commit message suggestions and code quality feedback.
```

```bash
# Install as git hook
cp pre_commit_review .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### In CI/CD Pipelines

```yaml
# .github/workflows/ai-analysis.yml
name: AI Code Analysis
on: [pull_request]

jobs:
  analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
      - run: gem install aia
      - name: Run Analysis
        run: cat ./prompts/pr_analyzer.md | aia --no-output --no-mcp
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

## Best Practices

### Security

1. **Review Before Execution**: Always review executable prompts before running
2. **Limit Permissions**: Use appropriate file permissions
3. **Avoid Secrets**: Never hardcode API keys or sensitive data

```bash
chmod 750 executable_prompt    # Owner can execute, group can read
chmod 700 sensitive_prompt     # Owner only
```

### Performance

Use YAML front matter to tune model parameters:

```yaml
---
model: gpt-4o-mini       # Faster model for simple tasks
temperature: 0.3         # Lower temperature for consistent results
---
```

### Debugging

Add `--debug` or `--verbose` at runtime to troubleshoot:

```bash
./my_prompt --debug --verbose
```

Or pipe with debug flags:

```bash
cat my_prompt.md | aia --no-output --debug --verbose
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Permission denied" | File not executable | `chmod +x filename` |
| "Command not found" | AIA not in PATH | Check `gem install aia` |
| Output goes to temp.md | Missing `--no-output` | Add to shebang or CLI |
| Shebang options ignored | Too many shebang args | Use `#!/usr/bin/env -S aia ...` on Linux |

## Related Documentation

- [Getting Started](getting-started.md) - Basic AIA usage
- [Basic Usage](basic-usage.md) - Common usage patterns
- [CLI Reference](../cli-reference.md) - Command-line options
- [Directives Reference](../directives-reference.md) - Available directives
- [Advanced Prompting](../advanced-prompting.md) - Complex prompt techniques
