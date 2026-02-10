# Prompt Examples

This collection contains real-world prompt examples organized by category and complexity level.

## Categories

### [Development](development/index.md)
Prompts for software development tasks:
- **Code Review**: Quality analysis and improvement suggestions
- **Documentation**: Generate comprehensive code documentation
- **Debugging**: Systematic problem diagnosis and resolution
- **Architecture**: System design analysis and recommendations
- **Testing**: Test strategy and implementation guidance

### [Writing](writing/index.md)
Content creation and editing prompts:
- **Technical Writing**: API docs, tutorials, technical guides
- **Blog Posts**: Engaging technical and general content
- **Creative Writing**: Stories, poetry, creative projects
- **Editing**: Content improvement and style refinement
- **Marketing**: Copy, descriptions, promotional content

### [Analysis](analysis/index.md)
Data analysis and research prompts:
- **Data Analysis**: Statistical analysis and insights
- **Research**: Literature review and synthesis
- **Reports**: Structured analysis and recommendations
- **Comparison**: Competitive analysis and evaluation
- **Trends**: Pattern recognition and forecasting

### [Automation](automation/index.md)
System administration and automation prompts:
- **System Monitoring**: Health checks and diagnostics
- **Deployment**: Release and deployment workflows
- **Log Analysis**: System log interpretation
- **Maintenance**: Routine system maintenance tasks
- **Alerting**: Notification and response templates

### [Learning](learning/index.md)
Educational and knowledge acquisition prompts:
- **Concept Explanation**: Complex topic simplification
- **Tutorial Creation**: Step-by-step learning guides
- **Quiz Generation**: Assessment and evaluation tools
- **Research Assistance**: Academic and professional research
- **Skill Development**: Practice exercises and challenges

## Complexity Levels

### Basic
- Simple, single-purpose prompts
- Minimal configuration required
- Clear, straightforward outputs
- Great for learning AIA basics

### Intermediate
- Multi-step workflows
- Dynamic configuration
- Context-aware processing
- Suitable for regular use

### Advanced
- Complex multi-stage pipelines
- Extensive use of directives
- Tool and MCP integration
- Production-ready workflows

## Using These Examples

### 1. Copy to Your Prompts Directory
```bash
# Copy individual prompts
cp docs/examples/prompts/development/code_review.md ~/.prompts/

# Copy entire categories
cp -r docs/examples/prompts/development/ ~/.prompts/

# Copy all examples
cp -r docs/examples/prompts/* ~/.prompts/
```

### 2. Customize for Your Needs
Each prompt includes customization sections:
- **Parameters**: Variables you can adjust
- **Configuration**: Settings to modify
- **Extensions**: How to add functionality
- **Variations**: Alternative approaches

### 3. Run Examples
```bash
# Basic usage
aia code_review my_file.py

# With customization
aia --model gpt-4 --temperature 0.3 code_review my_file.py

# In workflows
aia --pipeline "code_review,optimize,test" my_project/
```

## Featured Examples

### Code Review Prompt
**File**: `development/code_review.md`
```markdown
/config model gpt-4
/config temperature 0.3

# Code Review Analysis

Review the following code for:
- **Bugs**: Logic errors, edge cases, potential crashes
- **Security**: Vulnerabilities, input validation, data exposure
- **Performance**: Efficiency, scalability, resource usage
- **Style**: Conventions, readability, maintainability
- **Best Practices**: Design patterns, industry standards

## Code to Review:
/include <%= file %>

## Review Format:
Provide your analysis in the following structure:

### Summary
Brief overall assessment and rating (1-10).

### Issues Found
List specific problems with severity levels:
- 🔴 **Critical**: Security vulnerabilities, crashes
- 🟠 **Major**: Performance issues, bugs
- 🟡 **Minor**: Style, minor improvements

### Recommendations
Concrete suggestions for improvement with code examples where applicable.

### Positive Aspects
Highlight what's done well in the code.
```

### Blog Post Generator
**File**: `writing/blog_post.md`
```markdown
/config model gpt-4
/config temperature 1.0
/config max_tokens 3000

# Technical Blog Post Generator

Create an engaging, well-structured blog post about: **<%= topic %>**

## Requirements:
- **Target Audience**: <%= audience || "Software developers" %>
- **Word Count**: <%= word_count || "1000-1500 words" %>
- **Tone**: <%= tone || "Professional but approachable" %>
- **Include Code Examples**: <%= code_examples || "Yes" %>

## Context:
<% if context_file %>
/include <%= context_file %>
<% end %>

## Structure:
1. **Hook**: Engaging opening that grabs attention
2. **Introduction**: Problem statement and article overview
3. **Main Content**: 3-4 major sections with headers
4. **Code Examples**: Practical, runnable code samples
5. **Best Practices**: Key takeaways and recommendations
6. **Conclusion**: Summary and call-to-action

## Style Guidelines:
- Use clear, concise language
- Include practical examples
- Add subheadings for readability
- Include relevant links and resources
- End with actionable next steps

Please ensure the post is SEO-friendly with good header structure and includes relevant keywords naturally.
```

