# Working with Models

AIA supports multiple AI models through the RubyLLM gem, allowing you to choose the best model for each task and even use multiple models simultaneously.

## Available Models

### List All Models
```bash
# Show all available models
aia --available-models

# Filter by provider
aia --available-models openai
aia --available-models anthropic
aia --available-models google

# Filter by capability
aia --available-models vision
aia --available-models function_calling
aia --available-models text_to_image

# Complex filtering
aia --available-models openai,gpt,4
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

### Token Usage and Cost Tracking

One of AIA's most powerful capabilities is real-time tracking of token usage and cost estimates across multiple models. This enables informed decisions about model selection based on both quality and cost.

#### Enabling Token Tracking

```bash
# Display token usage for each model
aia my_prompt -m gpt-4o,claude-3-sonnet --tokens

# Include cost estimates (automatically enables --tokens)
aia my_prompt -m gpt-4o,claude-3-sonnet --cost

# In chat mode with full tracking
aia --chat -m gpt-4o,claude-3-sonnet,gemini-pro --cost
```

#### Multi-Model Comparison with Metrics

```bash
# Compare 3 models with cost tracking
aia --chat -m gpt-4o,claude-3-5-sonnet,gemini-1.5-pro --cost
```

**Example Output:**
```
You: Explain the CAP theorem and its implications for distributed databases.

from: gpt-4o
The CAP theorem states that a distributed system can only guarantee two of three properties...

from: claude-3-5-sonnet
CAP theorem, proposed by Eric Brewer, describes fundamental trade-offs in distributed systems...

from: gemini-1.5-pro
The CAP theorem is a cornerstone principle in distributed computing that states...

┌─────────────────────────────────────────────────────────────────┐
│ Model               │ Input Tokens │ Output Tokens │ Cost      │
├─────────────────────────────────────────────────────────────────┤
│ gpt-4o              │ 42           │ 287           │ $0.0068   │
│ claude-3-5-sonnet   │ 42           │ 312           │ $0.0053   │
│ gemini-1.5-pro      │ 42           │ 298           │ $0.0038   │
└─────────────────────────────────────────────────────────────────┘
Total: $0.0159
```

#### Use Cases for Token/Cost Tracking

| Use Case | Description |
|----------|-------------|
| **Budget Management** | Monitor API costs in real-time during development |
| **Model Evaluation** | Compare quality vs. cost across different providers |
| **Cost Optimization** | Identify the most cost-effective model for your tasks |
| **Usage Auditing** | Track token consumption for billing and optimization |
| **A/B Testing** | Compare model performance with objective metrics |

#### Combining with Consensus Mode

```bash
# Get consensus response with cost breakdown
aia my_prompt -m gpt-4o,claude-3-sonnet,gemini-pro --consensus --cost

# The consensus response shows combined metrics:
# Tokens: input=126 (total), output=892 (consensus + individual)
# Cost: $0.0189 (all models combined)
```

#### Environment Variables

```bash
# Enable token tracking by default
export AIA_FLAGS__TOKENS=true

# Enable cost tracking by default
export AIA_FLAGS__COST=true
```

### Per-Model Roles

Assign specific roles to each model in multi-model mode to get diverse perspectives on your prompts. Each model receives a prepended role prompt that shapes its perspective.

#### Inline Role Syntax

Use the `MODEL=ROLE` syntax to assign roles directly on the command line:

```bash
# Single model with role
aia --model gpt-4o=architect design_review.md

# Multiple models with different roles
aia --model gpt-4o=architect,claude=security,gemini=performance design_review.md

# Mixed: some models with roles, some without
aia --model gpt-4o=expert,claude analyze.md
```

#### Multiple Perspectives

Use the same model multiple times with different roles for diverse viewpoints:

```bash
# Three instances of same model with different roles
aia --model gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist project_plan.md

# AI provides three distinct perspectives on the same input
```

**Output Format with Roles:**
```
from: gpt-4o (optimist)
I see great potential in this approach! The architecture is solid...

from: gpt-4o #2 (pessimist)
We need to consider several risks here. The design has some concerning...

from: gpt-4o #3 (realist)
Let's look at this pragmatically. The proposal has both strengths and...
```

**Note**: When using duplicate models, AIA automatically numbers them (e.g., `gpt-4o`, `gpt-4o #2`, `gpt-4o #3`) and maintains separate conversation contexts for each instance.

