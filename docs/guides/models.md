# Working with Models

AIA supports multiple AI models through the RubyLLM gem, allowing you to choose the best model for each task and even use multiple models simultaneously.

## Available Models

### List All Models
```bash
# Show all available models
aia --available_models

# Filter by provider
aia --available_models openai
aia --available_models anthropic
aia --available_models google

# Filter by capability
aia --available_models vision
aia --available_models function_calling
aia --available_models text_to_image

# Complex filtering
aia --available_models openai,gpt,4
```

### Model Information
Each model listing includes:
- **Model ID**: Exact name to use with `--model`
- **Provider**: Company providing the model
- **Context Window**: Maximum input/output length
- **Input Cost**: Price per million input tokens
- **Modalities**: Supported input/output types
- **Capabilities**: Special features available

## Model Selection

### Single Model Usage
```bash
# Use specific model
aia --model gpt-4 my_prompt
aia --model claude-3-sonnet code_review.py
aia --model gemini-pro analyze_data.csv

# Short model names (when unambiguous)
aia --model gpt-4 my_prompt
aia --model claude my_prompt
aia --model gemini my_prompt
```

### Model Categories by Use Case

#### Text Generation
**Creative Writing**: High creativity, good with narratives
- `gpt-4`: Excellent creative writing, good instruction following
- `claude-3-sonnet`: Great for longer creative pieces
- `gemini-pro`: Good balance of creativity and structure

**Technical Writing**: Accuracy and precision focus
- `gpt-4`: Strong technical accuracy
- `claude-3-sonnet`: Excellent for documentation
- `gpt-3.5-turbo`: Fast, cost-effective for simple technical tasks

#### Code Analysis
**Code Review**: Understanding existing code
- `gpt-4`: Excellent code comprehension
- `claude-3-sonnet`: Great at explaining complex code
- `codellama-34b`: Specialized for code understanding

**Code Generation**: Writing new code
- `gpt-4`: High-quality code generation
- `claude-3-sonnet`: Good at following coding standards
- `codellama-7b`: Fast code completion

#### Data Analysis
**Statistical Analysis**: Working with numbers and data
- `claude-3-sonnet`: Excellent analytical reasoning
- `gpt-4`: Strong mathematical capabilities
- `gemini-pro`: Good with structured data

**Research**: Processing large amounts of information
- `claude-3-sonnet`: Large context window, good summarization
- `gpt-4`: Strong reasoning and synthesis
- `claude-3-opus`: Highest quality analysis (more expensive)

## Multi-Model Operations

### Parallel Processing
Run the same prompt with multiple models:
```bash
# Compare outputs from different models
aia --model "gpt-4,claude-3-sonnet,gemini-pro" my_prompt

# Each model provides separate response
```

### Consensus Mode
Get unified response from multiple models:
```bash
# Enable consensus mode
aia --model "gpt-4,claude-3-sonnet" --consensus my_prompt

# Works in chat mode too
aia --chat --model "gpt-4o-mini,gpt-3.5-turbo" --consensus

# Models collaborate to provide single, refined response
```

**Consensus Output Format:**
```
from: gpt-4o-mini (consensus)
Based on the insights from multiple AI models, here is a comprehensive answer that
incorporates the best perspectives and resolves any contradictions...
```

### Individual Response Mode

By default, each model provides its own separate response:

```bash
# Default behavior - show individual responses  
aia --model "gpt-4o-mini,gpt-3.5-turbo,gpt-5-mini" my_prompt

# Explicitly disable consensus
aia --model "gpt-4o-mini,gpt-3.5-turbo" --no-consensus my_prompt
```

**Individual Responses Output Format:**
```
from: gpt-4o-mini
Response from the first model...

from: gpt-3.5-turbo  
Response from the second model...

from: gpt-5-mini
Response from the third model...
```

### Model Configuration Status

View your current multi-model configuration using the `//model` directive:

```bash
# In any prompt file or in chat session
//model
```

**Example Output:**
```
Multi-Model Configuration:
==========================
Model count: 3
Primary model: gpt-4o-mini (used for consensus when --consensus flag is enabled)
Consensus mode: false

Model Details:
--------------------------------------------------
1. gpt-4o-mini (primary)
2. gpt-3.5-turbo  
3. gpt-5-mini
```

