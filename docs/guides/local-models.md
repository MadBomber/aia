# Local Models Guide

Complete guide to using Ollama and LM Studio with AIA for local AI processing.

## Why Use Local Models?

### Benefits

- 🔒 **Privacy**: All processing happens on your machine
- 💰 **Cost**: No API fees
- 🚀 **Speed**: No network latency
- 📡 **Offline**: Works without internet
- 🔧 **Control**: Choose exact model and parameters
- 📦 **Unlimited**: No rate limits or quotas

### Use Cases

- Processing confidential business data
- Working with personal information
- Development and testing
- High-volume batch processing
- Air-gapped environments
- Learning and experimentation

## Ollama Setup

### Installation

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Windows
# Download installer from https://ollama.ai
```

### Model Management

```bash
# List available models
ollama list

# Pull new models
ollama pull llama3.2
ollama pull mistral
ollama pull codellama

# Remove models
ollama rm model-name

# Show model info
ollama show llama3.2
```

### Using with AIA

```bash
# Basic usage - prefix with 'ollama/'
aia --model ollama/llama3.2 my_prompt

# Chat mode
aia --chat --model ollama/mistral

# Batch processing
for file in *.md; do
  aia --model ollama/llama3.2 summarize "$file"
done
```

### Recommended Ollama Models

#### General Purpose
- `llama3.2` - Versatile, good quality
- `llama3.2:70b` - Higher quality, slower
- `mistral` - Fast, efficient

#### Code
- `qwen2.5-coder` - Excellent for code
- `codellama` - Code-focused
- `deepseek-coder` - Programming tasks

#### Specialized
- `mixtral` - High performance
- `phi3` - Small, efficient
- `gemma2` - Google's open model

## LM Studio Setup

### Installation

1. Download from https://lmstudio.ai
2. Install the application
3. Launch LM Studio

### Model Management

1. Click "🔍 Search" tab
2. Browse or search for models
3. Click download button
4. Wait for download to complete

### Starting Local Server

1. Click "💻 Local Server" tab
2. Select loaded model from dropdown
3. Click "Start Server"
4. Note the endpoint (default: http://localhost:1234/v1)

### Using with AIA

```bash
# Prefix model name with 'lms/'
aia --model lms/qwen/qwen3-coder-30b my_prompt

# Chat mode
aia --chat --model lms/llama-3.2-3b-instruct

# AIA validates model names
# Error shows available models if name is wrong
```

### Popular LM Studio Models

- `lmsys/vicuna-7b` - Conversation
- `TheBloke/Llama-2-7B-Chat-GGUF` - Chat
- `TheBloke/CodeLlama-7B-GGUF` - Code
- `qwen/qwen3-coder-30b` - Advanced coding

## Configuration

### Environment Variables

```bash
# Ollama custom endpoint
export OLLAMA_API_BASE=http://localhost:11434

# LM Studio custom endpoint
export LMS_API_BASE=http://localhost:1234/v1
```

### Config File

```yaml
# ~/.aia/config.yml
model: ollama/llama3.2

# Or for LM Studio
model: lms/qwen/qwen3-coder-30b
```

### In Prompts

```
//config model = ollama/mistral
//config temperature = 0.7

Your prompt here...
```

## Listing Models

### In Chat Session

```bash
aia --model ollama/llama3.2 --chat
> //models
```

**Ollama Output:**
```
Local LLM Models:

Ollama Models (http://localhost:11434):
------------------------------------------------------------
- ollama/llama3.2:latest (size: 2.0 GB, modified: 2024-10-01)
- ollama/mistral:latest (size: 4.1 GB, modified: 2024-09-28)

2 Ollama model(s) available
```

**LM Studio Output:**
```
Local LLM Models:

LM Studio Models (http://localhost:1234/v1):
------------------------------------------------------------
- lms/qwen/qwen3-coder-30b
- lms/llama-3.2-3b-instruct

2 LM Studio model(s) available
```

## Advanced Usage

### Mixed Local/Cloud Models

```bash
# Compare local and cloud responses
aia --model ollama/llama3.2,gpt-4o-mini,claude-3-sonnet analysis_prompt

# Get consensus
aia --model ollama/llama3.2,ollama/mistral,gpt-4 --consensus decision_prompt
```

### Local-First Workflow

```bash
# 1. Process with local model (private)
aia --model ollama/llama3.2 --output draft.md sensitive_data.txt

# 2. Review and sanitize draft.md manually

# 3. Polish with cloud model
aia --model gpt-4 --include draft.md final_output
```

### Cost Optimization

```bash
# Bulk tasks with local model
for i in {1..1000}; do
  aia --model ollama/mistral --output "result_$i.md" process "input_$i.txt"
done

# No API costs!
```

## Troubleshooting

### Ollama Issues

**Problem:** "Cannot connect to Ollama"
```bash
# Check if Ollama is running
ollama list

# Start Ollama service (if needed)
ollama serve
```

**Problem:** "Model not found"
```bash
# List installed models
ollama list

# Pull missing model
ollama pull llama3.2
```

### LM Studio Issues

**Problem:** "Cannot connect to LM Studio"
1. Ensure LM Studio is running
2. Check local server is started
3. Verify endpoint in settings

**Problem:** "Model validation failed"
- Check exact model name in LM Studio
- Ensure model is loaded (not just downloaded)
- Use full model path with `lms/` prefix

**Problem:** "Model not listed"
1. Load model in LM Studio
2. Start local server
3. Run `//models` directive

### Performance Issues

**Slow responses:**
- Use smaller models (7B instead of 70B)
- Reduce max_tokens
- Check system resources (CPU/RAM/GPU)

**High memory usage:**
- Close other applications
- Use quantized models (Q4, Q5)
- Try smaller model variants

## Best Practices

### Security
✅ Keep local models for sensitive data
✅ Use cloud models for general tasks
✅ Review outputs before sharing externally

### Performance
✅ Use appropriate model size for task
✅ Leverage GPU if available
✅ Cache common responses

### Cost Management
✅ Use local models for development/testing
✅ Use local models for high-volume processing
✅ Reserve cloud models for critical tasks

## Related Documentation

- [Models Guide](models.md)
- [Configuration](../configuration.md)
- [Chat Mode](chat.md)
- [CLI Reference](../cli-reference.md)
