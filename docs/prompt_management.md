# Prompt Management

AIA provides sophisticated prompt management capabilities through the PM gem, enabling you to organize, version, and efficiently use large collections of prompts.

## Directory Structure

### Default Structure
```
~/.prompts/
├── README.md                    # Documentation for your prompt collection
├── roles/                       # Role-based prompts for context setting
│   ├── assistant.md
│   ├── code_expert.md
│   └── teacher.md
├── development/                 # Development-related prompts
│   ├── code_review.md
│   ├── debug_help.md
│   └── documentation.md
├── writing/                     # Content creation prompts
│   ├── blog_post.md
│   ├── technical_docs.md
│   └── creative_writing.md
├── analysis/                    # Data and research analysis
│   ├── data_analysis.md
│   ├── research_summary.md
│   └── report_generation.md
└── workflows/                   # Multi-step prompt sequences
    ├── code_pipeline.md
    ├── content_pipeline.md
    └── analysis_pipeline.md
```

### Custom Structure
```bash
# Set custom prompts directory (uses nested naming convention)
export AIA_PROMPTS__DIR="/path/to/custom/prompts"
aia --prompts-dir /path/to/custom/prompts

# Use project-specific prompts
aia --prompts-dir ./project_prompts my_prompt
```

## Prompt File Formats

### Basic Text Prompts
```markdown
# ~/.prompts/simple_question.md
Please answer this question clearly and concisely:

<%= question %>

Provide examples where helpful.
```

### Prompts with Directives
```markdown
# ~/.prompts/code_analysis.md
/config model gpt-4
/config temperature 0.3

# Code Analysis and Review

Analyze the following code for:
- Security vulnerabilities
- Performance issues  
- Best practice violations
- Potential bugs

## Code to Review:
/include <%= file %>

Provide specific recommendations with code examples.
```

### ERB Template Prompts
```erb
# ~/.prompts/blog_post_generator.md
/config model <%= model || "gpt-4" %>
/config temperature <%= creativity || "0.8" %>
/config max_tokens <%= length || "2000" %>

# Blog Post: <%= title %>

Write a <%= tone || "professional" %> blog post about <%= topic %>.

Target audience: <%= audience || "general" %>
Word count: <%= word_count || "1000-1500" %> words

<% if include_seo %>
Include SEO-friendly headings and meta description.
<% end %>

<% if code_examples %>
Include practical code examples where relevant.
<% end %>

Structure:
1. Engaging introduction
2. Main content with clear sections
3. Actionable takeaways
4. Compelling conclusion
```

### Executable Prompts
```markdown
# ~/.prompts/system_report.md
/config executable true
/shell hostname
/shell uptime
/shell df -h
/shell free -h
/shell ps aux | head -10

System Status Report
===================

Please analyze this system information and provide:
1. Overall system health assessment
2. Potential issues or concerns
3. Recommendations for optimization
4. Any immediate actions needed
```

## Prompt Discovery and Search

### Basic Search
```bash
# List all prompts
aia --prompts-dir ~/.prompts

# Search by pattern
find ~/.prompts -name "*code*" -type f

# Search content
grep -r "code review" ~/.prompts/
```

### Fuzzy Search (with fzf)
```bash
# Interactive prompt selection
aia --fuzzy

# This opens an interactive interface showing:
# - Prompt names and paths
# - Recent usage
# - Preview of prompt content
```

### Advanced Search
```bash
# Search by category
aia --fuzzy development/

# Search by role
aia --fuzzy roles/

# Search in specific subdirectory
aia --prompts-dir ~/.prompts/analysis --fuzzy
```

## Prompt Organization Strategies

### By Domain/Category
```
~/.prompts/
├── software_development/
├── data_science/
├── content_creation/
├── business_analysis/
└── personal/
```

### By Complexity
```
~/.prompts/
├── quick_tasks/          # Simple, fast prompts
├── standard_workflows/   # Regular multi-step processes
├── complex_analysis/     # Deep analysis prompts
└── specialized/          # Domain-specific expert prompts
```

### By Model Type
```
~/.prompts/
├── gpt4_prompts/         # Prompts optimized for GPT-4
├── claude_prompts/       # Prompts optimized for Claude
├── vision_prompts/       # Prompts for vision models
└── code_prompts/         # Prompts for code models
```

### By Workflow Stage
```
~/.prompts/
├── input_processing/     # Initial data/content processing
├── analysis/            # Analysis and evaluation
├── generation/          # Content/code generation
├── review/             # Quality review and validation
└── finalization/       # Final output formatting
```

## Parameterized Prompts