**Multi-Model Features:**
- **Primary Model**: The first model in the list serves as the consensus orchestrator
- **Concurrent Processing**: All models run simultaneously for better performance  
- **Flexible Output**: Choose between individual responses or synthesized consensus
- **Error Handling**: Invalid models are reported but don't prevent valid models from working
- **Batch Mode Support**: Multi-model responses are properly formatted in output files

### Model Comparison in Prompts
```markdown
Compare responses from multiple models:
//compare "Explain quantum computing" --models gpt-4,claude-3-sonnet,gemini-pro

Which explanation is most accessible?
```

## Model Configuration

### Model-Specific Settings
Different models may work best with different parameters:

#### GPT Models
```yaml
# ~/.aia/models/gpt-4.yml
temperature: 0.7
max_tokens: 4000
top_p: 1.0
frequency_penalty: 0.0
presence_penalty: 0.0
```

#### Claude Models
```yaml
# ~/.aia/models/claude-3-sonnet.yml
temperature: 0.8
max_tokens: 8000
top_p: 0.9
```

#### Gemini Models
```yaml
# ~/.aia/models/gemini-pro.yml
temperature: 0.6
max_tokens: 2000
top_p: 0.95
```

### Dynamic Model Selection
Choose models based on task characteristics:

```ruby
# In prompt with Ruby directive
//ruby
task_type = '<%= task_type %>'
model = case task_type
        when 'creative' then 'gpt-4'
        when 'analytical' then 'claude-3-sonnet'  
        when 'code' then 'codellama-34b'
        else 'gpt-3.5-turbo'
        end
puts "//config model #{model}"
```

## Model Performance Optimization

### Speed vs Quality Tradeoffs

#### Fast Models (Lower Cost, Quicker Response)
```bash
# Quick tasks, simple questions
aia --model gpt-3.5-turbo simple_question

# Code completion, basic analysis
aia --model claude-3-haiku code_completion

# Bulk processing
for file in *.txt; do
  aia --model gpt-3.5-turbo --out_file "${file%.txt}_processed.md" process_file "$file"
done
```

#### Quality Models (Higher Cost, Better Results)
```bash
# Complex analysis, important decisions
aia --model gpt-4 strategic_analysis.md

# Creative writing, nuanced tasks
aia --model claude-3-opus --temperature 1.0 creative_writing

# Critical code review
aia --model gpt-4 --temperature 0.2 security_review.py
```

### Context Window Management

#### Large Context Models
For processing large documents:
```bash
# Claude has the largest context window
aia --model claude-3-sonnet large_document.pdf

# GPT-4 Turbo for large contexts
aia --model gpt-4-turbo comprehensive_analysis.md
```

#### Context-Aware Processing
```bash
# Check document size and choose appropriate model
//ruby
file_size = File.size('<%= file %>') 
model = file_size > 100000 ? 'claude-3-sonnet' : 'gpt-4'
puts "//config model #{model}"

# Process with selected model
```

## Model Capabilities

### Vision Models
For image analysis and processing:
```bash
# Analyze images
aia --model gpt-4-vision image_analysis.jpg

# Process screenshots
aia --model gpt-4-vision --temperature 0.3 screenshot_analysis.png

# Extract text from images
aia --model gpt-4-vision extract_text_prompt image_with_text.jpg
```

### Function Calling Models
For tool integration:
```bash
# Models that support function calling
aia --model gpt-4 --tools ./tools/ analysis_with_tools

# Best function calling models
aia --model gpt-3.5-turbo --tools ./tools/ tool_heavy_task
```

### Code Models
Specialized for programming tasks:
```bash
# Code-specific models
aia --model codellama-34b code_generation_task

# Programming assistance
aia --model codellama-7b --temperature 0.1 debug_assistance
```

## Cost Management

### Model Pricing Considerations

#### Monitor Usage
```bash
# Enable verbose mode to see token usage
aia --verbose --model gpt-4 expensive_task

# Use debug mode for detailed cost tracking
aia --debug --model claude-3-opus cost_analysis
```

#### Cost-Effective Strategies
```bash
# Use cheaper models for initial drafts
aia --model gpt-3.5-turbo initial_draft

# Refine with better models
aia --model gpt-4 --include initial_draft.md refine_output

# Batch processing with efficient models
aia --model claude-3-haiku --pipeline "process,summarize" batch_files/
```

### Budget-Conscious Model Selection
```yaml
# Cost-effective configuration
budget_models:
  fast_tasks: gpt-3.5-turbo
  analysis: claude-3-haiku
  creative: gpt-3.5-turbo
  
premium_models:
  critical_analysis: gpt-4
  creative_writing: claude-3-sonnet
  complex_reasoning: claude-3-opus
```

