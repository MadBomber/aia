# AI Assistant (AIA)

A Ruby command-line interface for interacting with various AI services using the `ai_client` and `prompt_manager` gems.

## Overview

The AIA project provides a flexible interface for working with AI models through standardized prompt management.

### Key Features

- Proper variable substitution using `prompt_manager` gem
- Directive handling for extended functionality
- Support for multiple AI providers through `ai_client`
- Conversation mode with history and context management
- Pipeline processing for sequential AI operations

## Architecture

The architecture has been updated to better leverage the `prompt_manager` gem's built-in functionality:

- `Session`: Manages the interaction flow, utilizing `prompt_manager` objects directly
- `PromptHandler`: Processes prompts with improved directive handling using the gem's capabilities
- `AIClientAdapter`: Provides a unified interface to different AI operations

## Usage

See documentation for examples of how to use this tool effectively.
