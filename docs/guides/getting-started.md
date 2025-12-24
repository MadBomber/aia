# Getting Started with AIA

This guide will walk you through your first steps with AIA, from basic usage to creating your first prompts and workflows.

## Prerequisites

Before starting, make sure you have:

- [Installed AIA](../installation.md)
- Set up your API keys (see [Installation](../installation.md#4-set-up-api-keys))
- Created your prompts directory (`~/.prompts`)

## Your First AIA Command

Let's start with the simplest possible usage:

```bash
aia --chat
```

This opens an interactive chat session. Type your question and press Enter:

```
You: Hello, what can you help me with?
AI: Hello! I'm an AI assistant that can help you with a wide variety of tasks...
```

Type `exit` or press Ctrl+C to end the chat.

## Basic Usage Patterns

### 1. Direct Questions

Ask questions directly without creating prompt files:

```bash
# Simple question
aia --chat "What's the capital of France?"

# Technical question
aia --chat "Explain how HTTP works"
```

### 2. Using Different Models

Specify which AI model to use:

```bash
# Use GPT-4
aia --model gpt-4 --chat

# Use Claude
aia --model claude-3-sonnet --chat

# See all available models
aia --available-models
```

### 3. Adjusting AI Behavior

Control the AI's response style:

```bash
# More creative responses
aia --temperature 1.2 --chat

# More focused responses  
aia --temperature 0.3 --chat

# Shorter responses
aia --terse --chat

# Limit response length
aia --max-tokens 100 --chat
```

## Creating Your First Prompt

Instead of typing questions each time, you can create reusable prompt files.

### 1. Create a Simple Prompt

```bash
# Create your first prompt file
echo "Explain this code and suggest improvements:" > ~/.prompts/code_review.txt
```

### 2. Use the Prompt

```bash
# Run the prompt (you'll be asked for the code to review)
aia code_review

# Or provide a context file
aia code_review my_script.py
```

### 3. Create a More Complex Prompt

```bash
cat > ~/.prompts/blog_writer.txt << 'EOF'
Write a professional blog post about the following topic:

Topic: <%= topic %>
Target audience: <%= audience %>
Word count: <%= word_count %>

Please include:
- An engaging introduction
- Well-structured main points
- A compelling conclusion
- SEO-friendly headings
EOF
```

Use it with parameters:

```bash
aia blog_writer --topic "AI productivity tools" --audience "developers" --word_count 800
```

## Understanding Prompts with Context

AIA can include context from files:

### 1. Review Code Files

```bash
# Review a specific file
aia code_review src/main.rb

# Review multiple files
aia code_review src/*.rb
```

### 2. Analyze Documents

```bash
# Analyze a document
echo "Summarize this document and extract key points:" > ~/.prompts/summarize.txt
aia summarize report.pdf
```

### 3. Process Data Files

```bash
# Create a data analysis prompt
echo "Analyze this data and provide insights:" > ~/.prompts/analyze_data.txt
aia analyze_data data.csv
```

## Using Directives

Prompts can include special directives for dynamic behavior:

### 1. Configuration Directives

```bash
cat > ~/.prompts/creative_writing.txt << 'EOF'
//config temperature 1.3
//config max_tokens 2000
//config model gpt-4

Write a creative short story about:
<%= topic %>

Make it engaging and unique!
EOF
```

### 2. File Inclusion Directives

```bash
cat > ~/.prompts/project_analysis.txt << 'EOF'
Analyze this project structure and provide recommendations:

//include README.md
//include package.json
//include src/

Focus on architecture, dependencies, and best practices.
EOF
```

### 3. Shell Command Directives

```bash
cat > ~/.prompts/system_status.txt << 'EOF'
Here's my current system status:

CPU Usage:
//shell top -l 1 -n 10 | head -20

Disk Usage:  
//shell df -h

Memory Usage:
//shell free -h

Please analyze this and suggest optimizations.
EOF
```

## Working with Roles

Roles help set context for the AI:

### 1. Create a Role File

```bash
mkdir -p ~/.prompts/roles
cat > ~/.prompts/roles/code_expert.txt << 'EOF'
You are an expert software developer with 15+ years of experience.
You specialize in clean code, best practices, and modern development patterns.
Always provide specific, actionable advice with code examples.
EOF
```

### 2. Use the Role

```bash
aia --role code_expert code_review my_app.rb
```

## Fuzzy Search (with fzf)

If you have `fzf` installed, you can use fuzzy search:

```bash
# Search for prompts interactively
aia --fuzzy

# This opens a searchable list of all your prompts
```

## Saving Output

Save AI responses to files:

```bash
# Save to a file
aia --output response.md my_prompt

# Append to an existing file
aia --output response.md --append my_prompt

# Format with Markdown
aia --output response.md --markdown my_prompt
```

## Chat Mode Features

### 1. Persistent Chat

```bash
# Start a chat that remembers context
aia --chat
```

Within chat:
- Your conversation history is maintained
- You can reference previous messages
- Type `/help` for chat commands
- Type `/save filename.md` to save the conversation

### 2. Chat with Initial Prompt

```bash
# Start chat with a specific role/prompt
aia --chat --role code_expert
aia --chat system_architect
```

### 3. Multi-turn Conversations

```bash
You: Explain REST APIs
AI: [Detailed explanation of REST APIs...]

You: Now give me a Python example
AI: [Python code example using the previous REST context...]

You: How would you test this?
AI: [Testing strategies specific to the Python example...]
```

## Common Workflows

### 1. Code Review Workflow

```bash
# Set up the workflow
echo "Review this code for bugs, style, and improvements:" > ~/.prompts/code_review.txt

# Use it regularly
aia code_review src/new_feature.py
aia --model claude-3-sonnet code_review complex_algorithm.rb
```

### 2. Documentation Workflow

```bash
# Create documentation prompt
cat > ~/.prompts/document_code.txt << 'EOF'
Generate comprehensive documentation for this code:

//include <%= file %>

Include:
- Purpose and functionality
- Parameters and return values
- Usage examples
- Edge cases and considerations
EOF

# Use it
aia document_code --file src/api.py
```

### 3. Learning Workflow

```bash
# Create learning prompt
cat > ~/.prompts/explain_concept.txt << 'EOF' 
//config temperature 0.7
//role teacher

Explain the concept of "<%= concept %>" in simple terms.

Include:
- Definition and core principles
- Real-world examples
- Common use cases
- Key benefits and drawbacks
- Related concepts

Adjust the explanation for a <%= level %> level understanding.
EOF

# Use it for learning
aia explain_concept --concept "microservices" --level "beginner"
aia explain_concept --concept "machine learning" --level "intermediate"
```

## Best Practices

### 1. Organize Your Prompts

```bash
# Create a logical directory structure
mkdir -p ~/.prompts/{development,writing,analysis,personal}

# Categorize prompts
mv ~/.prompts/code_review.txt ~/.prompts/development/
mv ~/.prompts/blog_writer.txt ~/.prompts/writing/
```

### 2. Use Descriptive Names

```bash
# Good prompt names
~/.prompts/development/code_review_security.txt
~/.prompts/writing/blog_post_technical.txt
~/.prompts/analysis/data_insights.txt

# Avoid generic names
~/.prompts/prompt1.txt
~/.prompts/test.txt
```

### 3. Version Control Your Prompts

```bash
cd ~/.prompts
git init
git add .
git commit -m "Initial prompt collection"

# Keep your prompts under version control
git add new_prompt.txt
git commit -m "Add prompt for API documentation"
```

### 4. Test Different Models

```bash
# Test with different models to find the best fit
aia --model gpt-3.5-turbo code_review app.py
aia --model gpt-4 code_review app.py  
aia --model claude-3-sonnet code_review app.py

# Compare outputs and choose the best model for each task
```

## Next Steps

Now that you understand the basics:

1. **Explore Advanced Features**:
   - [Chat Mode Guide](chat.md)
   - [Working with Models](models.md)
   - [Tools Integration](tools.md)

2. **Learn Advanced Techniques**:
   - [Advanced Prompting](../advanced-prompting.md)
   - [Workflows & Pipelines](../workflows-and-pipelines.md)
   - [Prompt Management](../prompt_management.md)

3. **Browse Examples**:
   - [Examples Directory](../examples/index.md)
   - [Tools & MCP Examples](../tools-and-mcp-examples.md)

4. **Reference Documentation**:
   - [CLI Reference](../cli-reference.md)
   - [Directives Reference](../directives-reference.md)
   - [Configuration Guide](../configuration.md)

## Troubleshooting

### Common Issues

#### "No prompt found"
- Check that the prompt file exists: `ls ~/.prompts/`
- Verify the filename matches what you're typing
- Try fuzzy search: `aia --fuzzy`

#### "Model not available"
- Check your API keys: `echo $OPENAI_API_KEY`
- List available models: `aia --available-models`
- Check your internet connection

#### "Permission denied"
- Check file permissions: `ls -la ~/.prompts/`
- Ensure the prompts directory is readable

### Getting Help

- Use `aia --help` for command help
- Use `--verbose` flag to see what AIA is doing
- Use `--debug` flag for detailed debugging information
- Check the [FAQ](../faq.md) for common questions
- Report issues on [GitHub](https://github.com/MadBomber/aia/issues)

## Summary

You've learned:

- ✅ How to run basic AIA commands
- ✅ How to create and use prompts
- ✅ How to work with different AI models
- ✅ How to use roles and context files
- ✅ How to organize your workflow
- ✅ Basic troubleshooting

You're now ready to explore AIA's more advanced features and create your own AI-powered workflows!