# Workflows and Pipelines

AIA's workflow system allows you to chain prompts together, creating sophisticated multi-stage processes for complex tasks. This enables automated processing pipelines that can handle everything from simple two-step workflows to complex enterprise-level automation.

## Understanding Workflows

### Basic Concepts

**Workflow**: A sequence of prompts executed in order, where each prompt can pass context to the next.

**Pipeline**: A predefined sequence of prompt IDs that are executed automatically.

**Next Prompt**: The immediate next prompt to execute after the current one completes.

**Context Passing**: Information and results flow from one prompt to the next in the sequence.

## Simple Workflows

### Sequential Processing
```markdown
# first_prompt.md
/next second_prompt
/config model gpt-4

Analyze the following data and prepare it for detailed analysis:
/include <%= data_file %>

Key findings summary:
```

```markdown  
# second_prompt.md
/config model claude-3-sonnet

Based on the initial analysis, provide detailed insights and recommendations:

Previous analysis results will be available in context.
Generate actionable recommendations.
```

### Basic Pipeline
```bash
# Execute a simple pipeline
aia --pipeline "data_prep,analysis,report" dataset.csv

# Or using the directive
aia data_prep --next analysis --next report dataset.csv
```

## Pipeline Definition

### Command Line Pipelines
```bash
# Simple linear pipeline
aia --pipeline "step1,step2,step3" input.txt

# Pipeline with output files
aia --pipeline "extract,transform,load" --output results.md data.csv

# Pipeline with model specification
aia --model gpt-4 --pipeline "review,optimize,test" code.py
```

### Directive-Based Pipelines
```markdown
# pipeline_starter.md
/pipeline analyze_data,generate_insights,create_visualization,write_report
/config model claude-3-sonnet

# Data Analysis Pipeline

Starting comprehensive data analysis workflow.

Input data: <%= input_file %>
Processing stages: 4 stages planned

## Stage 1: Data Analysis
Initial data examination and basic statistics.
```

### Dynamic Pipeline Generation
```ruby
# adaptive_pipeline.md
/ruby
data_size = File.size('<%= input_file %>')
complexity = data_size > 100000 ? 'complex' : 'simple'

if complexity == 'complex'
  pipeline = ['data_chunk', 'parallel_analysis', 'merge_results', 'comprehensive_report']
else
  pipeline = ['quick_analysis', 'summary_report']
end

puts "/pipeline #{pipeline.join(',')}"
puts "Selected #{complexity} pipeline (#{pipeline.length} stages)"
```

## Advanced Workflow Patterns

### Conditional Workflows
Execute different paths based on intermediate results:

```ruby
# conditional_workflow.md
/ruby
# Analyze input to determine workflow path
content = File.read('<%= input_file %>')
file_type = File.extname('<%= input_file %>')

if file_type == '.py'
  workflow = ['python_analysis', 'security_check', 'performance_review', 'documentation']
elsif file_type == '.js'
  workflow = ['javascript_analysis', 'eslint_check', 'performance_review', 'documentation']
elsif content.match?(/SELECT|INSERT|UPDATE|DELETE/i)
  workflow = ['sql_analysis', 'security_audit', 'optimization_review']
else
  workflow = ['generic_analysis', 'quality_check', 'recommendations']
end

puts "/pipeline #{workflow.join(',')}"
puts "Detected #{file_type} file, using #{workflow.first.split('_').first} workflow"
```

### Parallel Processing Workflows
Handle multiple inputs simultaneously:

```ruby
# parallel_processing.md
/ruby
input_files = Dir.glob('<%= pattern %>')
batch_size = 3

puts "Processing #{input_files.length} files in parallel batches"

input_files.each_slice(batch_size).with_index do |batch, index|
  puts "\n## Batch #{index + 1}"
  batch.each_with_index do |file, file_index|
    puts "### File #{file_index + 1}: #{File.basename(file)}"
    puts "/include #{file}"
  end
  
  puts "\nProcess this batch focusing on:"
  puts "- Individual file analysis"  
  puts "- Cross-file relationships"
  puts "- Batch-level patterns"
  
  if index < (input_files.length / batch_size.to_f).ceil - 1
    puts "/next parallel_processing_batch_#{index + 2}"
  else
    puts "/next merge_parallel_results"
  end
end
```