### Data Analysis Workflow
**File**: `analysis/data_pipeline.md`
```markdown
/config model claude-3-sonnet
/config temperature 0.2

# Data Analysis Pipeline

Analyze the provided dataset and generate comprehensive insights.

## Dataset Information:
/shell head -5 <%= dataset_file %>
/shell wc -l <%= dataset_file %>
/shell file <%= dataset_file %>

## Analysis Steps:

### 1. Data Overview
- Examine data structure and types
- Identify columns and their meanings
- Note data quality issues

### 2. Descriptive Statistics
- Calculate summary statistics
- Identify distributions and outliers
- Examine correlations

### 3. Data Quality Assessment
- Missing values analysis
- Duplicate detection
- Inconsistency identification

### 4. Key Insights
- Significant patterns and trends
- Interesting correlations
- Anomalies or outliers

### 5. Recommendations
- Data cleaning suggestions
- Further analysis opportunities
- Actionable business insights

## Data Sample:
/include <%= dataset_file %>

Please provide a thorough analysis with specific findings and quantitative metrics where possible.
```

## Prompt Design Patterns

### Parameterization Pattern
Make prompts reusable with variables:
```markdown
/config model <%= model || "gpt-4" %>
/config temperature <%= temperature || "0.7" %>

Task: <%= task_description %>
Context: <%= context || "General" %>
Output Format: <%= format || "Markdown" %>
```

### Conditional Inclusion Pattern
Include different content based on conditions:
```markdown
<% if File.exist?('production.yml') %>
/include production.yml
<% else %>
/include development.yml
<% end %>

<% if ENV['DETAILED_ANALYSIS'] == 'true' %>
Provide detailed technical analysis.
<% else %>
Provide summary analysis.
<% end %>
```

### Multi-Stage Pipeline Pattern
Chain related prompts together:
```markdown
/next data_cleaning
/pipeline analysis,visualization,reporting

Initial data processing completed.
Ready for next stage: <%= next_stage %>
```

### Tool Integration Pattern
Incorporate external tools:
```markdown
# Get a list of tools that are available
/tools

Using advanced analysis tools:

# Tell the LLM which tool to use and its arguments
use the examine_data tool to review this file '<%= data_file %>')
```

## Validation and Testing

### Testing Your Prompts
1. **Syntax Check**: Verify directive syntax
2. **Parameter Testing**: Test with different inputs
3. **Output Validation**: Ensure consistent, quality outputs
4. **Performance Testing**: Check response times and costs
5. **Edge Case Testing**: Handle unusual inputs gracefully

### Example Test Scripts
```bash
# Test basic functionality
aia --debug code_review test_file.py

# Test with different models
for model in gpt-3.5-turbo gpt-4 claude-3-sonnet; do
  echo "Testing with $model"
  aia --model $model code_review test_file.py
done

# Test parameter variations
aia code_review --file test1.py --severity high
aia code_review --file test2.py --severity low
```

## Best Practices

### Prompt Structure
1. **Clear Instructions**: Specific, actionable directions
2. **Context Setting**: Provide necessary background
3. **Output Format**: Specify desired response structure
4. **Examples**: Include sample inputs/outputs when helpful
5. **Error Handling**: Account for edge cases

### Configuration Management
1. **Model Selection**: Choose appropriate models for tasks
2. **Temperature Setting**: Adjust creativity vs. consistency
3. **Token Limits**: Balance completeness with cost
4. **Parameter Validation**: Ensure required inputs are provided

### Maintenance
1. **Version Control**: Track prompt changes
2. **Documentation**: Keep usage instructions current
3. **Performance Monitoring**: Track effectiveness over time
4. **User Feedback**: Incorporate user suggestions

## Related Documentation

- [Directives Reference](../../directives-reference.md) - All available directives
- [CLI Reference](../../cli-reference.md) - Command-line options
- [Advanced Prompting](../../advanced-prompting.md) - Expert techniques
- [Configuration](../../configuration.md) - Setup and customization

---

Explore the specific categories to find prompts that match your needs, or use these as inspiration to create your own custom prompts!
