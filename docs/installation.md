# Installation

This guide will help you install AIA and get it running on your system.

## Prerequisites

### Required
- **Ruby**: Version 3.0 or higher
- **RubyGems**: Usually comes with Ruby

### Recommended
- **fzf**: For fuzzy prompt searching
- **git**: For prompt management with version control

## Installation Methods

### Method 1: Install from RubyGems (Recommended)

The easiest way to install AIA is through RubyGems:

```bash
gem install aia
```

### Method 2: Install from Source

If you want the latest development version:

```bash
git clone https://github.com/MadBomber/aia.git
cd aia
bundle install
rake install
```

### Method 3: Using Bundler

Add to your Gemfile:

```ruby
gem 'aia'
```

Then run:

```bash
bundle install
```

## Verify Installation

After installation, verify that AIA is working:

```bash
aia --version
```

You should see the version number printed.

## Initial Setup

### 1. Create Prompts Directory

AIA stores prompts in a directory (default: `~/.prompts`). Create it:

```bash
mkdir -p ~/.prompts
```

### 2. Create Configuration Directory

Create the configuration directory (following XDG Base Directory Specification):

```bash
mkdir -p ~/.config/aia
```

### 3. Basic Configuration File (Optional)

Create a basic configuration file at `~/.config/aia/aia.yml`:

```yaml
# Basic AIA configuration
# Uses nested structure - see docs/configuration.md for full reference

llm:
  adapter: ruby_llm
  temperature: 0.7

models:
  - name: gpt-4o-mini

prompts:
  dir: ~/.prompts

flags:
  verbose: false
```

### 4. Set Up API Keys

AIA uses the RubyLLM gem, which supports multiple AI providers. Set up your API keys as environment variables:

#### OpenAI
```bash
export OPENAI_API_KEY="your_openai_api_key_here"
```

#### Anthropic Claude
```bash
export ANTHROPIC_API_KEY="your_anthropic_api_key_here"
```

#### Google Gemini
```bash
export GOOGLE_API_KEY="your_google_api_key_here"
```

#### Ollama (Local models)
```bash
export OLLAMA_URL="http://localhost:11434"
```

Add these to your shell profile (`.bashrc`, `.zshrc`, etc.) to make them permanent.

## Optional Dependencies

### Install fzf for Fuzzy Search

AIA supports fuzzy searching for prompts using `fzf`. Install it:

#### macOS (using Homebrew)
```bash
brew install fzf
```

#### Ubuntu/Debian
```bash
apt-get install fzf
```

#### Other systems
See the [fzf installation guide](https://github.com/junegunn/fzf#installation).

### Install Additional Ruby Gems

Some features may require additional gems:

```bash
# For advanced audio processing
gem install ruby-audio

# For advanced image processing  
gem install mini_magick

# For enhanced terminal features
gem install tty-prompt
```

## Testing Your Installation

### 1. Check Available Models

```bash
aia --available-models
```

This will show all available AI models.

### 2. Test Basic Functionality

Create a simple prompt file:

```bash
echo "Hello, what can you help me with today?" > ~/.prompts/hello.txt
```

Run it:

```bash
aia hello
```

### 3. Test Chat Mode

```bash
aia --chat
```

This should start an interactive chat session.

## Troubleshooting

### Common Issues

#### "Command not found: aia"
- Make sure Ruby's bin directory is in your PATH
- Try reinstalling: `gem uninstall aia && gem install aia`

#### "No models available"
- Check that your API keys are set correctly
- Verify your internet connection
- Try: `aia --available-models` to diagnose

#### "fzf not found" warning
- Install fzf as described above
- Or disable fuzzy search: `aia --no-fuzzy`

#### Permission errors
- Try installing with: `gem install aia --user-install`
- Or use `sudo` (not recommended): `sudo gem install aia`

### Getting Help

If you encounter issues:

1. Check the [FAQ](faq.md)
2. Search existing [GitHub issues](https://github.com/MadBomber/aia/issues)
3. Create a new issue with:
   - Your OS and Ruby version
   - The exact error message
   - Steps to reproduce

## Next Steps

Once AIA is installed:

1. Read the [Configuration Guide](configuration.md)
2. Follow the [Getting Started Guide](guides/getting-started.md)
3. Explore [Examples](examples/index.md)

## Updating AIA

To update to the latest version:

```bash
gem update aia
```

Or if installed from source:

```bash
cd path/to/aia
git pull
bundle install
rake install
```