### ERB Variables
```erb
# ~/.prompts/parameterized_analysis.md
/config model <%= model || "gpt-4" %>

Analyze <%= subject %> focusing on <%= focus_area %>.

<% if detailed %>
Provide comprehensive analysis including:
- Background context
- Detailed findings
- Implications and recommendations
<% else %>
Provide a concise summary of key findings.
<% end %>

Context:
/include <%= context_file if context_file %>
```

### Usage with Parameters
```bash
# Pass parameters via environment or command line
export subject="market trends"
export focus_area="growth opportunities"
export detailed="true"
aia parameterized_analysis

# Or using AIA's parameter system
aia parameterized_analysis --subject "user behavior" --focus_area "conversion rates"
```

### Parameter Extraction
```bash
# Use regex to extract parameters from prompts
aia --regex '\{\{(\w+)\}\}' template_prompt
aia --regex '<%=\s*(\w+)\s*%>' erb_prompt
```

## Roles and Context

### Role Definitions
```markdown
# ~/.prompts/roles/software_architect.md
You are a senior software architect with 15+ years of experience designing scalable systems.

Your expertise includes:
- Microservices architecture
- Cloud-native design patterns
- Performance optimization
- Security best practices
- Team leadership and mentoring

When providing advice:
- Consider scalability and maintainability
- Suggest industry best practices
- Provide concrete architectural examples
- Address potential trade-offs
- Consider operational aspects

Communicate in a professional but approachable manner, suitable for both senior and junior developers.
```

### Using Roles
```bash
# Apply role to prompt
aia --role software_architect system_design

# Role with specific prompts
aia --role code_expert code_review main.py

# Custom roles directory
aia --roles-prefix personas --role mentor learning_session
```

### Context Layering
```markdown
# ~/.prompts/layered_context.md
/include roles/<%= role || "assistant" %>.md

/config model <%= model || "gpt-4" %>

Project Context:
/include README.md
/include ARCHITECTURE.md

Current Task:
<%= task_description %>

Please provide guidance consistent with the project architecture and your role as <%= role %>.
```

## Prompt Workflows and Pipelines

### Simple Workflows
```markdown
# ~/.prompts/data_workflow_start.md
/next data_cleaning
/pipeline analysis,visualization,reporting

Begin data processing workflow for: <%= dataset %>

Initial data examination:
/shell head -10 <%= dataset %>
/shell wc -l <%= dataset %>

Proceed to data cleaning stage.
```

### Complex Pipelines
```bash
# Multi-stage analysis pipeline
aia --pipeline "extract_data,validate_data,analyze_patterns,generate_insights,create_report" dataset.csv
```

### Conditional Workflows
```ruby
# ~/.prompts/adaptive_workflow.md
/ruby
data_size = File.size('<%= input_file %>')
complexity = data_size > 1000000 ? 'complex' : 'simple'

if complexity == 'complex'
  puts "/pipeline prepare_data,chunk_processing,merge_results,final_analysis"
else
  puts "/pipeline quick_analysis,summary_report"  
end

puts "Selected #{complexity} workflow for #{data_size} byte dataset"
```

## Version Control for Prompts

### Git Integration
```bash
# Initialize prompt repository
cd ~/.prompts
git init
git add .
git commit -m "Initial prompt collection"

# Track changes
git add modified_prompt.md
git commit -m "Improved code review prompt with security focus"

# Branch for experiments
git checkout -b experimental_prompts
# ... make changes ...
git checkout main
git merge experimental_prompts
```

### Backup and Sync
```bash
# Backup to remote repository
git remote add origin git@github.com:username/my-prompts.git
git push -u origin main

# Sync across machines
git pull origin main
```

### Versioned Prompts
```markdown
# ~/.prompts/versioned/code_review_v2.md
/config version 2.0
/config changelog "Added security analysis, improved output format"

# Code Review v2.0
Enhanced code review with security focus and structured output.
```

## Prompt Sharing and Collaboration

### Team Prompt Libraries
```bash
# Shared team prompts
git clone git@github.com:team/shared-prompts.git ~/.prompts/shared/
aia --prompts-dir ~/.prompts/shared/ team_code_review

# Personal + shared prompts
export AIA_PROMPTS__DIR="~/.prompts:~/.prompts/shared:./project_prompts"
```

### Prompt Documentation
```markdown
# ~/.prompts/README.md
# Team Prompt Library

## Categories
- `development/` - Code review, debugging, architecture
- `analysis/` - Data analysis, research, reporting
- `content/` - Writing, documentation, marketing

## Usage Guidelines
1. Test prompts before sharing
2. Include parameter documentation
3. Add examples in comments
4. Follow naming conventions

## Contributing
1. Create feature branch
2. Add/modify prompts
3. Test thoroughly
4. Submit pull request
```

