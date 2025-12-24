# Available Models

AIA supports a wide range of AI models through the RubyLLM gem. This comprehensive list shows all supported models, their capabilities, and best use cases.

## Viewing Available Models

### Command Line Query
```bash
# List all available models
aia --available-models

# Filter by provider
aia --available-models openai
aia --available-models anthropic
aia --available-models google

# Filter by capability
aia --available-models vision
aia --available-models function_calling
aia --available-models text_to_image

# Complex filtering (AND operation)
aia --available-models openai,gpt,4
aia --available-models anthropic,claude,sonnet
```

### Within Prompts
```markdown
# List models in a prompt
//available_models

# Filter models
//available_models openai,gpt
```

## Model Categories

### OpenAI Models

#### GPT-4 Family
- **gpt-4**: Most capable model, excellent for complex reasoning
  - Context: 8,192 tokens
  - Best for: Complex analysis, creative writing, code generation
  - Cost: Higher, but highest quality

- **gpt-4-turbo**: Faster GPT-4 with larger context
  - Context: 128,000 tokens
  - Best for: Long documents, comprehensive analysis
  - Cost: Lower than GPT-4, faster responses

- **gpt-4-vision-preview**: GPT-4 with image understanding
  - Context: 128,000 tokens (including images)
  - Best for: Image analysis, visual content creation
  - Capabilities: Text + image input, text output

#### GPT-3.5 Family
- **gpt-3.5-turbo**: Fast, cost-effective general purpose
  - Context: 4,096 tokens
  - Best for: General queries, quick tasks, batch processing
  - Cost: Most economical

- **gpt-3.5-turbo-16k**: Extended context version
  - Context: 16,384 tokens
  - Best for: Longer documents, extended conversations
  - Cost: Moderate

#### Specialized OpenAI Models
- **text-davinci-003**: Legacy completion model
- **code-davinci-002**: Code-optimized model
- **text-embedding-ada-002**: Text embedding model

### Anthropic Claude Models

#### Claude-3 Family
- **claude-3-opus**: Highest capability Claude model
  - Context: 200,000 tokens
  - Best for: Complex analysis, long documents, nuanced tasks
  - Cost: Premium pricing

- **claude-3-sonnet**: Balanced performance and cost
  - Context: 200,000 tokens  
  - Best for: Most general tasks, good balance
  - Cost: Moderate

- **claude-3-haiku**: Fastest, most economical
  - Context: 200,000 tokens
  - Best for: Quick tasks, batch processing, simple queries
  - Cost: Most economical

#### Claude-2 Family (Legacy)
- **claude-2**: Previous generation
  - Context: 100,000 tokens
  - Best for: Long-form content, analysis
  - Status: Being phased out

### Google Models

#### Gemini Family
- **gemini-pro**: Google's flagship model
  - Context: 32,000 tokens
  - Best for: Reasoning, structured data, math
  - Features: Multimodal capabilities

- **gemini-pro-vision**: Gemini with vision
  - Context: 32,000 tokens (including images)
  - Best for: Image understanding, visual analysis
  - Capabilities: Text + image input

#### PaLM Family
- **text-bison**: Text generation model
- **chat-bison**: Conversational model

### Open Source Models (via Ollama)

#### Llama 2 Family
- **llama2-7b**: 7 billion parameter model
  - Best for: Local deployment, privacy-sensitive tasks
  - Requirements: 8GB+ RAM

- **llama2-13b**: 13 billion parameter model
  - Best for: Better quality local processing
  - Requirements: 16GB+ RAM

- **llama2-70b**: 70 billion parameter model
  - Best for: Highest quality local processing
  - Requirements: 64GB+ RAM

#### Code Llama
- **codellama-7b**: Code-specialized 7B model
- **codellama-13b**: Code-specialized 13B model
- **codellama-34b**: Code-specialized 34B model

#### Other Open Models
- **mistral-7b**: Efficient general-purpose model
- **mixtral-8x7b**: Mixture of experts model
- **phi-2**: Microsoft's compact model
- **orca-2**: Microsoft's reasoning-focused model

## Model Capabilities

### Text Generation
**All models support**: Basic text generation, question answering, summarization

**Best performers**:
- Complex reasoning: GPT-4, Claude-3-Opus
- Creative writing: GPT-4, Claude-3-Sonnet
- Technical writing: Claude-3-Sonnet, GPT-4

### Code Understanding and Generation
**Code-optimized models**:
- CodeLlama family (7B, 13B, 34B)
- GPT-4 (excellent general code understanding)
- Claude-3-Sonnet (good at following coding standards)

**Capabilities**:
- Code generation and completion
- Bug detection and fixing
- Code explanation and documentation
- Refactoring suggestions

### Vision and Multimodal
**Image understanding models**:
- GPT-4 Vision Preview
- Gemini Pro Vision
- Claude-3 (limited vision capabilities)

**Capabilities**:
- Image description and analysis
- Chart and diagram interpretation
- OCR and text extraction
- Visual question answering

### Function Calling and Tools
**Tool-compatible models**:
- GPT-3.5-turbo (excellent function calling)
- GPT-4 (sophisticated tool usage)
- Claude-3-Sonnet (good tool integration)

