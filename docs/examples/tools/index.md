# Tools Examples

Collection of RubyLLM tools that extend AIA's capabilities with custom Ruby functions.

## Available Tools

### File Processing Tools
- **file_analyzer.rb** - Advanced file analysis and metadata extraction
- **log_analyzer.rb** - Log file parsing and pattern analysis
- **config_manager.rb** - Configuration file management and validation
- **document_processor.rb** - Document format conversion and processing

### Web Integration Tools
- **web_client.rb** - HTTP client for API interactions
- **web_scraper.rb** - Web scraping and content extraction
- **api_tester.rb** - API endpoint testing and validation
- **webhook_handler.rb** - Webhook processing and management

### Data Analysis Tools
- **data_analyzer.rb** - CSV and JSON data analysis
- **statistics_calculator.rb** - Statistical calculations and metrics
- **chart_generator.rb** - Data visualization and chart generation
- **database_connector.rb** - Database query and analysis tools

### Development Tools
- **code_quality.rb** - Code quality analysis and metrics
- **test_runner.rb** - Test execution and reporting
- **dependency_checker.rb** - Dependency analysis and management
- **deploy_helper.rb** - Deployment assistance and validation

### System Integration Tools
- **system_monitor.rb** - System monitoring and health checks
- **process_manager.rb** - Process management and control
- **backup_manager.rb** - Backup operations and scheduling
- **security_scanner.rb** - Security scanning and assessment

## Tool Structure

All tools follow the standard RubyLLM::Tool pattern:

```ruby
class ToolName < RubyLLM::Tool
  description "Brief description of tool functionality"
  
  def method_name(parameter1, parameter2 = nil)
    # Tool implementation
    return "Result string or JSON"
  end
  
  private
  
  def helper_method
    # Internal helper methods
  end
end
```

## Usage Examples

### Basic Tool Usage
```bash
# Use a single tool
aia --tools file_analyzer.rb analyze_project project/

# Use multiple tools
aia --tools "web_client.rb,data_analyzer.rb" api_data_analysis

# Use tool directory
aia --tools ./tools/ comprehensive_analysis
```

### Tool Security
```bash
# Restrict to specific tools
aia --tools ./tools/ --allowed_tools "file_analyzer,data_analyzer" safe_analysis

# Block potentially dangerous tools
aia --tools ./tools/ --rejected_tools "system_monitor,process_manager" user_analysis
```

### Tool Integration in Prompts
```markdown
# Use tools within prompts
//tools file_analyzer.rb,web_client.rb

Analyze the project structure and check API endpoints:
1. Use file_analyzer to examine project files
2. Use web_client to test API endpoints
3. Provide comprehensive assessment
```

## Tool Categories

### Security Level: Safe
Tools that only read data and perform analysis:
- file_analyzer.rb
- data_analyzer.rb
- statistics_calculator.rb
- code_quality.rb

### Security Level: Network
Tools that make network requests:
- web_client.rb
- web_scraper.rb
- api_tester.rb
- webhook_handler.rb

### Security Level: System
Tools that interact with the system:
- system_monitor.rb
- process_manager.rb
- deploy_helper.rb
- security_scanner.rb

### Security Level: Write
Tools that can modify files or system state:
- config_manager.rb (when writing configs)
- backup_manager.rb
- document_processor.rb (when saving files)

## Tool Development Guidelines

### Best Practices
1. **Single Responsibility** - Each tool should do one thing well
2. **Error Handling** - Comprehensive error handling and user feedback
3. **Input Validation** - Validate all inputs and parameters
4. **Security** - Follow principle of least privilege
5. **Documentation** - Clear descriptions and usage examples

### Example Tool Template
```ruby
# ~/.aia/tools/example_tool.rb
require 'json'

class ExampleTool < RubyLLM::Tool
  description "Example tool demonstrating best practices"
  
  def process_data(input_data, options = {})
    # Validate inputs
    return "Error: No input data provided" if input_data.nil? || input_data.empty?
    
    begin
      # Process data
      result = perform_processing(input_data, options)
      
      # Return structured result
      {
        status: 'success',
        data: result,
        metadata: {
          processed_at: Time.now.iso8601,
          options_used: options
        }
      }.to_json
      
    rescue StandardError => e
      # Handle errors gracefully
      {
        status: 'error',
        message: e.message,
        type: e.class.name
      }.to_json
    end
  end
  
  private
  
  def perform_processing(data, options)
    # Actual processing logic
    data.upcase
  end
end
```

### Testing Tools
```ruby
# test_example_tool.rb
require 'minitest/autorun'
require_relative 'example_tool'

class TestExampleTool < Minitest::Test
  def setup
    @tool = ExampleTool.new
  end
  
  def test_basic_functionality
    result = @tool.process_data("test input")
    parsed = JSON.parse(result)
    
    assert_equal 'success', parsed['status']
    assert_equal 'TEST INPUT', parsed['data']
  end
  
  def test_error_handling
    result = @tool.process_data(nil)
    parsed = JSON.parse(result)
    
    assert_includes parsed['message'], 'No input data'
  end
end
```

## Tool Installation and Distribution

### Local Tool Directory
```bash
# Create tool directory structure
mkdir -p ~/.aia/tools/{core,development,analysis,web,system}

# Copy tools to appropriate directories
cp file_analyzer.rb ~/.aia/tools/core/
cp code_quality.rb ~/.aia/tools/development/
cp data_analyzer.rb ~/.aia/tools/analysis/
```

### Tool Libraries
```yaml
# ~/.aia/tool_config.yml
tool_libraries:
  core:
    path: ~/.aia/tools/core
    security_level: safe
    
  development:
    path: ~/.aia/tools/development
    security_level: safe
    
  web:
    path: ~/.aia/tools/web
    security_level: network
    
  system:
    path: ~/.aia/tools/system
    security_level: system
    restricted: true
```

### Shared Tool Repositories
```bash
# Clone shared tool repositories
git clone https://github.com/team/aia-tools.git ~/.aia/shared-tools

# Use shared tools
aia --tools ~/.aia/shared-tools/web/ api_analysis
```

## Performance Considerations

### Tool Optimization
- Cache expensive operations
- Use appropriate data structures
- Implement timeouts for network operations
- Handle large data sets efficiently
- Profile and optimize slow operations

### Memory Management
- Clean up temporary files
- Manage large object lifecycles
- Use streaming for large data processing
- Monitor memory usage in long-running operations

## Troubleshooting

### Common Issues
1. **Tool Not Found** - Check file paths and permissions
2. **Method Errors** - Verify method signatures and parameters
3. **Permission Denied** - Check file and directory permissions
4. **Network Timeouts** - Implement proper timeout handling
5. **Memory Issues** - Optimize for large data processing

### Debugging Tools
```bash
# Debug tool loading
aia --debug --tools problem_tool.rb test_prompt

# Verbose tool execution
aia --verbose --tools analysis_tool.rb data_analysis

# Test tool isolation
ruby -r './my_tool.rb' -e "puts MyTool.new.test_method('input')"
```

## Related Documentation

- [Tools Integration Guide](../../guides/tools.md) - Detailed tool development guide
- [Advanced Prompting](../../advanced-prompting.md) - Complex tool integration
- [MCP Examples](../mcp/index.md) - Alternative integration approach
- [Configuration](../../configuration.md) - Tool configuration options

---

Tools are the backbone of AIA's extensibility. Start with simple analysis tools and gradually build more sophisticated capabilities as your needs grow!