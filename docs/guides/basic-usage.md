# Basic Usage

Learn the fundamental patterns and workflows for using AIA effectively in your daily tasks.

## Core Usage Patterns

### 1. Simple Prompt Execution
The most basic usage pattern - running a single prompt:

```bash
# Execute a prompt with context
aia my_prompt input_file.txt

# Execute without additional context
aia general_question
```

### 2. Model Selection
Choose the appropriate model for your task:

```bash
# Fast and economical for simple tasks
aia --model gpt-3.5-turbo quick_question

# High quality for complex analysis
aia --model gpt-4 complex_analysis data.csv

# Best for long documents
aia --model claude-3-sonnet document_review long_doc.pdf
```

### 3. Output Management
Control where and how AIA saves results:

```bash
# Save to file
aia --output result.md analysis_prompt data.csv

# Append to existing file
aia --output log.md --append status_check

# Format with markdown
aia --output report.md --markdown comprehensive_analysis
```

## Common Workflow Patterns

### Research and Analysis
Typical workflow for research tasks:

```bash
# Step 1: Gather information
aia information_gathering --topic "AI trends 2024" --sources "web,papers"

# Step 2: Analyze findings
aia trend_analysis --data research_output.md --focus "enterprise adoption"

# Step 3: Generate insights
aia insight_generation --analysis analysis_output.md --format "executive_summary"
```

### Code Review and Development
Standard development workflow:

```bash
# Code quality check
aia code_review src/main.py --focus "security,performance"

# Generate documentation
aia generate_docs --code src/ --format "markdown" --audience "developers"

# Create tests
aia test_generator --code src/main.py --framework "pytest" --coverage "comprehensive"
```

### Content Creation
Content development workflow:

```bash
# Research phase
aia content_research --topic "microservices architecture" --depth "comprehensive"

# Outline creation
aia create_outline --topic "microservices" --audience "developers" --length "3000 words"

# Content generation
aia write_content --outline outline.md --style "technical" --examples "include"
```

## Configuration Patterns

### Environment-Specific Configurations
Set up different configurations for different environments:

```yaml
# ~/.aia/dev_config.yml
model: gpt-3.5-turbo
temperature: 0.7
verbose: true
debug: true

# ~/.aia/prod_config.yml  
model: gpt-4
temperature: 0.3
verbose: false
debug: false
```

```bash
# Use environment-specific configs
aia --config-file ~/.aia/dev_config.yml development_task
aia --config-file ~/.aia/prod_config.yml production_analysis
```

### Task-Specific Model Selection
Choose models based on task characteristics:

```bash
# Creative tasks - higher temperature
aia --model gpt-4 --temperature 1.2 creative_writing

# Analysis tasks - lower temperature  
aia --model claude-3-sonnet --temperature 0.2 data_analysis

# Quick tasks - fast model
aia --model gpt-3.5-turbo --temperature 0.5 quick_summary
```

## File and Context Management

### Working with Multiple Files
Handle multiple input files effectively:

```bash
# Single file context
aia code_review main.py

# Multiple related files
aia architecture_review src/*.py

# Directory-based analysis
aia project_analysis ./src/ --recursive --include "*.py,*.rb"
```

### Context Preparation
Prepare context effectively for better results:

```bash
# Include relevant documentation
aia --include README.md,ARCHITECTURE.md code_review new_feature.py

# Add configuration context
aia --include config/database.yml,config/redis.yml deployment_review

# Include test context
aia --include tests/ code_quality_check src/
```

## Parameter and Variable Usage

### ERB Template Variables
Use variables to make prompts reusable:

```markdown
# ~/.prompts/parameterized_review.md
Review the <%= file_type %> file for <%= focus_areas %>:

File: /include <%= file_path %>

Provide <%= detail_level %> analysis with recommendations.
```

```bash
# Use with parameters
aia parameterized_review \
  --file_type "Python script" \
  --focus_areas "security and performance" \
  --file_path "app.py" \
  --detail_level "comprehensive"
```

### Environment Variable Integration
Use environment variables for dynamic configuration:

```bash
# Set environment-specific variables
export PROJECT_NAME="my-app"
export ENVIRONMENT="staging"
export REVIEW_FOCUS="security"

# Use in prompts
aia deployment_review --project "${PROJECT_NAME}" --env "${ENVIRONMENT}"
```

## Error Handling and Recovery

### Graceful Failure Handling
Handle common failure scenarios:

```bash
# Retry with different model on failure
aia --model gpt-4 analysis_task || aia --model claude-3-sonnet analysis_task

# Fallback to simpler approach
aia comprehensive_analysis data.csv || aia simple_analysis data.csv

# Debug mode for troubleshooting
aia --debug --verbose problematic_task
```

### Input Validation
Validate inputs before processing:

```bash
# Check file exists before processing
test -f input.csv && aia data_analysis input.csv || echo "Input file not found"

# Verify model availability
aia --available-models | grep -q "gpt-4" && aia --model gpt-4 task || aia task
```

## Performance Optimization

### Efficient Model Usage
Optimize for speed and cost:

```bash
# Use appropriate model for task complexity
aia --model gpt-3.5-turbo simple_tasks      # Fast and economical
aia --model gpt-4 complex_reasoning         # High quality when needed
aia --model claude-3-haiku batch_processing # Fast for large batches
```

### Batch Processing
Handle multiple similar tasks efficiently:

```bash
# Process multiple files
for file in *.py; do
  aia code_review "$file" --output "reviews/${file%.py}_review.md"
done

# Parallel processing
parallel -j4 aia analysis_task {} --output {.}_analysis.md ::: *.csv
```

