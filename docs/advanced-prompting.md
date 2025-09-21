# Advanced Prompting Techniques

Master sophisticated prompting strategies to get the most out of AIA's capabilities with complex workflows, dynamic content generation, and expert-level AI interactions.

## Advanced Directive Usage

### Conditional Execution
Execute directives based on runtime conditions:

```markdown
<%
environment = ENV['RAILS_ENV'] || 'development'
config_file = "config/#{environment}.yml"
if File.exist?(config_file)
%>
//include <%= config_file %><%
<% else %>
//include config/default.yml
<% end %>
```

```markdown
<%
model = AIA.config.model
case model
when /gpt-4/
%>
Provide detailed, step-by-step analysis with code examples.
<% when /gpt-3.5/ %>
Provide concise, practical guidance with brief examples.
<% when /claude/ %>
Provide thorough analysis with emphasis on reasoning process.
<% end %>
```

### Dynamic Configuration
Adjust settings based on content or context:

```markdown
//ruby
<%
task_type = '<%= task_type %>'
temperature = case task_type
             when 'creative' then 1.2
             when 'analytical' then 0.3
             when 'balanced' then 0.7
             else 0.7
             end
%>
//config temperature <%= temperature %>
```

```markdown
<%
content_size = File.read('<%= input_file %>').length
model = content_size > 50000 ? 'claude-3-sonnet' : 'gpt-4'
max_tokens = content_size > 50000 ? 8000 : 4000
%>
//config model <%= model %>
//config max_tokens <%= max_tokens %>
```

## Complex Workflow Patterns

### Multi-Stage Analysis Pipeline
Create sophisticated analysis workflows with intermediate processing:

```markdown
# Stage 1: Data Preparation
//config model gpt-3.5-turbo
//config temperature 0.2

# Data Analysis Pipeline - Stage 1: Preparation

## Input Data Overview
//shell file <%= input_file %>
//shell wc -l <%= input_file %>
<%= "File size: #{File.size('<%= input_file %>')} bytes" %>

## Data Quality Assessment
//include <%= input_file %>

Analyze the data structure and identify:
1. Data format and schema
2. Missing or inconsistent values
3. Potential data quality issues
4. Preprocessing requirements

Save findings to: preprocessing_notes.md

//next data_cleaning
//pipeline analysis_deep_dive,pattern_recognition,insight_generation,final_report
```

### Adaptive Decision Trees
Create prompts that adapt their approach based on intermediate results:

```markdown
<%
file_ext = File.extname('<%= code_file %>')
file_size = File.size('<%= code_file %>')

# Determine analysis approach
if file_size > 10000
  analysis_type = 'comprehensive'
%>
//config model gpt-4
//config max_tokens 6000
<%
elsif file_ext == '.py'
  analysis_type = 'python_specific'
%>
//config model gpt-4
Including Python-specific analysis patterns
<%
else
  analysis_type = 'standard'
%>
//config model gpt-3.5-turbo
<%
end
%>
Selected <%= analysis_type %> analysis for <%= file_ext %> file (<%= file_size %> bytes)
```

## Advanced Context Management

### Hierarchical Context Building
Build context progressively through multiple layers:

```markdown
# Layer 1: Project Context
//include README.md
//include ARCHITECTURE.md

# Layer 2: Domain Context
<%
domain = '<%= domain || "general" %>'
domain_file = "docs/#{domain}_context.md"
if File.exist?(domain_file)
%>
//include <%= domain_file %>
<% end %>
```

# Layer 3: Task-Specific Context
<% if task_context_file %>
//include <%= task_context_file %>
<% end %>

# Layer 4: Historical Context
<%
history_file = ".aia/history/#{Date.today.strftime('%Y%m')}_context.md"
if File.exist?(history_file)
%>
//include <%= history_file %>
<% end %>
```

Now analyze <%= task %> using all available context layers.
```

### Clipboard Integration
Quick data insertion from clipboard:

```markdown
# Code Review with Clipboard Content

## Code to Review
//paste

## Review Guidelines
- Check for best practices
- Identify security vulnerabilities
- Suggest performance improvements
- Validate error handling

Please provide detailed feedback on the code above.
```

This is particularly useful for:
- Quick code reviews when you've copied code from an IDE
- Analyzing error messages or logs copied from terminals
- Including data from spreadsheets or other applications
- Rapid prototyping with copied examples

### Context Filtering and Summarization
Manage large contexts intelligently:

```markdown
<%
max_context_size = 20000  # characters
context_files = ['docs/spec.md', 'docs/api.md', 'docs/examples.md']
total_size = 0

context_files.each do |file|
  if File.exist?(file)
    file_size = File.read(file).length
    if total_size + file_size <= max_context_size
%>
//include <%= file %>
<%
      total_size += file_size
    else
%>
Summarizing <%= file %> (too large for full inclusion):

<%= AIA.summarize_file(file, max_length: 500) %>
<%
    end
  end
end
%>
```

## Dynamic Content Generation

### Template-Based Generation
Create flexible templates that adapt to different scenarios:

```erb
# Multi-format document generator
//config model <%= model || "gpt-4" %>
//config temperature <%= creativity || "0.7" %>

# <%= document_type.capitalize %> Document

<% case format %>
<% when 'technical' %>
Generate a technical document with:
- Executive summary
- Detailed technical specifications
- Implementation guidelines
- Code examples and APIs
- Testing and validation procedures

<% when 'business' %>
Generate a business document with:
- Executive summary
- Market analysis
- Financial projections
- Risk assessment
- Implementation timeline

<% when 'academic' %>
Generate an academic document with:
- Abstract and keywords
- Literature review
- Methodology
- Results and analysis
- Conclusions and future work
<% end %>

## Source Material
//include <%= source_file %>

## Additional Context
<% if context_files %>
<% context_files.each do |file| %>
//include <%= file %>
<% end %>
<% end %>

## Clipboard Content (if applicable)
<% if include_clipboard %>
//paste
<% end %>

Target audience: <%= audience || "general professional" %>
Document length: <%= length || "2000-3000 words" %>
```

### Recursive Prompt Generation
Generate prompts that create other prompts:

```markdown
<%
domain = '<%= domain %>'
tasks = ['analyze', 'design', 'implement', 'test', 'document']

tasks.each do |task|
  prompt_content = <<~PROMPT
    # #{domain.capitalize} #{task.capitalize} Prompt

    //config model gpt-4
    //config temperature 0.5

    You are a #{domain} expert performing #{task} tasks.

    Task: <%= specific_task %>
    Context: //include <%= context_file %>

    Provide expert-level guidance specific to #{domain} #{task}.
  PROMPT

  filename = "generated_#{domain}_#{task}.txt"
  File.write(filename, prompt_content)
%>
Generated: <%= filename %>
<% end %>
```

## Expert-Level Model Interaction

### Multi-Model Orchestration
Coordinate multiple models for complex tasks:

```markdown
# Multi-model analysis system
//config consensus false

## Phase 1: Creative Ideation (High Temperature)
<%= "Using GPT-4 for creative brainstorming..." %>
<%
gpt4_creative = RubyLLM.chat(model: 'gpt-4', temperature: 1.3)
ideas = gpt4_creative.ask("Generate 10 innovative approaches to: <%= problem %>")
%>
<%= ideas.content %>
```

## Phase 2: Technical Analysis (Low Temperature)

<%= "Using Claude for technical analysis..." %>
<%
claude_technical = RubyLLM.chat(model: 'claude-3-sonnet', temperature: 0.2)
analysis = claude_technical.ask("Analyze technical feasibility of these approaches: #{ideas.content}")
%>
<%= analysis.content %>
```

## Phase 3: Synthesis and Recommendation

<%= "Using GPT-4 for final synthesis..." %>
<%
gpt4_synthesis = RubyLLM.chat(model: 'gpt-4', temperature: 0.7)
final_rec = gpt4_synthesis.ask("Synthesize and recommend best approach: Ideas: #{ideas.content} Analysis: #{analysis.content}")
%>
<%= final_rec.content %>
```