### Error Recovery Workflows
Handle failures gracefully:

```markdown
# robust_workflow.md
/config model gpt-4
/config temperature 0.3

# Robust Analysis Workflow

/ruby
begin
  primary_data = File.read('<%= primary_input %>')
  puts "Using primary data source"
  puts "/include <%= primary_input %>"
  
  # Set success path
  puts "/next detailed_analysis"
  
rescue => e
  puts "Primary data unavailable: #{e.message}"
  puts "Switching to fallback workflow"
  
  # Check for fallback options
  if File.exist?('<%= fallback_input %>')
    puts "/include <%= fallback_input %>"  
    puts "/next basic_analysis"
  else
    puts "No data sources available"
    puts "/next manual_input_prompt"
  end
end
```

## State Management in Workflows

### Context Persistence
Maintain state across workflow stages:

```ruby
# stateful_workflow.md
/ruby
# Initialize or load workflow state
state_file = '/tmp/workflow_state.json'

if File.exist?(state_file)
  state = JSON.parse(File.read(state_file))
  puts "Resuming workflow at stage: #{state['current_stage']}"
else
  state = {
    'workflow_id' => SecureRandom.uuid,
    'started_at' => Time.now.iso8601,
    'current_stage' => 1,
    'completed_stages' => [],
    'data' => {}
  }
end

# Update state for current stage
stage_name = '<%= stage_name || "unknown" %>'
state['current_stage'] = stage_name
state['data'][stage_name] = {
  'started_at' => Time.now.iso8601,
  'input_file' => '<%= input_file %>',
  'model' => AIA.config.model
}

# Save state
File.write(state_file, JSON.pretty_generate(state))
puts "Workflow state saved: #{state['workflow_id']}"
```

### Data Passing Between Stages
Pass structured data between workflow stages:

```ruby
# data_passing_example.md
/ruby
# Stage data management
stage_data_file = "/tmp/stage_data_#{ENV['WORKFLOW_ID'] || 'default'}.json"

# Load previous stage data if available
previous_data = {}
if File.exist?(stage_data_file)
  previous_data = JSON.parse(File.read(stage_data_file))
  puts "Loaded data from previous stages:"
  puts JSON.pretty_generate(previous_data)
end

# Current stage identifier
current_stage = '<%= current_stage || "stage_#{Time.now.to_i}" %>'
```

## Current Stage: <%= current_stage.capitalize %>

Previous stage results:
<%= previous_data.empty? ? "No previous data" : previous_data.to_json %>

## Analysis Task
Perform analysis considering previous stage results.

/ruby
# Prepare data for next stage (this would be set by the AI response processing)
current_results = {
  'stage' => current_stage,
  'timestamp' => Time.now.iso8601,
  'status' => 'completed',
  'key_findings' => 'placeholder_for_ai_results'
}

# This would typically be saved after AI processing
puts "Stage data template prepared for: #{current_stage}"
```

## Workflow Orchestration

### Master Workflow Controller
Create workflows that manage other workflows:

```ruby
# master_controller.md
/config model gpt-4

# Master Workflow Controller

/ruby
project_type = '<%= project_type %>'
complexity = '<%= complexity || "standard" %>'

workflows = {
  'code_project' => {
    'simple' => ['code_review', 'basic_tests', 'documentation'],
    'standard' => ['code_review', 'security_scan', 'performance_test', 'documentation'],
    'complex' => ['architecture_review', 'code_review', 'security_audit', 'performance_analysis', 'test_suite', 'documentation']
  },
  'data_analysis' => {
    'simple' => ['data_overview', 'basic_stats', 'summary'],
    'standard' => ['data_validation', 'exploratory_analysis', 'modeling', 'insights'],
    'complex' => ['data_profiling', 'quality_assessment', 'feature_engineering', 'advanced_modeling', 'validation', 'reporting']
  },
  'content_creation' => {
    'simple' => ['outline', 'draft', 'review'],
    'standard' => ['research', 'outline', 'draft', 'edit', 'finalize'],
    'complex' => ['research', 'expert_review', 'outline', 'sections_draft', 'peer_review', 'revision', 'final_edit']
  }
}