### Caching and Reuse
Avoid redundant processing:

```bash
# Check if output exists before processing
output_file="analysis_$(date +%Y%m%d).md"
test -f "$output_file" || aia daily_analysis --output "$output_file"

# Reuse previous analysis
aia followup_analysis --previous_analysis yesterday_analysis.md
```

## Integration Patterns

### Shell Integration
Integrate AIA into shell workflows:

```bash
#!/bin/bash
# Automated analysis script

echo "Starting analysis..."
aia system_health_check --output health_$(date +%Y%m%d_%H%M).md

if [ $? -eq 0 ]; then
    echo "Health check complete"
    aia generate_report --source health_*.md --output daily_report.md
else
    echo "Health check failed, investigating..."
    aia troubleshoot_system --debug --verbose
fi
```

### Git Hooks Integration
Use AIA in Git workflows:

```bash
#!/bin/sh
# .git/hooks/pre-commit

# Review changed files before commit
changed_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(py|rb|js)$')

if [ -n "$changed_files" ]; then
    echo "Running AIA code review..."
    for file in $changed_files; do
        aia quick_code_review "$file" || exit 1
    done
fi
```

### CI/CD Integration
Integrate into continuous integration:

```yaml
# .github/workflows/aia-analysis.yml
name: AIA Code Analysis
on: [pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.1
      - name: Install AIA
        run: gem install aia
      - name: Run Analysis
        run: |
          aia pr_analysis --diff_only --output analysis.md
          cat analysis.md >> $GITHUB_STEP_SUMMARY
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

## Troubleshooting Common Issues

### Model and API Issues
```bash
# Test model availability
aia --available-models | grep "gpt-4" || echo "GPT-4 not available"

# Test API connection
aia --model gpt-3.5-turbo --debug simple_test_prompt

# Check API key
echo $OPENAI_API_KEY | cut -c1-10  # Show first 10 chars only
```

### File and Permission Issues
```bash
# Check file permissions
ls -la ~/.prompts/my_prompt.md
chmod 644 ~/.prompts/my_prompt.md

# Verify directory access
test -r ~/.prompts && echo "Prompts directory accessible" || echo "Permission issue"

# Check prompt syntax
aia --debug --dry-run my_prompt  # Dry run to check syntax
```

### Performance Issues
```bash
# Monitor token usage
aia --verbose --debug resource_intensive_task 2>&1 | grep -i token

# Profile execution time
time aia complex_analysis large_dataset.csv

# Use faster model for testing
aia --model gpt-3.5-turbo quick_test
```

## Essential Prompt Patterns

### The `run` Prompt Pattern

The `run` prompt is a configuration-only prompt that serves as a foundation for flexible AI interactions:

```bash
# ~/.prompts/run.md
# Desc: A configuration only prompt file for use with executable prompts
#       Put whatever you want here to setup the configuration desired.
#       You could also add a system prompt to preface your intended prompt

/config model = gpt-4o-mini
/config temperature = 0.7
/config terse = true
```

**Usage Examples:**
```bash
# Direct question via pipe
echo "What is the meaning of life?" | aia run

# File analysis
aia run my_code.py

# Multiple files
aia run *.txt

# With custom configuration
echo "Explain quantum computing" | aia run --model gpt-4 --temperature 1.0
```

### The Ad Hoc One-Shot Prompt

Perfect for quick questions without cluttering your prompt collection:

```bash
# ~/.prompts/ad_hoc.md
[WHAT_NOW_HUMAN]
```

**Usage:**
```bash
aia ad_hoc
# You'll be prompted: "Enter value for WHAT_NOW_HUMAN:"
# Type your question and get an instant response
```

### Recommended Shell Setup

Add these powerful aliases and functions to your shell configuration:

```bash
# ~/.bashrc_aia (or add to ~/.bashrc)
# Uses nested naming convention with double underscore
export AIA_PROMPTS__DIR=~/.prompts
export AIA_OUTPUT__FILE=./temp.md
export AIA_MODEL=gpt-4o-mini
export AIA_FLAGS__VERBOSE=true  # Shows spinner while waiting for LLM response

# Quick chat alias
alias chat='aia --chat --terse'

# Quick question function
ask() { echo "$1" | aia run --no-output; }
```

**Usage Examples:**
```bash
# Start quick chat
chat

# Ask quick questions
ask "How do I install Docker on Ubuntu?"
ask "What's the difference between REST and GraphQL?"
ask "Explain the MVC pattern"
```

## Best Practices Summary

### Model Selection
- Use `gpt-3.5-turbo` for simple, fast tasks
- Use `gpt-4` for complex reasoning and critical analysis
- Use `claude-3-sonnet` for long documents and detailed analysis
- Use `claude-3-haiku` for batch processing and quick tasks

### Prompt Organization
- Group related prompts in directories
- Use descriptive, consistent naming
- Include usage examples in prompt comments
- Version control your prompt collection

### Configuration Management
- Use environment variables for secrets
- Create environment-specific configs
- Document your configuration choices
- Test configurations in safe environments

### Performance Optimization
- Choose appropriate models for each task
- Use batch processing for similar tasks
- Cache results when appropriate
- Monitor usage and costs

## Related Documentation

- [Getting Started](getting-started.md) - Initial setup and first steps
- [Chat Mode](chat.md) - Interactive usage patterns
- [Working with Models](models.md) - Model selection strategies
- [Advanced Prompting](../advanced-prompting.md) - Complex usage patterns
- [Configuration](../configuration.md) - Detailed configuration options

---

Master these basic patterns first, then explore the advanced features as your needs grow!