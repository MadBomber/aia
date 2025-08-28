# Contributing to AIA

We welcome contributions to AIA! This guide will help you get started with contributing to the project.

## Ways to Contribute

### 1. Report Issues
- **Bug Reports**: Found a bug? Please report it with detailed steps to reproduce
- **Feature Requests**: Have an idea for a new feature? We'd love to hear about it
- **Documentation Issues**: Spot errors or areas for improvement in documentation

### 2. Submit Code Changes
- **Bug Fixes**: Help fix reported issues
- **New Features**: Implement requested features or propose new ones
- **Performance Improvements**: Optimize existing code
- **Tests**: Improve test coverage and quality

### 3. Improve Documentation
- **User Guides**: Help improve user-facing documentation
- **Code Comments**: Add or improve inline documentation
- **Examples**: Contribute new examples or improve existing ones
- **Tutorials**: Create learning materials for new users

### 4. Contribute Examples
- **Prompts**: Share useful prompt templates
- **Tools**: Create Ruby tools that extend AIA's capabilities
- **MCP Clients**: Develop Model Context Protocol integrations

## Getting Started

### Prerequisites
- Ruby 3.0+ installed
- Git for version control
- Familiarity with AI/LLM concepts
- Understanding of command-line tools

### Setting Up Development Environment

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/aia.git
   cd aia
   ```

2. **Install Dependencies**
   ```bash
   bundle install
   ```

3. **Run Tests**
   ```bash
   rake test
   ```

4. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Guidelines

### Code Standards

#### Ruby Style Guide
- Follow Ruby community conventions
- Use descriptive variable and method names
- Write clear, concise comments
- Maintain consistent indentation (2 spaces)
- Keep line length under 120 characters

#### Testing Requirements
- Write tests for all new functionality
- Maintain or improve test coverage
- Use descriptive test names
- Include both unit and integration tests

#### Documentation Standards
- Update README if needed
- Add inline documentation for public methods
- Include usage examples
- Update CHANGELOG.md for user-facing changes

### Commit Message Format

Use clear, descriptive commit messages following this format:

```
type(scope): brief description

Longer description if needed

- List key changes
- Include breaking changes
- Reference issues: Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test-related changes
- `refactor`: Code refactoring
- `perf`: Performance improvements

**Examples:**
```
feat(cli): add --fuzzy flag for prompt selection

fix(config): resolve issue with nested YAML parsing

docs(examples): add MCP client integration examples
```

## Contributing Examples

### Prompt Examples

#### File Structure
```
docs/examples/prompts/category/
├── index.md                    # Category overview
├── example_name.txt           # Prompt file
└── example_name_usage.md      # Usage documentation
```

#### Prompt Template Format
```markdown
# Prompt Title

Brief description of what this prompt does.

## Prerequisites
- List any required setup
- Dependencies or tools needed
- API keys or configurations

## Usage
```bash
aia prompt_name input_file.txt
```

## Customization
Explain how users can modify the prompt for their needs.

## Related Examples
- Link to similar or complementary examples
```

### Tool Examples

#### File Structure
```
docs/examples/tools/
├── index.md                    # Tools overview
├── tool_name.rb               # Ruby tool implementation
└── tool_name_usage.md         # Documentation
```

#### Tool Template
```ruby
# Tool implementation following RubyLLM::Tool pattern
class ToolName < RubyLLM::Tool
  description "Brief description of tool functionality"
  
  def method_name(parameter1, parameter2 = nil)
    # Implementation with error handling
    # Return structured results
  end
  
  private
  
  def helper_method
    # Internal helper methods
  end
end
```

### MCP Client Examples

#### File Structure
```
docs/examples/mcp/
├── index.md                    # MCP overview
├── client_name.py             # Python MCP client
├── client_name.js             # Node.js MCP client
└── client_name_usage.md       # Documentation
```

## Pull Request Process

### Before Submitting
1. **Test Your Changes**
   ```bash
   rake test
   rake integration_test
   ```

2. **Check Code Quality**
   ```bash
   rubocop
   reek
   ```

3. **Update Documentation**
   - Add/update relevant documentation
   - Include examples if applicable
   - Update CHANGELOG.md

### Submitting the Pull Request

1. **Create Descriptive Title**
   - Use the same format as commit messages
   - Be specific about what changed

2. **Write Comprehensive Description**
   ```markdown
   ## Summary
   Brief description of changes

   ## Changes Made
   - List key changes
   - Explain design decisions
   - Note any breaking changes

   ## Testing
   - Describe testing performed
   - Include test results if relevant

   ## Documentation
   - List documentation updates
   - Include screenshots if applicable
   ```

3. **Checklist**
   - [ ] Tests pass locally
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] CHANGELOG.md updated (if user-facing)
   - [ ] No breaking changes (or documented)

### Review Process
- Maintainers will review your pull request
- Address feedback promptly and professionally
- Be open to suggestions and improvements
- Update your PR based on review comments

## Community Guidelines

### Communication
- **Be Respectful**: Treat all community members with respect
- **Be Constructive**: Provide helpful, actionable feedback
- **Be Patient**: Maintainers and contributors are volunteers
- **Be Collaborative**: Work together to improve the project

### Issue Reporting
- **Search First**: Check if the issue already exists
- **Be Specific**: Provide detailed reproduction steps
- **Include Context**: OS, Ruby version, AIA version
- **Provide Examples**: Include relevant code or configuration

### Feature Requests
- **Describe Use Case**: Explain why the feature is needed
- **Consider Alternatives**: Discuss other approaches
- **Be Open to Discussion**: Feature scope may evolve

## Security

### Reporting Security Issues
- **Do NOT** create public GitHub issues for security vulnerabilities
- Email security issues to: [maintainer-email]
- Include detailed description and reproduction steps
- Allow reasonable time for response before public disclosure

### Security Best Practices
- Never commit API keys or secrets
- Validate all user inputs
- Use secure defaults in configurations
- Follow principle of least privilege

## Recognition

### Contributors
All contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes for significant contributions
- GitHub contributor statistics

### Types of Recognition
- **Code Contributors**: Code, tests, bug fixes
- **Documentation Contributors**: Guides, examples, documentation
- **Community Contributors**: Issue triage, user support
- **Maintainers**: Ongoing project stewardship

## Getting Help

### Development Questions
- **GitHub Discussions**: For general questions and ideas
- **Issues**: For specific bugs or feature requests
- **Documentation**: Check existing guides and examples

### Code Review
- Ask for reviews in PR comments
- Mention specific maintainers if needed
- Be patient - reviews take time

### Community Support
- Help other contributors
- Share knowledge and experience
- Mentor new contributors

## Release Process

### Version Management
AIA follows semantic versioning (SemVer):
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Schedule
- No fixed schedule - releases when ready
- Security fixes released promptly
- Feature releases coordinated with maintainers

## Thank You!

Thank you for considering contributing to AIA! Your contributions help make this tool better for everyone in the AI community.

Questions? Feel free to open an issue or start a discussion on GitHub.

---

*Last updated: December 2024*