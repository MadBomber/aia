# Executable Prompts

Transform your prompts into standalone executable scripts that can be run directly from the command line, integrated into shell workflows, and used as command-line tools.

## What Are Executable Prompts?

Executable prompts are prompt files with a special shebang line that makes them directly executable from the command line. They combine the power of AIA's prompt processing with the convenience of traditional shell scripts.

## Creating Executable Prompts

### Basic Structure

```bash
#!/usr/bin/env aia run --no-output --exec
# Your prompt description and comments

Your prompt content here...
```

### Key Components

1. **Shebang Line**: Must include `--exec` flag to enable prompt processing
2. **Output Configuration**: Use `--no-output` to send output to STDOUT
3. **Executable Permissions**: Make file executable with `chmod +x`

## The `run` Prompt Pattern

The `run` prompt is a special configuration-only prompt file that serves as a foundation for executable prompts:

### Creating the `run` Prompt

```bash
# ~/.prompts/run.txt
# Desc: A configuration only prompt file for use with executable prompts
#       Put whatever you want here to setup the configuration desired.
#       You could also add a system prompt to preface your intended prompt

//config model = gpt-4o-mini
//config temperature = 0.7
//config terse = true
```

### Usage Pattern

```bash
# Pipe questions directly to the run prompt
echo "What is the meaning of life?" | aia run
```

This pattern allows for quick one-shot questions without creating specific prompt files.

## Practical Examples

### Weather Report Script

Create a weather monitoring executable:

```bash
#!/usr/bin/env aia run --no-output --exec
# Get current storm activity for the east and south coast of the US

Summarize the tropical storm outlook for the Atlantic, Caribbean Sea and Gulf of America.

//webpage https://www.nhc.noaa.gov/text/refresh/MIATWOAT+shtml/201724_MIATWOAT.shtml
```

**Setup and Usage:**
```bash
# Save as weather_report
chmod +x weather_report

# Run directly
./weather_report

# Pipe to markdown viewer
./weather_report | glow
```

### System Status Monitor

```bash
#!/usr/bin/env aia run --no-output --exec
# System health check and analysis

Analyze the current system status and provide recommendations:

System Information:
//shell uname -a

Disk Usage:
//shell df -h

Memory Usage:
//shell free -h 2>/dev/null || vm_stat

Running Processes:
//shell ps aux | head -20

Provide analysis and recommendations for system optimization.
```

### Code Quality Checker

```bash
#!/usr/bin/env aia run --no-output --exec
# Analyze code quality for the current directory

//config model = gpt-4
//config temperature = 0.3

Review the code structure and quality in this project:

Project Structure:
//shell find . -type f -name "*.rb" -o -name "*.py" -o -name "*.js" | head -20

Git Status:
//shell git status --short 2>/dev/null || echo "Not a git repository"

Recent Commits:
//shell git log --oneline -10 2>/dev/null || echo "No git history available"

Provide code quality assessment and improvement recommendations.
```

### Daily Standup Generator

```bash
#!/usr/bin/env aia run --no-output --exec
# Generate daily standup report from git activity

//config model = gpt-4o-mini
//config temperature = 0.5

Generate a daily standup report based on recent git activity:

Yesterday's Commits:
//shell git log --since="1 day ago" --author="$(git config user.name)" --oneline

Current Branch Status:
//shell git status --short

Today's Focus:
Based on the above activity, what should be the key focus areas for today?
Provide a structured standup report.
```

## Advanced Executable Patterns

### Parameterized Executables

Create executable prompts that accept command-line parameters:

```bash
#!/usr/bin/env aia run --no-output --exec
# Code review for specific file
# Usage: ./code_review <filename>

//ruby
filename = ARGV[0] || "[FILENAME]"
puts "Reviewing file: #{filename}"
```

Review this code file for quality, security, and best practices:

//include <%= filename %>

Provide specific, actionable feedback for improvements.
```

### Pipeline Executables

Chain multiple prompts in an executable workflow:

```bash
#!/usr/bin/env aia run --no-output --exec
# Complete project analysis pipeline

//pipeline project_scan,security_check,recommendations

Starting comprehensive project analysis...
```

### Conditional Logic Executables

```bash
#!/usr/bin/env aia run --no-output --exec
# Environment-aware deployment checker

//ruby
environment = ENV['RAILS_ENV'] || 'development'
case environment
when 'production'
  puts "//config model = gpt-4"
  puts "//config temperature = 0.2"
  puts "Production deployment analysis:"
when 'staging'
  puts "//config model = gpt-4o-mini"
  puts "//config temperature = 0.4"
  puts "Staging deployment analysis:"
