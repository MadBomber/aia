# Chat Mode Guide

AIA's chat mode provides interactive conversations with AI models, maintaining context and supporting advanced features like multi-model interactions, tool usage, and persistent sessions.

## Starting a Chat Session

### Basic Chat
```bash
# Start an interactive chat session
aia --chat

# Start chat with a specific model
aia --chat --model gpt-4

# Start chat with initial context
aia --chat --role assistant my_context.txt
```

### Chat with Initial Prompts
```bash
# Begin chat after processing a prompt
aia --chat my_initial_prompt

# Chat with system prompt
aia --chat --system-prompt helpful_assistant

# Chat with role-based context
aia --chat --role code_expert debugging_session
```

## Chat Interface

### Basic Commands
Once in chat mode, you can use these commands:

- **Regular messages**: Type normally and press Enter
- **`/help`**: Show available chat commands
- **`/exit`** or **`/quit`**: End the chat session
- **`/clear`**: Clear conversation history
- **`/save filename.md`**: Save conversation to file
- **`/model model_name`**: Switch AI model
- **`/temperature 0.8`**: Adjust creativity level
- **`/tools`**: List available tools
- **`/context`**: Show current context

### Special Features

#### Multi-line Input
```
You: ```
This is a multi-line input.
You can write code, long explanations,
or complex queries across multiple lines.
```

#### File Upload During Chat
```
You: Please analyze this file:
//include my_data.csv

What patterns do you see?
```

#### Code Execution
```
The current date and time is:
//ruby Time.now

Files in the current directory are:
//shell ls -la

which files are over 1 week old?
```

## Advanced Chat Features

### Multi-Model Conversations

#### Consensus Mode
```bash
# Start chat with multiple models seeking consensus
aia --chat --model "gpt-4,claude-3-sonnet,gemini-pro" --consensus

# Models will collaborate to provide unified responses
```

#### Parallel Responses
```bash
# Get responses from multiple models simultaneously
aia --chat --model "gpt-4,claude-3-sonnet" --no-consensus

# You'll see separate responses from each model
```

#### Model Comparison
```
You: Compare these approaches to solving the problem:
//compare "Explain recursion vs iteration" --models gpt-4,claude-3-sonnet

Which explanation is clearer?
```

### Context Management

#### Persistent Context
AIA maintains conversation context automatically:
```
You: I'm working on a Python web application using Flask.
AI: Great! Flask is an excellent choice for web development...

You: How do I handle user authentication?
AI: For your Flask application, here are several authentication options...
```

#### Context Checkpoints
Create savepoints in your conversation to easily return to specific moments:

```
You: Let's explore different authentication approaches for Flask.
AI: I can help you explore various authentication methods...

You: //checkpoint auth_start

You: Tell me about JWT authentication.
AI: JWT (JSON Web Tokens) authentication is a stateless approach...

You: //checkpoint jwt_discussion

You: What about OAuth integration?
AI: OAuth provides a robust framework for authentication...

You: Actually, let's go back to the JWT discussion
You: //restore jwt_discussion

You: //context
=== Chat Context ===
Total messages: 6
Checkpoints: auth_start, jwt_discussion

1. [System]: You are a helpful assistant
2. [User]: Let's explore different authentication approaches for Flask.
3. [Assistant]: I can help you explore various authentication methods...

📍 [Checkpoint: auth_start]
----------------------------------------
4. [User]: Tell me about JWT authentication.
5. [Assistant]: JWT (JSON Web Tokens) authentication is a stateless approach...

📍 [Checkpoint: jwt_discussion]
----------------------------------------
=== End of Context ===
```

**Checkpoint Commands**:
- `//checkpoint` - Create auto-numbered checkpoint (1, 2, 3...)
- `//checkpoint name` - Create named checkpoint
- `//restore` - Restore to last checkpoint
- `//restore name` - Restore to specific checkpoint
- `//cp name` - Short alias for checkpoint

**Use Cases for Checkpoints**:
- **Exploring alternatives**: Save before trying different approaches
- **Debugging conversations**: Return to working state after errors
- **Session branching**: Explore multiple conversation paths
- **Learning sessions**: Bookmark important explanations

#### Context Inspection
```
You: //context
# Shows current conversation history with checkpoint markers

You: //review
# Alternative command for context inspection
```

#### Context Clearing
```
You: //clear
# Clears conversation history and all checkpoints while keeping session active
```

### Tool Integration in Chat

#### Enabling Tools
```bash
# Start chat with specific tools
aia --chat --tools ./my_tools.rb

# Start with tool directory
aia --chat --tools ./tools/

# Restrict tool access
aia --chat --tools ./tools/ --allowed-tools "file_reader,calculator"
```

