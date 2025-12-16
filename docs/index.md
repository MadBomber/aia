# AIA - AI Assistant

<table border="0">
<tr>
<td width="30%" valign="top">
  <img src="assets/images/aia.png" alt="AIA - May I take your prompt?" width="200" />
  <div align="center">
      <strong>The Prompt is the Code</strong>
  </div>
</td>
<td width="70%" valign="top">

Welcome to AIA, your powerful CLI tool for dynamic prompt management and AI interaction.
<br/><br/>
<strong>AIA (AI Assistant)</strong> is a Ruby-based command-line tool that revolutionizes how you interact with AI models. It's designed for generative AI workflows, enabling you to effortlessly manage AI prompts, integrate seamlessly with shell and embedded Ruby (ERB), run batch processes, and engage in interactive chats with user-defined directives, tools, and MCP clients.
</td>
</tr>
</table>

  <div align="center">
      AIA treats prompts as executable programs, complete with configuration, logic, and workflows.
  </div>

## Key Features

### 🚀 Dynamic Prompt Management
- **Hierarchical Configuration**: Embedded directives > CLI args > environment variables > config files > defaults
- **Prompt Sequences and Workflows**: Chain prompts together for complex AI workflows
- **Role-based Prompts**: Use predefined roles to context your AI interactions
- **Fuzzy Search**: Find prompts quickly with fuzzy matching (requires `fzf`)

### 🔧 Powerful Integration
- **Shell Integration**: Execute shell commands directly within prompts
- **Ruby (ERB) Processing**: Use Ruby code in your prompts for dynamic content
- **RubyLLM::Tool Support**: Function callbacks for enhanced AI capabilities
- **MCP Client Support**: Integrate with Model Context Protocol clients

### 💬 Interactive Chat Sessions
- **Context Management**: Maintain conversation history and context
- **Multi-model Support**: Use multiple AI models simultaneously
- **Consensus Mode**: Get consensus responses from multiple models
- **Voice Support**: Convert text to speech and back

### 🎯 Advanced Features
- **Executable Prompts**: Run prompts as executable scripts
- **Parameter Extraction**: Use regex to extract parameters from prompts
- **Image Generation**: Generate images with customizable parameters
- **Tool Integration**: Use custom Ruby tools for enhanced functionality

## Quick Start

1. **Install AIA:**
   ```bash
   gem install aia
   ```

2. **Install dependencies:**
   ```bash
   brew install fzf
   ```

3. **Create your first prompt:**
   ```bash
   mkdir -p ~/.prompts
   echo "What is [TOPIC]?" > ~/.prompts/what_is.txt
   ```

4. **Run your prompt:**
   ```bash
   aia what_is
   ```
   You'll be prompted to enter a value for `[TOPIC]`, then AIA will send your question to the AI model.

5. **Start an interactive chat:**
   ```bash
   aia --chat

   # Or use multiple models for comparison
   aia --chat --model "gpt-4o-mini,gpt-3.5-turbo"
   ```

When AIA starts, you'll see the friendly robot mascot:

```plain

       ,      ,
       (\____/) AI Assistant (v0.9.7) is Online
        (_oo_)   ["gpt-4o-mini", "gpt-5-mini"]
         (O)       using ruby_llm (v1.6.4 MCP v0.6.1)
       __||__    \) model db was last refreshed on
     [/______\]  /    2025-08-27
    / \__AI__/ \/      You can share my tools
   /    /__\
  (\   /____\

```

## Core Architecture

AIA follows a modular Ruby gem structure with clear separation of concerns:

### Component Overview

```mermaid
graph TD
    A[CLI Input] --> B[Config System]
    B --> C[Prompt Handler]
    C --> D[Directive Processor]
    D --> E[Context Manager]
    E --> F[RubyLLM Adapter]
    F --> G[AI Models]

    H[Prompt Files] --> C
    I[Role Files] --> C
    J[Tools] --> F
    K[MCP Clients] --> F

    C --> L[Chat Processor Service]
    L --> M[UI Presenter]
    M --> N[Terminal Output]
```

### Core Components

- **AIA::Config** - Configuration management with hierarchical precedence
- **AIA::PromptHandler** - Main prompt processing orchestrator
- **AIA::ChatProcessorService** - Interactive chat session management
- **AIA::DirectiveProcessor** - Processes embedded directives (`//command params`)
- **AIA::RubyLLMAdapter** - Interfaces with the ruby_llm gem for AI model communication (manages conversation history via RubyLLM's Chat.@messages)
- **AIA::ShellCommandExecutor** - Executes shell commands safely within prompts
- **AIA::HistoryManager** - Manages prompt parameter history and user input
- **AIA::UIPresenter** - Terminal output formatting and presentation
- **AIA::Session** - Manages chat sessions and state
- **AIA::Fzf** - Fuzzy finder integration for prompt selection
- **AIA::Directives::Checkpoint** - Manages conversation checkpoints, restore, clear, and review operations

### External Dependencies

- **prompt_manager gem** - Core prompt management functionality
- **ruby_llm gem** - AI model interface layer
- **fzf** - Command-line fuzzy finder (external CLI tool)

## Documentation Structure

### Getting Started
- [Installation](installation.md) - Get AIA up and running
- [Configuration](configuration.md) - Configure AIA for your needs
- [Getting Started Guide](guides/getting-started.md) - Your first steps with AIA

### Guides
- [Chat Mode](guides/chat.md) - Interactive conversations with AI
- [Working with Models](guides/models.md) - Multi-model support and configuration
- [Tools Integration](guides/tools.md) - Extend AIA with custom tools
- [Advanced Prompting](advanced-prompting.md) - Master complex prompt techniques

### Reference
- [CLI Parameters](cli-reference.md) - Complete command-line reference
- [Directives Reference](directives-reference.md) - All available directives
- [Examples](examples/index.md) - Practical examples and use cases

## Community & Support

- **GitHub**: [madbomber/aia](https://github.com/MadBomber/aia)
- **Issues**: [Report bugs and request features](https://github.com/MadBomber/aia/issues)
- **RubyGems**: [aia gem](https://rubygems.org/gems/aia)

## License

AIA is open source software. See the [LICENSE](https://github.com/MadBomber/aia/blob/main/LICENSE) file for details.

---

Ready to get started? Head to the [Installation](installation.md) guide to begin your AIA journey!