else
  puts "//config model = gpt-3.5-turbo"
  puts "//config temperature = 0.6"
  puts "Development deployment analysis:"
end
```

Environment: <%= environment %>

//shell env | grep -E "(DATABASE|REDIS|API)" | sort

Analyze the deployment configuration and provide environment-specific recommendations.
```

## Integration with Shell Workflows

### As Git Hooks

```bash
#!/usr/bin/env aia run --no-output --exec
# .git/hooks/pre-commit
# Automated commit message analysis

Analyze the staged changes and suggest improvements:

Staged Changes:
//shell git diff --cached --stat

//shell git diff --cached

Provide commit message suggestions and code quality feedback.
```

### In Makefiles

```makefile
# Makefile integration
analyze-code:
	@./scripts/code_analyzer

deploy-check:
	@./scripts/deployment_check | tee deploy-report.md

.PHONY: analyze-code deploy-check
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
      - uses: actions/checkout@v3
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
      - name: Install AIA
        run: gem install aia
      - name: Run Analysis
        run: ./scripts/pr_analyzer
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

## Best Practices for Executable Prompts

### Security Considerations

1. **Review Before Execution**: Always review executable prompts before running
2. **Limit Permissions**: Use appropriate file permissions
3. **Validate Inputs**: Check parameters and environment variables
4. **Avoid Secrets**: Never hardcode API keys or sensitive data

```bash
# Set secure permissions
chmod 750 executable_prompt    # Owner can execute, group can read
chmod 700 sensitive_prompt     # Owner only
```

### Error Handling

```bash
#!/usr/bin/env aia run --no-output --exec
# Robust executable with error handling

//ruby
if ARGV.empty?
  puts "Error: Please provide a filename as argument"
  puts "Usage: #{$0} <filename>"
  exit 1
end

filename = ARGV[0]
unless File.exist?(filename)
  puts "Error: File '#{filename}' not found"
  exit 1
end
```

File analysis for: <%= filename %>

//include <%= filename %>

Analyze the file structure, quality, and provide recommendations.
```

### Performance Optimization

```bash
# Use faster models for simple tasks
//config model = gpt-4o-mini

# Reduce token usage for executables
//config max_tokens = 1500

# Lower temperature for consistent results
//config temperature = 0.3
```

## Debugging Executable Prompts

### Enable Debug Mode

```bash
#!/usr/bin/env aia run --no-output --exec --debug --verbose
# Debug version of your executable prompt
```

### Test Components Separately

```bash
# Test the underlying prompt
aia run test_input.txt

# Test with debug output
aia --debug run test_input.txt

# Test shell commands separately
date
git status
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Permission denied" | File not executable | `chmod +x filename` |
| "Command not found" | Missing shebang or wrong path | Check shebang line |
| "Prompt not found" | Missing run prompt | Create ~/.prompts/run.txt |
| "Output not appearing" | Missing --no-output | Add flag to shebang |

## Advanced Executable Patterns

### Self-Documenting Executables

```bash
#!/usr/bin/env aia run --no-output --exec
# Self-documenting code analyzer
# Usage: ./code_analyzer [--help] <directory>

//ruby
if ARGV.include?('--help')
  puts <<~HELP
    Code Analyzer - AI-powered code quality assessment
    
    Usage: #{$0} <directory>
    
    Options:
      --help    Show this help message
    
    Examples:
      #{$0} ./src
      #{$0} /path/to/project
  HELP
  exit 0
end
```

### Multi-Stage Executables

```bash
#!/usr/bin/env aia run --no-output --exec
# Multi-stage project analysis

//ruby
stages = %w[structure security performance documentation]
current_stage = ENV['STAGE'] || stages.first

puts "=== Stage #{stages.index(current_stage) + 1}: #{current_stage.capitalize} ==="

case current_stage
when 'structure'
  puts "//pipeline structure_analysis,security_check"
when 'security' 
  puts "//pipeline security_scan,vulnerability_check"
when 'performance'
  puts "//pipeline performance_analysis,optimization_suggestions"
when 'documentation'
  puts "//pipeline doc_analysis,improvement_suggestions"
end
```

## Related Documentation

- [Getting Started](getting-started.md) - Basic AIA usage
- [Basic Usage](basic-usage.md) - Common usage patterns  
- [CLI Reference](../cli-reference.md) - Command-line options
- [Advanced Prompting](../advanced-prompting.md) - Complex prompt techniques and shell integration

---

Executable prompts transform AIA from a tool into a platform for creating AI-powered command-line utilities. Start with simple executables and gradually build more sophisticated tools as you become comfortable with the patterns!