#### Using Tools in Conversation
```
You: Can you analyze the performance metrics in this log file?
//tools performance_analyzer
//include /var/log/app.log

AI: I'll analyze the performance data using the performance analyzer tool...
```

#### Tool Discovery
```
You: /tools
Available Tools:
- file_analyzer: Analyze file contents and structure
- web_scraper: Extract data from web pages
- calculator: Perform complex mathematical calculations
```

## Chat Session Types

### Code Review Session
```bash
# Start specialized code review chat
aia --chat --role code_expert --system-prompt code_reviewer

You: I need help reviewing this Python function:
//include my_function.py

AI: I'll review this code for bugs, performance issues, and best practices...

You: What about security concerns?
AI: Looking at the security aspects of your function...

You: Can you suggest unit tests for this?
AI: Here are comprehensive unit tests for your function...
```

### Data Analysis Session
```bash
# Start data analysis chat with tools
aia --chat --tools ./analysis_tools/ --model claude-3-sonnet

You: I have a dataset I need to analyze:
//include data.csv

AI: I can help you analyze this dataset. Let me start by examining its structure...

You: Focus on the correlation between sales and marketing spend
AI: I'll analyze the correlation using statistical tools...
```

### Writing Session
```bash
# Start creative writing session
aia --chat --model gpt-4 --temperature 1.2 --role creative_writer

You: Help me write a technical blog post about microservices
AI: I'd be happy to help! Let's start by outlining the key points...

You: Make it more engaging for developers
AI: Here's how we can make it more engaging...
```

### Learning Session
```bash
# Start educational chat
aia --chat --role teacher --system-prompt patient_explainer

You: Explain how blockchain works, but I'm completely new to this
AI: Let me explain blockchain in simple terms, starting from the basics...

You: Can you give me a practical example?
AI: Absolutely! Let's use a simple example everyone can relate to...
```

## Voice and Audio Features

### Text-to-Speech
```bash
# Enable speech output
aia --chat --speak

# Choose specific voice
aia --chat --speak --voice nova

# Use high-quality speech model
aia --chat --speak --speech-model tts-1-hd
```

### Audio Input
```bash
# Use speech-to-text for input
aia --chat --transcription-model whisper-1 audio_input.wav
```

### Interactive Voice Chat
```bash
# Full voice interaction
aia --chat --speak --voice echo --transcription-model whisper-1

# Great for hands-free operation or accessibility
```

## Session Management

### Saving Conversations
```
# Within chat
You: /save project_discussion.md
Conversation saved to project_discussion.md

# Or with full path
You: /save /path/to/conversations/analysis_session.md
```

### Loading Previous Context
```bash
# Start chat with previous conversation
aia --chat --include previous_session.md

# This loads the conversation as context
```

### Session Configuration
```
# Change model mid-conversation
You: /model gpt-4
Switched to gpt-4

# Adjust creativity
You: /temperature 0.3
Temperature set to 0.3 (more focused)

# Enable verbose mode
You: /verbose on
Verbose mode enabled
```

## Chat Workflows

### Research and Analysis Workflow
1. **Information Gathering**: Load documents and data
2. **Initial Analysis**: Ask broad questions
3. **Deep Dive**: Focus on specific areas
4. **Synthesis**: Combine insights
5. **Documentation**: Save findings

```
You: I'm researching market trends in AI development
//include market_report.pdf
//include competitor_analysis.csv

AI: I'll help you analyze these market trends...

You: What are the key growth drivers?
AI: Based on the data, here are the main growth drivers...

You: How do our competitors compare?
AI: Looking at the competitive landscape...

You: /save ai_market_research.md
```

### Development Workflow
1. **Code Review**: Analyze existing code
2. **Problem Solving**: Debug issues
3. **Implementation**: Write new features
4. **Testing**: Create test cases
5. **Documentation**: Generate docs

```
You: Let's review and improve this API endpoint:
//include api_endpoint.py

AI: I'll review this endpoint for potential improvements...

You: It's running slowly, can you identify bottlenecks?
AI: I see several performance issues...

You: Help me optimize the database queries
AI: Here are optimized versions of your queries...

You: Generate unit tests for the optimized version
AI: Here are comprehensive unit tests...
```

## Customization and Configuration

