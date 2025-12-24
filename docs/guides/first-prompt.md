# Your First Prompt

A step-by-step guide to creating and running your very first AIA prompt, from the simplest examples to more sophisticated patterns.

## Before You Start

Make sure you have:
- [Installed AIA](../installation.md)
- Set up your API keys
- Created your prompts directory (`mkdir -p ~/.prompts`)

## The Simplest Prompt

Let's start with the most basic prompt possible:

### Step 1: Create Your First Prompt File
```bash
echo "What is Ruby programming language?" > ~/.prompts/what_is_ruby.txt
```

### Step 2: Run Your Prompt
```bash
aia what_is_ruby
```

That's it! AIA will:
1. Find your prompt file in `~/.prompts/`
2. Send it to the default AI model
3. Display the response in your terminal

## Adding Context to Prompts

Now let's create a prompt that works with files:

### Step 1: Create a Context-Aware Prompt
```bash
cat > ~/.prompts/explain_code.txt << 'EOF'
Please explain what this code does:

<%= context_file %>

Provide a clear explanation that covers:
- What the code accomplishes
- How it works
- Any potential improvements
EOF
```

### Step 2: Use It with a File
```bash
# Create a sample code file
echo 'puts "Hello, World!"' > hello.rb

# Run the prompt with context
aia explain_code hello.rb
```

AIA automatically includes the file content where you specified `<%= context_file %>`.

## Using Directives

Directives are special commands in prompts that start with `//`. Let's try some:

### Configuration Directives
```bash
cat > ~/.prompts/detailed_analysis.txt << 'EOF'
//config model gpt-4
//config temperature 0.3

Provide a detailed technical analysis of this code:

<%= context_file %>

Focus on:
- Architecture and design patterns
- Performance considerations
- Security implications
- Best practices compliance
EOF
```

### File Inclusion Directives
```bash
cat > ~/.prompts/project_overview.txt << 'EOF'
//include README.md
//include package.json

Based on the project files above, provide an overview of:
- Project purpose and goals
- Technology stack
- Getting started instructions
- Key dependencies
EOF
```

### Shell Command Directives
```bash
cat > ~/.prompts/system_status.txt << 'EOF'
Current system status:

//shell date
//shell whoami
//shell uptime
//shell df -h

Please analyze the system status and provide recommendations.
EOF
```

## Interactive Prompts with Parameters

Create prompts that accept parameters:

### Step 1: Create a Parameterized Prompt
```bash
cat > ~/.prompts/code_review.txt << 'EOF'
//config model gpt-4
//config temperature 0.2

# Code Review: <%= file_name %>

Review this <%= language %> code for:
- Bugs and potential issues
- Code quality and style
- Performance optimizations
- Security considerations

Focus level: <%= focus_level || "standard" %>

Code to review:
//include <%= file_name %>

Please provide specific, actionable feedback.
EOF
```

### Step 2: Use with Parameters
```bash
# ERB-style parameters (in prompt content)
aia code_review --file_name "app.py" --language "Python" --focus_level "security"
```

## Your First Chat Session

Try AIA's interactive chat mode:

### Step 1: Start a Chat
```bash
aia --chat
```

### Step 2: Have a Conversation
```
You: Help me understand how to use AIA effectively
AI: I'd be happy to help! AIA is a powerful CLI tool for AI interactions...

You: Can you help me write a Python function?
AI: Of course! What kind of function would you like to create?

You: A function that calculates factorial
AI: Here's a Python factorial function...
```

### Step 3: Save Your Conversation
```
You: /save factorial_help.md
```

## Working with Different Models

Try different AI models for different tasks:

### Quick Tasks
```bash
aia --model gpt-3.5-turbo what_is_ruby
```

### Complex Analysis
```bash
aia --model gpt-4 detailed_analysis complex_code.py
```

### Long Documents
```bash
aia --model claude-3-sonnet project_overview
```

## Creating Your First Workflow

Chain prompts together for multi-step processes:

### Step 1: Create Individual Steps
```bash
# Step 1: Extract requirements
cat > ~/.prompts/extract_requirements.txt << 'EOF'
//next analyze_requirements

Extract and list all requirements from this project:

//include README.md
//include requirements.txt

Provide a structured list of:
- Functional requirements
- Non-functional requirements
- Dependencies
- Constraints
EOF

# Step 2: Analyze requirements
cat > ~/.prompts/analyze_requirements.txt << 'EOF'
//next generate_recommendations

Based on the requirements extraction, analyze:
- Completeness of requirements
- Potential conflicts or gaps
- Implementation complexity
- Risk factors
EOF

# Step 3: Generate recommendations
cat > ~/.prompts/generate_recommendations.txt << 'EOF'
Based on the requirements and analysis, provide:
- Implementation recommendations
- Architecture suggestions
- Risk mitigation strategies
- Next steps
EOF
```

### Step 2: Run the Workflow
```bash
aia extract_requirements
```

AIA will automatically run all three prompts in sequence!