### Model-Specific Optimization
Tailor prompts for specific model strengths:

```markdown
<%
model = AIA.config.model
case model
when /gpt-4/
  # GPT-4 excels at complex reasoning and code
  instruction_style = "detailed step-by-step analysis with code examples"
  context_depth = "comprehensive background and multiple perspectives"
when /claude/
  # Claude excels at long-form analysis and following instructions precisely
  instruction_style = "thorough systematic analysis with clear reasoning"
  context_depth = "complete context with relevant documentation"
when /gemini/
  # Gemini excels at structured data and mathematical reasoning
  instruction_style = "structured analysis with quantitative metrics"
  context_depth = "organized data with clear relationships"
end
%>
Optimizing for <%= model %>: <%= instruction_style %>
```

Apply <%= instruction_style %> to analyze <%= task %>.

Include <%= context_depth %> for comprehensive understanding.
```

## Advanced Tool Integration

### Custom Tool Workflows
Create sophisticated tool integration patterns:

```markdown
//tools advanced_analysis_tools.rb

<%
# Initialize analysis workflow
workflow = AnalysisWorkflow.new
workflow.add_tool('data_preprocessor', weight: 0.3)
workflow.add_tool('statistical_analyzer', weight: 0.4)
workflow.add_tool('pattern_detector', weight: 0.2)
workflow.add_tool('insight_generator', weight: 0.1)

results = workflow.execute('<%= input_data %>')
%>
Analysis complete. Confidence: <%= results[:confidence] %>
<%= results[:summary] %>
```

Based on multi-tool analysis, provide expert interpretation of:
<%= results[:detailed_findings] %>
```

### Dynamic Tool Selection
Select tools based on content analysis:

```markdown
<%
content = File.read('<%= input_file %>')

# Analyze content to determine best tools
tools = []
tools << 'text_analyzer' if content.match?(/[a-zA-Z]{100,}/)
tools << 'code_analyzer' if content.match?(/def\s+\w+|function\s+\w+|class\s+\w+/)
tools << 'data_analyzer' if content.match?(/\d+[,.]?\d*\s*[%$]?/)
tools << 'web_scraper' if content.match?(/https?:\/\//)
%>
Selected tools: <%= tools.join(', ') %>
<% tools.each do |tool| %>
//tools <%= tool %>.rb
<% end %>
```

## Sophisticated Output Formatting

### Multi-Format Output Generation
Generate output in multiple formats simultaneously:

```markdown
//config model gpt-4

# Multi-Format Report Generator

Generate analysis in multiple formats:

## 1. Executive Summary (Business Format)
Provide a 200-word executive summary suitable for C-level presentation.

## 2. Technical Detail (Developer Format)
Provide detailed technical analysis with:
- Architecture diagrams (textual description)
- Code examples
- Implementation steps
- Testing strategies

## 3. Academic Format (Research Paper Style)
Provide structured analysis with:
- Abstract and keywords
- Methodology description
- Results and discussion
- References and citations

## 4. Action Items (Project Management Format)
Extract concrete action items with:
- Priority levels (High/Medium/Low)
- Estimated effort
- Dependencies
- Assigned roles
- Success criteria

Source: //include <%= source_file %>
```

### Structured Data Extraction
Extract structured data from unstructured content:

```ruby
# Structured data extraction
//config model gpt-4
//config temperature 0.1

Extract structured information from the following content and format as JSON:

Required fields:
- entities: List of people, organizations, locations
- dates: Important dates and deadlines
- metrics: Numerical data and KPIs
- actions: Required actions and decisions
- risks: Identified risks and concerns
- opportunities: Growth and improvement opportunities

Content:
//include <%= unstructured_content %>

Output valid JSON only, no explanatory text.

# Post-process extracted JSON
json_output = response.content
begin
  data = JSON.parse(json_output)
  puts "Successfully extracted #{data.keys.length} data categories"

  # Save to structured file
  File.write('extracted_data.json', JSON.pretty_generate(data))
  puts "Data saved to extracted_data.json"
rescue JSON::ParserError => e
  puts "JSON parsing failed: #{e.message}"
end
```