### Chat-Specific Configuration
```yaml
# ~/.aia/chat_config.yml
chat:
  default_model: gpt-4
  save_conversations: true
  conversation_dir: ~/aia_conversations
  auto_save_interval: 300  # seconds
  max_context_length: 16000
  show_token_count: true

speech:
  enabled: false
  voice: alloy
  auto_play: true

tools:
  auto_discover: true
  default_paths: [~/.aia/tools, ./tools]
  security_mode: safe
```

### Custom Chat Commands
You can define custom chat commands by creating tool functions:

```ruby
# ~/.aia/tools/chat_commands.rb
class ChatCommands < RubyLLM::Tool
  def summarize_conversation
    # Custom command to summarize the current conversation
    "<%= AIA.chat.context.summarize %>"
  end

  def export_code_snippets
    # Extract and export all code snippets from conversation
    "<%= AIA.chat.extract_code_blocks %>"
  end
end
```

## Token Usage and Cost Tracking

### Displaying Token Usage
Use the `--tokens` flag to see token usage after each response:

```bash
# Enable token usage display
aia --chat --tokens

# Example output after a response:
# AI: Here's my response to your question...
#
# Tokens: input=125, output=89, model=gpt-4o-mini
```

### Cost Estimation
Use the `--cost` flag to include cost calculations with token usage:

```bash
# Enable cost estimation (automatically enables --tokens)
aia --chat --cost

# Example output after a response:
# AI: Here's my response to your question...
#
# Tokens: input=125, output=89, model=gpt-4o-mini
# Cost: $0.0003 (input: $0.0002, output: $0.0001)
```

### Multi-Model Token Tracking
When using multiple models, token usage is displayed for each model:

```bash
aia --chat --tokens --model gpt-4,claude-3-sonnet

# Example output:
# from: gpt-4
# Here's my response...
#
# from: claude-3-sonnet
# Here's my alternative response...
#
# Model: gpt-4 - Tokens: input=125, output=89
# Model: claude-3-sonnet - Tokens: input=125, output=112
```

## Troubleshooting Chat Mode

### Common Issues

#### Context Too Long
```
Error: Context exceeds maximum length
```
**Solution**: Use `/clear` to clear history or `/context trim` to keep recent messages only.

#### Model Not Responding
```
Error: Model timeout or connection error
```
**Solution**: Check your internet connection and API keys, try switching models.

#### Tool Not Found
```
Error: Tool 'my_tool' not found
```
**Solution**: Verify tool paths with `/tools` and check tool file syntax.

### Performance Optimization

#### Reduce Token Usage
- Clear context regularly with `/clear`
- Use shorter, more focused messages
- Summarize long conversations periodically

#### Improve Response Speed
- Use faster models for simple queries
- Cache frequently used context
- Optimize tool implementations

#### Memory Management
```bash
# Monitor memory usage
aia --chat --debug --verbose

# Use memory-efficient models
aia --chat --model gpt-3.5-turbo
```

## Best Practices

### Effective Chat Techniques
1. **Be Specific**: Clear, detailed questions get better responses
2. **Provide Context**: Include relevant information upfront
3. **Iterate**: Build on previous responses for deeper insights
4. **Use Tools**: Leverage tools for data processing and analysis
5. **Save Progress**: Regular saves prevent loss of valuable insights

### Security Considerations
1. **Sensitive Data**: Avoid sharing confidential information
2. **Tool Access**: Restrict tool permissions appropriately
3. **Session Management**: Clear sensitive conversations
4. **API Keys**: Keep credentials secure

### Productivity Tips
1. **Keyboard Shortcuts**: Learn and use available shortcuts
2. **Template Messages**: Create reusable message templates
3. **Model Selection**: Choose appropriate models for different tasks
4. **Batch Operations**: Process multiple items in single conversations

## Integration with Other AIA Features

### Pipeline Integration
```bash
# Start chat after pipeline completion
aia --pipeline "data_prep,analysis" --chat dataset.csv

# Process results in chat mode
```

### Configuration Integration
```bash
# Use predefined configurations in chat
aia --config-file chat_setup.yml --chat

# Override specific settings
aia --chat --temperature 0.9 --max-tokens 3000
```

### Output Integration
```bash
# Save chat output to file
aia --chat --output discussion.md --markdown

# Append to existing files
aia --chat --output project_log.md --append
```

## Related Documentation

- [Getting Started](getting-started.md) - Basic AIA usage
- [Working with Models](models.md) - Model selection and configuration
- [Tools Integration](tools.md) - Using and creating tools
- [CLI Reference](../cli-reference.md) - Command-line options
- [Configuration](../configuration.md) - Setup and customization

---

Chat mode is one of AIA's most powerful features. Experiment with different models, tools, and workflows to find what works best for your use cases!