selected_workflow = workflows[project_type][complexity]
puts "/pipeline #{selected_workflow.join(',')}"

puts "Initiating #{project_type} workflow (#{complexity} complexity)"
puts "Stages: #{selected_workflow.length}"
puts "Estimated duration: #{selected_workflow.length * 5} minutes"
```

### Workflow Monitoring and Logging
Track workflow execution and performance:

```ruby
# workflow_monitor.md
/ruby
require 'logger'

# Setup workflow logging
log_dir = '/tmp/aia_workflows'
Dir.mkdir(log_dir) unless Dir.exist?(log_dir)

logger = Logger.new("#{log_dir}/workflow_#{Date.today.strftime('%Y%m%d')}.log")
workflow_id = ENV['WORKFLOW_ID'] || SecureRandom.uuid

# Log workflow start
logger.info("Workflow #{workflow_id} started")
logger.info("Stage: <%= stage_name %>")
logger.info("Model: #{AIA.config.model}")
logger.info("Input: <%= input_description %>")

start_time = Time.now
puts "Workflow monitoring active (ID: #{workflow_id})"
```

## Workflow Performance Optimization

### Intelligent Model Selection
Choose optimal models for each workflow stage:

```ruby
# model_optimized_workflow.md
/ruby
stages = {
  'data_extraction' => { model: 'gpt-3.5-turbo', temperature: 0.2 },
  'analysis' => { model: 'claude-3-sonnet', temperature: 0.3 },
  'creative_generation' => { model: 'gpt-4', temperature: 1.0 },
  'review_and_edit' => { model: 'gpt-4', temperature: 0.4 },
  'final_formatting' => { model: 'gpt-3.5-turbo', temperature: 0.1 }
}

current_stage = '<%= current_stage %>'
stage_config = stages[current_stage]

if stage_config
  puts "/config model #{stage_config[:model]}"
  puts "/config temperature #{stage_config[:temperature]}"
  puts "Optimized for #{current_stage}: #{stage_config[:model]} at #{stage_config[:temperature]} temperature"
else
  puts "/config model gpt-4"
  puts "Using default model for unknown stage: #{current_stage}"
end
```

### Caching and Optimization
Implement caching for workflow efficiency:

```ruby
# cached_workflow.md
/ruby
require 'digest'

# Create cache key from inputs and configuration
cache_inputs = {
  'stage' => '<%= stage_name %>',
  'input_file' => '<%= input_file %>',
  'model' => AIA.config.model,
  'temperature' => AIA.config.temperature
}

cache_key = Digest::MD5.hexdigest(cache_inputs.to_json)
cache_file = "/tmp/workflow_cache_#{cache_key}.json"
cache_duration = 3600  # 1 hour

if File.exist?(cache_file) && (Time.now - File.mtime(cache_file)) < cache_duration
  cached_result = JSON.parse(File.read(cache_file))
  puts "Using cached result for stage: #{cached_result['stage']}"
  puts cached_result['content']
  
  # Skip to next stage if available
  if cached_result['next_stage']
    puts "/next #{cached_result['next_stage']}"
  end
  
  exit  # Skip AI processing
else
  puts "Processing fresh request (cache miss or expired)"
  # Continue with normal processing
end
```

## Real-World Workflow Examples

### Software Development Pipeline
Complete software development workflow:

```markdown
# software_dev_pipeline.md
/pipeline requirements_analysis,architecture_design,implementation_plan,code_review,testing_strategy,documentation,deployment_guide

# Software Development Pipeline

Project: <%= project_name %>
Repository: /include README.md

## Pipeline Stages:
1. **Requirements Analysis** - Extract and analyze requirements
2. **Architecture Design** - Design system architecture
3. **Implementation Plan** - Create detailed implementation plan  
4. **Code Review** - Review existing code
5. **Testing Strategy** - Develop testing approach
6. **Documentation** - Generate comprehensive docs
7. **Deployment Guide** - Create deployment instructions

Starting requirements analysis phase...

/config model gpt-4
/config temperature 0.4
```

### Content Creation Workflow
Multi-stage content creation pipeline:

```markdown
# content_creation_pipeline.md
/pipeline research_phase,outline_creation,content_draft,expert_review,content_revision,final_edit,seo_optimization