## Advanced Error Handling and Recovery

### Graceful Degradation
Handle errors and provide fallback options:

```ruby
# Robust prompt with fallbacks
<%=
begin
  primary_content = File.read('<%= primary_source %>')
  puts "//include <%= primary_source %>"
rescue => e
  puts "Primary source unavailable (#{e.message})"

  # Try fallback sources
  fallback_sources = ['backup.txt', 'default_context.md', 'minimal_info.txt']
  fallback_found = false

  fallback_sources.each do |source|
    if File.exist?(source)
      puts "Using fallback source: #{source}"
      puts "//include #{source}"
      fallback_found = true
      break
    end
  end

  unless fallback_found
    puts "No sources available. Proceeding with minimal context."
    puts "Please provide basic information about: <%= topic %>"
  end
end
%>
```

### Validation and Quality Assurance
Implement quality checks for AI outputs:

```ruby
# Output validation system
<%=
class OutputValidator
  def self.validate_code_review(output)
    required_sections = ['Summary', 'Issues Found', 'Recommendations']
    severity_levels = ['Critical', 'Major', 'Minor']

    issues = []
    required_sections.each do |section|
      issues << "Missing section: #{section}" unless output.include?(section)
    end

    has_severity = severity_levels.any? { |level| output.include?(level) }
    issues << "No severity levels found" unless has_severity

    issues.empty? ? "✓ Validation passed" : "⚠ Issues: #{issues.join(', ')}"
  end
end

# This will be used to validate the AI response
puts "Response will be validated for: <%= validation_criteria %>"
%>
```

## Performance Optimization Techniques

### Intelligent Caching
Implement smart caching for expensive operations:

```ruby
# Smart caching system
<%=
require 'digest'

cache_key = Digest::MD5.hexdigest('<%= input_data %>' + AIA.config.model)
cache_file = "/tmp/aia_cache_#{cache_key}.json"
cache_duration = 3600  # 1 hour

if File.exist?(cache_file) && (Time.now - File.mtime(cache_file)) < cache_duration
  puts "Using cached result for similar query..."
  cached_result = JSON.parse(File.read(cache_file))
  puts cached_result['content']
  exit  # Skip AI processing
else
  puts "Processing fresh query (no valid cache found)..."
  # Continue with normal processing
  # Result will be cached by post-processing script
end
%>
```

### Batch Processing Strategies
Optimize for processing multiple items:

```ruby
# Intelligent batch processing
<%=
files = Dir.glob('<%= pattern %>')
batch_size = 5
model_switching_threshold = 10

puts "Processing #{files.length} files in batches of #{batch_size}"

# Switch to faster model for large batches
if files.length > model_switching_threshold
  puts "//config model gpt-3.5-turbo  # Using faster model for large batch"
else
  puts "//config model gpt-4  # Using quality model for small batch"
end

files.each_slice(batch_size).with_index do |batch, index|
  puts "\n## Batch #{index + 1}: #{batch.map(&:basename).join(', ')}"
  batch.each { |file| puts "//include #{file}" }
  puts "\nAnalyze this batch focusing on common patterns and unique aspects."
end
%>
```

## Best Practices for Advanced Prompting

### Modular Design Principles
1. **Separation of Concerns**: Keep configuration, data, and instructions separate
2. **Reusable Components**: Create modular prompt components
3. **Clear Dependencies**: Document and manage prompt dependencies
4. **Version Control**: Track changes and maintain prompt versioning

### Performance Considerations
1. **Model Selection**: Choose appropriate models for task complexity
2. **Context Management**: Balance completeness with efficiency
3. **Caching Strategies**: Cache expensive computations and API calls
4. **Batch Processing**: Optimize for multiple similar tasks