## Model-Specific Tips

### GPT Models
- **GPT-4**: Best for complex reasoning, creative tasks
- **GPT-3.5 Turbo**: Fast, cost-effective, good general model
- **GPT-4 Vision**: Excellent for image analysis
- **Best for**: Code generation, creative writing, general tasks

### Claude Models  
- **Claude-3 Opus**: Highest quality, most expensive
- **Claude-3 Sonnet**: Great balance of quality and cost
- **Claude-3 Haiku**: Fastest, most cost-effective
- **Best for**: Long documents, analytical tasks, following instructions

### Gemini Models
- **Gemini Pro**: Google's flagship model
- **Gemini Pro Vision**: Multimodal capabilities
- **Best for**: Structured data, mathematical reasoning

### Specialized Models
- **CodeLlama**: Open-source code generation
- **Llama 2**: Open-source general purpose
- **Mixtral**: High-performance open model

## Troubleshooting Models

### Common Issues

#### Model Not Available
```bash
# Check if model exists
aia --available_models | grep model_name

# Try alternative model names
aia --available_models anthropic
```

#### Authentication Errors
```bash
# Check API keys
echo $OPENAI_API_KEY
echo $ANTHROPIC_API_KEY

# Test with working model
aia --model gpt-3.5-turbo test_prompt
```

#### Context Length Exceeded
```bash
# Use model with larger context
aia --model claude-3-sonnet large_document.pdf

# Split large inputs
split -l 1000 large_file.txt chunk_
for chunk in chunk_*; do
  aia --model gpt-4 process_chunk "$chunk"
done
```

#### Rate Limiting
```bash
# Add delays between requests
sleep 1 && aia --model gpt-4 request1
sleep 1 && aia --model gpt-4 request2

# Use different model to avoid limits
aia --model claude-3-sonnet alternative_processing
```

## Advanced Model Usage

### Model Switching Workflows
```bash
# Start with fast model for initial processing
aia --model gpt-3.5-turbo --out_file draft.md initial_analysis data.csv

# Switch to quality model for refinement
aia --model gpt-4 --include draft.md --out_file final.md refine_analysis

# Use specialized model for specific tasks
aia --model gpt-4-vision --include final.md image_analysis charts/
```

### Conditional Model Selection
```ruby
# Dynamic model selection based on task complexity
//ruby
content_length = File.read('<%= input_file %>').length
complexity = content_length > 10000 ? 'high' : 'low'

model = case complexity
        when 'high' then 'claude-3-sonnet'
        when 'low' then 'gpt-3.5-turbo'
        end
        
puts "//config model #{model}"
puts "Selected #{model} for #{complexity} complexity task"
```

### Model Ensemble Techniques
```bash
# Use different models for different aspects
aia --model gpt-4 --out_file technical_analysis.md technical_review code.py
aia --model claude-3-sonnet --out_file style_analysis.md style_review code.py
aia --model gpt-3.5-turbo --include technical_analysis.md --include style_analysis.md synthesize_reviews
```

## Integration with Other Features

### Chat Mode Model Management
```bash
# Start chat with specific model
aia --chat --model gpt-4

# Switch models during chat
You: /model claude-3-sonnet
AI: Switched to claude-3-sonnet

# Compare models in chat
You: //compare "Explain this concept" --models gpt-4,claude-3-sonnet
```

### Pipeline Model Configuration
```bash
# Different models for different pipeline stages
aia --config_file pipeline_config.yml --pipeline "extract,analyze,report"

# pipeline_config.yml
extract:
  model: gpt-3.5-turbo
analyze:
  model: claude-3-sonnet
report:
  model: gpt-4
```

### Tool Integration
```bash
# Use models optimized for function calling with tools
aia --model gpt-3.5-turbo --tools ./analysis_tools/ data_processing

# Vision models with image processing tools
aia --model gpt-4-vision --tools ./image_tools/ visual_analysis
```

## Related Documentation

- [Available Models](available-models.md) - Complete model list
- [Configuration](../configuration.md) - Model configuration options
- [CLI Reference](../cli-reference.md) - Command-line model options
- [Chat Mode](chat.md) - Interactive model usage
- [Advanced Prompting](../advanced-prompting.md) - Model-specific prompting techniques

---

Choosing the right model for each task is crucial for optimal results. Experiment with different models to find what works best for your specific use cases!