## Common Beginner Mistakes to Avoid

### ❌ Don't: Create overly complex first prompts
```bash
# Too complex for beginners
cat > ~/.prompts/bad_first_prompt.txt << 'EOF'
//config model gpt-4
//config temperature 0.7
//ruby complex_calculations
//shell complex_command | grep something
//include multiple_files.txt

Perform complex multi-step analysis with advanced features...
EOF
```

### ✅ Do: Start simple and build up
```bash
# Good first prompt
cat > ~/.prompts/good_first_prompt.txt << 'EOF'
Summarize this file in simple terms:

<%= context_file %>
EOF
```

### ❌ Don't: Ignore error messages
```bash
# If this fails, read the error message!
aia nonexistent_prompt
```

### ✅ Do: Use debug mode when learning
```bash
# See what AIA is doing
aia --debug --verbose your_prompt
```

## Practice Exercises

Try these exercises to reinforce what you've learned:

### Exercise 1: File Analyzer
Create a prompt that analyzes any file type and provides insights.

```bash
cat > ~/.prompts/analyze_file.txt << 'EOF'
Analyze this file:

//include <%= file %>

Provide:
- File type and format
- Key content summary
- Purpose and use case
- Any notable features
EOF
```

### Exercise 2: Code Formatter
Create a prompt that suggests code improvements.

```bash
cat > ~/.prompts/improve_code.txt << 'EOF'
//config temperature 0.3

Suggest improvements for this code:

//include <%= code_file %>

Focus on:
- Readability
- Performance
- Best practices
- Error handling
EOF
```

### Exercise 3: Project Documentation
Create a prompt that generates README content.

```bash
cat > ~/.prompts/generate_readme.txt << 'EOF'
Generate README.md content for this project:

Project structure:
//shell find . -type f -name "*.py" -o -name "*.rb" -o -name "*.js" | head -10

Configuration files:
//shell ls *.json *.yml *.yaml 2>/dev/null || echo "No config files found"

Create a comprehensive README with:
- Project description
- Installation instructions
- Usage examples
- Contributing guidelines
EOF
```

## Tips for Success

### Start Small
- Begin with simple, single-purpose prompts
- Test each prompt thoroughly before making it complex
- Add one new feature at a time

### Use Descriptive Names
```bash
# Good prompt names
~/.prompts/analyze_python_code.txt
~/.prompts/summarize_research_paper.txt
~/.prompts/generate_api_docs.txt

# Poor prompt names
~/.prompts/prompt1.txt
~/.prompts/test.txt
~/.prompts/stuff.txt
```

### Organize Your Prompts
```bash
# Create categories
mkdir -p ~/.prompts/{development,analysis,writing,learning}

# Move prompts to appropriate directories
mv ~/.prompts/code_review.txt ~/.prompts/development/
mv ~/.prompts/analyze_file.txt ~/.prompts/analysis/
```

### Version Control Your Prompts
```bash
cd ~/.prompts
git init
git add .
git commit -m "My first AIA prompts"
```

### Experiment and Iterate
- Try different models for the same prompt
- Adjust temperature settings to see the difference
- Refine prompts based on the results you get

## Getting Help

### Built-in Help
```bash
# General help
aia --help

# Model information
aia --available-models

# Debug information
aia --debug my_prompt
```

### Community Resources
- Check the [FAQ](../faq.md) for common questions
- Browse [Examples](../examples/index.md) for inspiration
- Read the [Advanced Prompting](../advanced-prompting.md) guide when ready

## Next Steps

After mastering your first prompt, explore:

1. **[Basic Usage](basic-usage.md)** - Common usage patterns
2. **[Chat Mode](chat.md)** - Interactive conversations
3. **[Working with Models](models.md)** - Model selection strategies
4. **[Tools Integration](tools.md)** - Extending capabilities
5. **[Advanced Prompting](../advanced-prompting.md)** - Expert techniques

## Troubleshooting Your First Prompt

### Prompt Not Found
```bash
# Check if file exists
ls ~/.prompts/your_prompt.txt

# Check file permissions
chmod 644 ~/.prompts/your_prompt.txt

# Use full path if needed
aia --prompts-dir ~/.prompts your_prompt
```

### API Errors
```bash
# Check API key
echo $OPENAI_API_KEY | cut -c1-10

# Test with simple prompt
aia --model gpt-3.5-turbo --debug simple_test
```

### Unexpected Results
```bash
# Use debug mode
aia --debug --verbose your_prompt

# Try different model
aia --model claude-3-sonnet your_prompt

# Simplify the prompt
echo "Simple test question" | aia --chat
```

## Congratulations!

You've created and run your first AIA prompt! You now understand:
- ✅ How to create basic prompt files
- ✅ How to run prompts with context
- ✅ How to use simple directives
- ✅ How to work with different models
- ✅ How to start chat sessions
- ✅ How to create basic workflows

Keep experimenting and building more sophisticated prompts as you become comfortable with these fundamentals!