#### Role Discovery

List all available roles in your prompts directory:

```bash
# List all roles
aia --list-roles

# Output shows role IDs and descriptions
Available roles in /Users/you/.prompts/roles:
  architect    - Software architecture expert
  security     - Security analysis specialist
  performance  - Performance optimization expert
  optimist     - Positive perspective analyzer
  pessimist    - Critical risk analyzer
  realist      - Balanced pragmatic analyzer
```

#### Role Files

Roles are stored as text files in your prompts directory:

```bash
# Default location: ~/.prompts/roles/
~/.prompts/
  roles/
    architect.txt
    security.txt
    performance.txt
    optimist.txt
    pessimist.txt
    realist.txt

# Nested role organization
~/.prompts/
  roles/
    software/
      architect.txt
      developer.txt
    analysis/
      optimist.txt
      pessimist.txt
      realist.txt
```

**Using Nested Roles:**
```bash
# Specify full path from roles directory
aia --model gpt-4o=software/architect,claude=analysis/pessimist design.md
```

#### Configuration File Format

Define model roles in your configuration file using array format:

```yaml
# ~/.aia/config.yml
model:
  - model: gpt-4o
    role: architect
  - model: claude-3-sonnet
    role: security
  - model: gemini-pro
    role: performance

# Duplicate models with different roles
model:
  - model: gpt-4o
    role: optimist
  - model: gpt-4o
    role: pessimist
  - model: gpt-4o
    role: realist
```

**Note**: Models without roles work normally - simply omit the `role` key.

#### Environment Variable Usage

Set model roles via environment variables using the same inline syntax:

```bash
# Single model with role
export AIA_MODEL="gpt-4o=architect"

# Multiple models with roles
export AIA_MODEL="gpt-4o=architect,claude=security,gemini=performance"

# Duplicate models
export AIA_MODEL="gpt-4o=optimist,gpt-4o=pessimist,gpt-4o=realist"

# Then run AIA normally
aia design_review.md
```

#### Role Configuration Precedence

When roles are specified in multiple places, the precedence order is:

1. **CLI inline syntax**: `--model gpt-4o=architect` (highest priority)
2. **CLI role flag**: `--role architect` (applies to all models)
3. **Environment variable**: `AIA_MODEL="gpt-4o=architect"`
4. **Configuration file**: `model: [{model: gpt-4o, role: architect}]`

**Example of precedence:**
```bash
# Config file specifies: model: [{model: gpt-4o, role: architect}]
# Environment has: AIA_MODEL="claude=security"
# Command line uses:
aia --model gemini=performance my_prompt

# Result: Uses gemini with performance role (CLI wins)
```

#### Role Validation

AIA validates role files exist at parse time and provides helpful error messages:

```bash
# If role file doesn't exist
$ aia --model gpt-4o=nonexistent my_prompt

ERROR: Role file not found: ~/.prompts/roles/nonexistent.txt

Available roles:
  - architect
  - security
  - performance
  - optimist
  - pessimist
  - realist
```

#### Creating Custom Roles

Create new role files in your roles directory:

```bash
# Create a new role
cat > ~/.prompts/roles/debugger.txt << 'EOF'
You are an expert debugging assistant. When analyzing code:
- Focus on identifying potential bugs and edge cases
- Suggest specific debugging strategies
- Explain the root cause of issues clearly
- Provide actionable fix recommendations
EOF

# Use the new role
aia --model gpt-4o=debugger analyze_bug.py
```

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
  aia --model gpt-3.5-turbo --output "${file%.txt}_processed.md" process_file "$file"
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

## Local Model Providers

### Ollama