### Error Prevention
1. **Validation**: Validate inputs and outputs
2. **Fallbacks**: Provide graceful degradation options
3. **Testing**: Test prompts with various inputs
4. **Monitoring**: Track performance and error rates

### Security and Privacy
1. **Input Sanitization**: Clean and validate user inputs
2. **Access Control**: Limit file and system access
3. **Data Privacy**: Avoid exposing sensitive information
4. **Audit Trails**: Log usage and maintain accountability

## Real-World Advanced Examples

### Automated Code Review System
A comprehensive code review system using multiple models and tools:

```markdown
# enterprise_code_review.txt
//config model gpt-4
//tools security_scanner.rb,performance_analyzer.rb,style_checker.rb

# Enterprise Code Review System

<%=
# Multi-phase review process
phases = {
  security: { model: 'gpt-4', temperature: 0.1, tools: ['security_scanner'] },
  performance: { model: 'claude-3-sonnet', temperature: 0.2, tools: ['performance_analyzer'] },
  style: { model: 'gpt-3.5-turbo', temperature: 0.3, tools: ['style_checker'] },
  architecture: { model: 'gpt-4', temperature: 0.5, tools: [] }
}

current_phase = '<%= phase || "security" %>'
config = phases[current_phase.to_sym]

puts "//config model #{config[:model]}"
puts "//config temperature #{config[:temperature]}"
config[:tools].each { |tool| puts "//tools #{tool}.rb" }

puts "\n## Phase: #{current_phase.capitalize} Review"
%>
```

### Code to Analyze:
//include <%= code_file %>

Perform comprehensive <%= current_phase %> analysis following enterprise standards.

<%=
next_phase = phases.keys[phases.keys.index(current_phase.to_sym) + 1]
puts next_phase ? "//next enterprise_code_review --phase #{next_phase}" : "# Review complete"
%>
```

### Intelligent Research Assistant
A research system that adapts its approach based on query complexity:

```markdown
<%=
# adaptive_research_assistant.txt
query = research_query
complexity = query.split.length > 10 ? 'complex' : 'simple'
domain = domain || "general"

if complexity == 'complex'
  puts "//config model claude-3-sonnet"
  puts "//config max_tokens 6000"
  research_depth = 'comprehensive'
else
  puts "//config model gpt-4"
  puts "//config max_tokens 3000"
  research_depth = 'focused'
end

puts "Research mode: #{research_depth} analysis for #{domain} domain"
%>
```

# Adaptive Research Analysis

## Query: <%= research_query %>

# Dynamic source inclusion based on domain
<%=
source_map = {
  'technology' => ['tech_sources.md', 'industry_reports/', 'patent_db.txt'],
  'business' => ['market_data.csv', 'financial_reports/', 'competitor_analysis.md'],
  'academic' => ['literature_db.txt', 'citation_index.md', 'peer_reviews/'],
  'general' => ['general_sources.md', 'news_feeds.txt', 'reference_materials/']
}

sources = source_map[domain] || source_map['general']
sources.each do |source|
  if File.exist?(source) || Dir.exist?(source)
    puts "//include #{source}"
  end
end
%>
```

Provide <%= research_depth %> research analysis addressing:
1. Current state of knowledge
2. Key findings and insights
3. Research gaps and limitations
4. Future research directions
5. Practical implications

<%=
if research_depth == 'comprehensive'
  puts "//next citation_generator"
  puts "//pipeline fact_checker,source_validator,bibliography_creator"
end
%>
```

## Related Documentation

- [Prompt Management](prompt_management.md) - Organizing and managing prompts
- [Directives Reference](directives-reference.md) - All available directives
- [Working with Models](guides/models.md) - Model selection and optimization
- [Tools Integration](guides/tools.md) - Advanced tool usage
- [Examples](examples/index.md) - Real-world advanced examples

---

Advanced prompting is where AIA truly shines. These techniques enable you to create sophisticated, intelligent workflows that adapt to complex requirements and deliver expert-level results. Experiment with these patterns and develop your own advanced techniques!