**Use cases**:
- API integrations
- Database queries
- File system operations
- External service calls

## Choosing the Right Model

### By Task Type

#### Quick Tasks and Batch Processing
```bash
# Fast, economical models
aia --model gpt-3.5-turbo simple_task
aia --model claude-3-haiku batch_processing
```

#### Complex Analysis and Reasoning
```bash
# High-capability models
aia --model gpt-4 complex_analysis
aia --model claude-3-opus comprehensive_research
```

#### Code-Related Tasks
```bash
# Code-optimized models
aia --model codellama-34b code_generation
aia --model gpt-4 code_review
```

#### Long Documents
```bash
# Large context models
aia --model claude-3-sonnet long_document.pdf
aia --model gpt-4-turbo comprehensive_analysis.md
```

#### Image Analysis
```bash
# Vision-capable models
aia --model gpt-4-vision-preview image_analysis.jpg
aia --model gemini-pro-vision chart_interpretation.png
```

### By Budget Considerations

#### Cost-Effective Options
- **gpt-3.5-turbo**: Best general-purpose budget option
- **claude-3-haiku**: Anthropic's economical choice
- **Local models**: Ollama-based models (compute cost only)

#### Premium Options
- **gpt-4**: OpenAI's flagship
- **claude-3-opus**: Anthropic's highest capability
- **gpt-4-turbo**: Large context with good performance

### By Privacy and Security

#### Cloud-Based (Standard)
- OpenAI models (GPT-3.5, GPT-4)
- Anthropic models (Claude-3 family)
- Google models (Gemini family)

#### Local/Self-Hosted
- Ollama models (Llama 2, CodeLlama, Mistral)
- Privacy-focused deployment
- Full control over data

## Model Configuration Examples

### Development Workflow
```yaml
# Different models for different stages
development:
  quick_tasks: gpt-3.5-turbo
  code_review: gpt-4
  documentation: claude-3-sonnet
  testing: codellama-13b
```

### Content Creation Workflow
```yaml
content:
  research: claude-3-sonnet
  drafting: gpt-4
  editing: claude-3-opus
  seo_optimization: gpt-3.5-turbo
```

### Analysis Workflow
```yaml
analysis:
  data_exploration: claude-3-sonnet
  statistical_analysis: gemini-pro
  insights: gpt-4
  reporting: claude-3-haiku
```

## Model Performance Comparison

### Speed (Responses per minute)
1. **gpt-3.5-turbo**: ~60 RPM
2. **claude-3-haiku**: ~50 RPM
3. **gemini-pro**: ~40 RPM
4. **gpt-4**: ~20 RPM
5. **claude-3-opus**: ~15 RPM

### Context Window Size
1. **Claude-3 family**: 200,000 tokens
2. **GPT-4-turbo**: 128,000 tokens
3. **Gemini-pro**: 32,000 tokens
4. **GPT-3.5-turbo-16k**: 16,384 tokens
5. **GPT-4**: 8,192 tokens

### Cost Efficiency (approximate)
1. **gpt-3.5-turbo**: Most economical
2. **claude-3-haiku**: Very economical
3. **gemini-pro**: Moderate
4. **claude-3-sonnet**: Moderate-high
5. **gpt-4**: Premium
6. **claude-3-opus**: Most expensive

## Advanced Model Usage

### Multi-Model Strategies
```bash
# Use different models for different aspects
aia --model gpt-3.5-turbo initial_analysis.txt
aia --model gpt-4 --include initial_analysis.txt detailed_review.txt
aia --model claude-3-sonnet --include detailed_review.txt final_synthesis.txt
```

### Model Switching Based on Content
```ruby
# Dynamic model selection
//ruby
content_size = File.read('<%= input %>').length
complexity = content_size > 10000 ? 'high' : 'low'

model = case complexity
        when 'high' then 'claude-3-sonnet'
        when 'low' then 'gpt-3.5-turbo'
        end
        
puts "//config model #{model}"
```

### Fallback Strategies
```ruby
# Model fallback chain
//ruby
preferred_models = ['gpt-4', 'claude-3-sonnet', 'gpt-3.5-turbo']
available_models = `aia --available-models`.split("\n").map { |line| line.split.first }

selected_model = preferred_models.find { |model| available_models.include?(model) }
puts "//config model #{selected_model || 'gpt-3.5-turbo'}"
```

## Staying Current

### Model Updates
- **Check regularly**: `aia --available-models`
- **Version changes**: Models are updated periodically
- **New releases**: Follow provider announcements
- **Deprecations**: Some models may be retired

### Performance Monitoring
```bash
# Test model performance
time aia --model gpt-4 test_prompt
time aia --model claude-3-sonnet test_prompt

# Compare outputs
aia --model "gpt-4,claude-3-sonnet" --no-consensus comparison_test
```

## Related Documentation

- [Working with Models](models.md) - Model selection and configuration
- [Configuration](../configuration.md) - Model configuration options
- [CLI Reference](../cli-reference.md) - Model-related command-line options
- [Chat Mode](chat.md) - Interactive model usage
- [Advanced Prompting](../advanced-prompting.md) - Model-specific techniques

---

The AI landscape evolves rapidly. Regularly check for new models and updates to ensure you're using the best tools for your specific needs!