[Ollama](https://ollama.ai) enables running open-source AI models locally.

#### Setup

```bash
# Install Ollama
brew install ollama  # macOS
# or download from https://ollama.ai

# Pull models
ollama pull llama3.2
ollama pull mistral
ollama pull qwen2.5-coder

# List available models
ollama list
```

#### Usage with AIA

```bash
# Use Ollama model (prefix with 'ollama/')
aia --model ollama/llama3.2 my_prompt

# Chat mode
aia --chat --model ollama/mistral

# List Ollama models from AIA
aia --model ollama/llama3.2 --chat
> //models

# Combine with cloud models for comparison
aia --model ollama/llama3.2,gpt-4o-mini,claude-3-sonnet my_prompt
```

#### Configuration

```yaml
# ~/.aia/config.yml
model: ollama/llama3.2

# Optional: Custom Ollama endpoint
# Set via environment variable
export OLLAMA_API_BASE=http://custom-host:11434
```

#### Popular Ollama Models

- **llama3.2**: Latest Llama model, good general purpose
- **llama3.2:70b**: Larger version, better quality
- **mistral**: Fast and efficient
- **mixtral**: High-performance mixture of experts
- **qwen2.5-coder**: Specialized for code
- **codellama**: Code-focused model

### LM Studio

[LM Studio](https://lmstudio.ai) provides a GUI for running local models with OpenAI-compatible API.

#### Setup

1. Download LM Studio from https://lmstudio.ai
2. Install and launch the application
3. Browse and download models within LM Studio
4. Start the local server:
   - Click "Local Server" tab
   - Click "Start Server"
   - Default endpoint: http://localhost:1234/v1

#### Usage with AIA

```bash
# Use LM Studio model (prefix with 'lms/')
aia --model lms/qwen/qwen3-coder-30b my_prompt

# Chat mode
aia --chat --model lms/llama-3.2-3b-instruct

# List LM Studio models from AIA
aia --model lms/any-loaded-model --chat
> //models

# Model validation
# AIA validates model names against LM Studio's loaded models
# If you specify an invalid model, you'll see:
#   ❌ 'model-name' is not a valid LM Studio model.
#
#   Available LM Studio models:
#     - lms/qwen/qwen3-coder-30b
#     - lms/llama-3.2-3b-instruct
```

#### Configuration

```yaml
# ~/.aia/config.yml
model: lms/qwen/qwen3-coder-30b

# Optional: Custom LM Studio endpoint
# Set via environment variable
export LMS_API_BASE=http://localhost:1234/v1
```

#### Tips for LM Studio

- Use the model name exactly as shown in LM Studio
- Prefix all model names with `lms/`
- Ensure the local server is running before use
- LM Studio supports one model at a time (unlike Ollama)

### Comparison: Ollama vs LM Studio

| Feature | Ollama | LM Studio |
|---------|--------|-----------|
| **Interface** | Command-line | GUI + CLI |
| **Model Management** | Via CLI (`ollama pull`) | GUI download |
| **API Compatibility** | Custom + OpenAI-like | OpenAI-compatible |
| **Multiple Models** | Yes (switch quickly) | One at a time |
| **Platform** | macOS, Linux, Windows | macOS, Windows |
| **Model Format** | GGUF, custom | GGUF |
| **Best For** | CLI users, automation | GUI users, experimentation |

### Local + Cloud Model Workflows

#### Privacy-First Workflow
```bash
# Use local model for sensitive data
aia --model ollama/llama3.2 --output draft.md process_private_data.txt

# Use cloud model for final polish (on sanitized data)
aia --model gpt-4 --include draft.md refine_output
```

#### Cost-Optimization Workflow
```bash
# Bulk processing with local model (free)
for file in *.txt; do
  aia --model ollama/mistral --output "${file%.txt}_summary.md" summarize "$file"
done

# Final review with premium cloud model
aia --model gpt-4 --include *_summary.md final_report
```

#### Consensus with Mixed Models
```bash
# Get consensus from local and cloud models
aia --model ollama/llama3.2,ollama/mistral,gpt-4o-mini --consensus decision_prompt

# Or individual responses to compare
aia --model ollama/llama3.2,lms/qwen-coder,claude-3-sonnet --no-consensus code_review.py
```

## Troubleshooting Models

### Common Issues

#### Model Not Available
```bash
# Check if model exists
aia --available-models | grep model_name

# Try alternative model names
aia --available-models anthropic
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
aia --model gpt-3.5-turbo --output draft.md initial_analysis data.csv

# Switch to quality model for refinement
aia --model gpt-4 --include draft.md --output final.md refine_analysis

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
aia --model gpt-4 --output technical_analysis.md technical_review code.py
aia --model claude-3-sonnet --output style_analysis.md style_review code.py
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
aia --config-file pipeline_config.yml --pipeline "extract,analyze,report"

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