### Prompt Standards
```markdown
# Prompt file header standard
# Title: Brief description
# Purpose: What this prompt accomplishes
# Parameters: List of expected variables
# Models: Recommended models
# Example: aia prompt_name --param value
# Author: Your name
# Version: 1.0
# Updated: YYYY-MM-DD
```

## Performance and Optimization

### Prompt Efficiency
```bash
# Monitor prompt performance
aia --verbose --debug optimized_prompt

# Compare prompt variations
time aia version1_prompt input.txt
time aia version2_prompt input.txt
```

### Caching Strategies
```ruby
# Cache expensive computations
/ruby
cache_file = "/tmp/analysis_cache_#{File.basename('<%= input %>')}.json"
if File.exist?(cache_file) && (Time.now - File.mtime(cache_file)) < 3600
  cached_data = JSON.parse(File.read(cache_file))
  puts "Using cached analysis: #{cached_data}"
else
  # Perform expensive analysis
  # Save to cache
end
```

### Batch Processing
```bash
# Batch process multiple files
for file in data/*.csv; do
  aia batch_analysis_prompt "$file" --output "results/$(basename $file .csv)_analysis.md"
done

# Parallel processing
parallel -j4 aia analysis_prompt {} --output {.}_result.md ::: data/*.txt
```

## Troubleshooting Prompts

### Debugging Tools
```bash
# Debug prompt processing
aia --debug --verbose problematic_prompt

# Test directive processing
aia --debug prompt_with_directives

# Validate ERB syntax
erb -T - ~/.prompts/template_prompt.md < /dev/null
```

### Common Issues

#### Missing Parameters
```bash
# Check required parameters
aia --regex '<%=\s*(\w+)\s*%>' my_prompt
# Ensure all extracted parameters are provided
```

#### File Not Found
```bash
# Verify file paths in /include directives
find ~/.prompts -name "missing_file.md"
# Use absolute paths or verify relative paths
```

#### Permission Errors
```bash
# Check prompt file permissions
ls -la ~/.prompts/problematic_prompt.md
chmod 644 ~/.prompts/problematic_prompt.md
```

## Advanced Prompt Techniques

### Dynamic Prompt Generation
```ruby
# Generate prompts based on context
/ruby
project_type = `git config --get remote.origin.url`.include?('rails') ? 'rails' : 'general'
prompt_template = File.read("templates/#{project_type}_review.md")
puts prompt_template
```

### Prompt Composition
```markdown
# ~/.prompts/composed_prompt.md
/include base/standard_instructions.md
/include domain/#{<%= domain %>}_expertise.md
/include format/#{<%= output_format %>}_template.md

Task: <%= specific_task %>
```

### Adaptive Prompts
```ruby
# Adjust based on model capabilities
/ruby
model = AIA.config.model
if model.include?('gpt-4')
  puts "Use advanced reasoning and detailed analysis."
elsif model.include?('3.5')
  puts "Focus on clear, direct responses."
end
```

## Best Practices

### Prompt Design
1. **Clear Structure**: Use headers and sections
2. **Specific Instructions**: Be precise about desired output
3. **Context Setting**: Provide necessary background
4. **Parameter Documentation**: Document all variables
5. **Error Handling**: Account for edge cases

### Organization  
1. **Consistent Naming**: Use clear, descriptive names
2. **Logical Grouping**: Organize by category or purpose
3. **Version Control**: Track changes and improvements
4. **Documentation**: Maintain usage guides
5. **Regular Cleanup**: Remove obsolete prompts

#### Recommended Directory Structure
```
~/.prompts/
├── daily/           # Daily workflow prompts
├── development/     # Coding and review prompts
├── research/        # Research and analysis
├── roles/          # System prompts
└── workflows/      # Multi-step pipelines
```

This organization helps you:
- **Find prompts quickly** by category
- **Maintain logical separation** of different use cases
- **Scale your prompt collection** without confusion
- **Share category-specific prompts** with team members

### Performance
1. **Model Selection**: Choose appropriate models
2. **Parameter Optimization**: Fine-tune settings
3. **Caching**: Cache expensive operations
4. **Batch Processing**: Process multiple items efficiently
5. **Monitoring**: Track usage and performance

## Related Documentation

- [Getting Started](guides/getting-started.md) - Basic prompt usage
- [Directives Reference](directives-reference.md) - Available directives
- [Advanced Prompting](advanced-prompting.md) - Expert techniques
- [Configuration](configuration.md) - Setup and customization
- [Examples](examples/prompts/index.md) - Real-world prompt examples

---

Effective prompt management is key to maximizing AIA's capabilities. Start with a simple organization structure and evolve it as your prompt collection grows!