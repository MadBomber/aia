# Development Prompts

Collection of prompts for software development tasks.

## Available Prompts

### Code Review
- **code_review.md** - Comprehensive code analysis and review
- **security_review.md** - Security-focused code review
- **performance_review.md** - Performance analysis and optimization

### Documentation
- **generate_docs.md** - Generate code documentation
- **api_docs.md** - API documentation generation
- **readme_generator.md** - README file creation

### Debugging
- **debug_analysis.md** - Systematic bug analysis
- **error_investigation.md** - Error investigation and resolution
- **performance_debug.md** - Performance issue diagnosis

### Architecture
- **architecture_analysis.md** - System architecture review
- **design_patterns.md** - Design pattern recommendations
- **refactoring_guide.md** - Code refactoring suggestions

### Testing
- **test_strategy.md** - Test strategy development
- **unit_test_generator.md** - Unit test creation
- **integration_testing.md** - Integration test planning

## Usage Examples

```bash
# Basic code review
aia code_review my_file.py

# Security-focused review
aia security_review --severity high auth_module.rb

# Generate comprehensive documentation
aia generate_docs --format markdown src/
```

## Detailed Example Prompts

### Code Review Prompt
```bash
# ~/.prompts/code_review.md
/config model gpt-4o-mini
/config temperature 0.3

Review this code for:
- Best practices adherence
- Security vulnerabilities
- Performance issues
- Maintainability concerns

Code to review:
```

**Usage:** `aia code_review mycode.rb`

### Meeting Notes Processor
```bash
# ~/.prompts/meeting_notes.md
/config model gpt-4o-mini
/pipeline format,action_items

Raw meeting notes:
/include [NOTES_FILE]

Please clean up and structure these meeting notes.
```

**Usage:** `aia meeting_notes raw_notes.txt`

### Documentation Generator  
```bash
# ~/.prompts/document.md
/config model gpt-4o-mini
/shell find [PROJECT_DIR] -name "*.rb" | head -10

Generate documentation for the Ruby project shown above.
Include: API references, usage examples, and setup instructions.
```

**Usage:** `aia document --PROJECT_DIR ./my_project`

### Multi-Model Decision Making
```bash
# ~/.prompts/decision_maker.md
# Compare different AI perspectives on complex decisions

What are the pros and cons of [DECISION_TOPIC]?
Consider: technical feasibility, business impact, risks, and alternatives.

Analyze this thoroughly and provide actionable recommendations.
```

**Usage Examples:**
```bash
# Get individual perspectives from each model
aia decision_maker --model "gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini" --no-consensus

# Get a synthesized consensus recommendation  
aia decision_maker --model "gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini" --consensus

# Use with chat mode for follow-up questions
aia --chat --model "gpt-4o-mini,gpt-3.5-turbo" --consensus
```

## Customization

These prompts can be customized with parameters:
- `--model` - Choose appropriate AI model
- `--temperature` - Adjust creativity level
- `--severity` - Focus level for reviews
- `--format` - Output format preference

## Related

- [Tools Examples](../../tools/index.md) - Development tools
- [Analysis Prompts](../analysis/index.md) - Data analysis prompts
- [Automation Prompts](../automation/index.md) - Process automation