# Content Creation Pipeline

Topic: <%= topic %>
Target Audience: <%= audience %>
Content Type: <%= content_type %>

## Research Phase
/include source_materials.md
/shell curl -s "https://api.example.com/research/<%= topic %>" | jq '.'

Initial research and source gathering...

/config model claude-3-sonnet
/config temperature 0.6
```

### Data Science Workflow
Comprehensive data analysis pipeline:

```ruby
# data_science_workflow.md
/ruby
dataset_size = File.size('<%= dataset %>')
complexity = dataset_size > 10000000 ? 'enterprise' : 'standard'

pipelines = {
  'standard' => ['data_exploration', 'data_cleaning', 'feature_analysis', 'modeling', 'validation', 'insights'],
  'enterprise' => ['data_profiling', 'quality_assessment', 'preprocessing', 'feature_engineering', 'model_selection', 'hyperparameter_tuning', 'validation', 'deployment_prep', 'monitoring_setup']
}

selected_pipeline = pipelines[complexity]
puts "/pipeline #{selected_pipeline.join(',')}"

puts "Selected #{complexity} data science pipeline"
puts "Dataset size: #{dataset_size} bytes"
```

# Data Science Analysis Pipeline

Dataset: /include <%= dataset %>

Pipeline optimized for <%= complexity %> analysis with <%= selected_pipeline.length %> stages.

/config model claude-3-sonnet
/config temperature 0.3
```

## Workflow Best Practices

### Design Principles
1. **Modularity**: Each stage should have a clear, single purpose
2. **Reusability**: Design stages that can be used in multiple workflows
3. **Error Handling**: Plan for failures and provide recovery paths
4. **State Management**: Maintain proper state between stages
5. **Monitoring**: Include logging and progress tracking

### Performance Considerations
1. **Model Selection**: Choose appropriate models for each stage
2. **Caching**: Cache expensive operations and intermediate results
3. **Parallel Processing**: Run independent stages concurrently
4. **Resource Management**: Monitor memory and token usage
5. **Optimization**: Profile and optimize slow stages

### Maintenance and Debugging
1. **Logging**: Comprehensive logging for troubleshooting
2. **Testing**: Test workflows with various inputs
3. **Documentation**: Document workflow purpose and usage
4. **Versioning**: Version control workflow definitions
5. **Monitoring**: Track workflow performance and success rates

## Troubleshooting Workflows

### Common Issues

#### Workflow Interruption
```bash
# Resume interrupted workflow
export WORKFLOW_ID="previous_workflow_id"
aia --resume-workflow $WORKFLOW_ID

# Or restart from specific stage
aia --pipeline "failed_stage,remaining_stages" --resume-from failed_stage
```

#### Context Size Issues
```ruby
# Handle large contexts in workflows
/ruby
context_size = File.read('<%= context_file %>').length
max_context = 50000

if context_size > max_context
  puts "Context too large (#{context_size} chars), implementing chunking strategy"
  puts "/pipeline chunk_processing,merge_results,final_analysis"
else
  puts "/pipeline standard_analysis,final_report"
end
```

#### Model Rate Limiting
```ruby
# Handle rate limiting in workflows
/ruby
stage_delays = {
  'heavy_analysis' => 30,  # seconds
  'api_calls' => 10,
  'standard' => 5
}

current_stage = '<%= stage_name %>'
delay = stage_delays[current_stage] || stage_delays['standard']

puts "Implementing #{delay}s delay for rate limiting"
sleep delay if ENV['WORKFLOW_MODE'] == 'production'
```

## Related Documentation

- [Advanced Prompting](advanced-prompting.md) - Complex prompting techniques
- [Prompt Management](prompt_management.md) - Organizing prompts
- [Configuration](configuration.md) - Workflow configuration options
- [Examples](examples/index.md) - Real-world workflow examples
- [CLI Reference](cli-reference.md) - Pipeline command-line options

---

Workflows and pipelines are powerful features that enable sophisticated automation with AIA. Start with simple sequential workflows and gradually build more complex, intelligent automation systems as your needs grow!