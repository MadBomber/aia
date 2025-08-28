# Tools Integration

AIA's tools system extends AI capabilities with custom Ruby functions, enabling AI models to perform actions, access external services, and process data beyond text generation.

## Understanding Tools

### What are Tools?
Tools are Ruby classes that inherit from `RubyLLM::Tool` and provide specific capabilities to AI models:
- **File operations**: Read, write, analyze files
- **Web interactions**: HTTP requests, API calls, web scraping  
- **Data processing**: Analysis, transformation, calculations
- **System integration**: Shell commands, external services
- **Custom logic**: Business-specific operations

### Tool Architecture
```ruby
class MyTool < RubyLLM::Tool
  description "Brief description of what this tool does"
  
  def tool_method(parameter1, parameter2 = nil)
    # Tool implementation
    "Result that gets returned to the AI"
  end
  
  private
  
  def helper_method
    # Internal helper methods
  end
end
```

## Using Existing Tools

### Enabling Tools
```bash
# Use tools from a specific file
aia --tools my_tool.rb my_prompt

# Use all tools in a directory
aia --tools ./tools/ my_prompt

# Use multiple tool sources
aia --tools "./tools/,./custom_tools.rb,/shared/tools/" my_prompt
```

### Tool Security
```bash
# Restrict to specific tools
aia --tools ./tools/ --allowed_tools "file_reader,calculator" my_prompt

# Block dangerous tools
aia --tools ./tools/ --rejected_tools "file_writer,system_admin" my_prompt

# Combine restrictions
aia --tools ./tools/ --allowed_tools "safe_tools" --rejected_tools "dangerous_tools" my_prompt
```

### Discovering Available Tools
```bash
# List available tools
aia --tools ./tools/ tool_discovery_prompt

# Or within a prompt
//tools
```

## Creating Custom Tools

### Basic Tool Structure
```ruby
# ~/.aia/tools/file_analyzer.rb
class FileAnalyzer < RubyLLM::Tool
  description "Analyzes files for structure, content, and metadata"
  
  def analyze_file(file_path, analysis_type = "basic")
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    case analysis_type
    when "basic"
      basic_analysis(file_path)
    when "detailed"
      detailed_analysis(file_path)
    when "security"
      security_analysis(file_path)
    else
      "Unknown analysis type: #{analysis_type}"
    end
  end
  
  def file_stats(file_path)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    stat = File.stat(file_path)
    {
      size: stat.size,
      created: stat.ctime,
      modified: stat.mtime,
      permissions: stat.mode.to_s(8),
      type: File.directory?(file_path) ? "directory" : "file"
    }.to_json
  end
  
  private
  
  def basic_analysis(file_path)
    content = File.read(file_path)
    lines = content.lines.count
    words = content.split.count
    chars = content.length
    
    "File: #{File.basename(file_path)}\nLines: #{lines}\nWords: #{words}\nCharacters: #{chars}"
  end
  
  def detailed_analysis(file_path)
    basic = basic_analysis(file_path)
    content = File.read(file_path)
    
    # Language detection
    ext = File.extname(file_path).downcase
    language = detect_language(ext, content)
    
    # Additional analysis
    encoding = content.encoding.to_s
    blank_lines = content.lines.count(&:strip.empty?)
    
    "#{basic}\nLanguage: #{language}\nEncoding: #{encoding}\nBlank lines: #{blank_lines}"
  end
  
  def security_analysis(file_path)
    content = File.read(file_path)
    issues = []
    
    # Check for potential security issues
    issues << "Contains potential passwords" if content.match?(/password\s*=\s*["'][^"']+["']/i)
    issues << "Contains API keys" if content.match?(/api[_-]?key\s*[:=]\s*["'][^"']+["']/i)
    issues << "Contains hardcoded URLs" if content.match?/https?:\/\/[^\s]+/
    issues << "Contains TODO/FIXME items" if content.match?/(TODO|FIXME|HACK)/i
    
    if issues.empty?
      "No obvious security issues found in #{File.basename(file_path)}"
    else
      "Security concerns in #{File.basename(file_path)}:\n- #{issues.join("\n- ")}"
    end
  end
  
  def detect_language(ext, content)
    case ext
    when '.rb' then 'Ruby'
    when '.py' then 'Python'
    when '.js' then 'JavaScript'
    when '.java' then 'Java'
    when '.cpp', '.cc', '.cxx' then 'C++'
    when '.c' then 'C'
    when '.go' then 'Go'
    when '.rs' then 'Rust'
    else
      # Simple heuristics based on content
      return 'Ruby' if content.match?(/def\s+\w+|class\s+\w+|require ['"]/)
      return 'Python' if content.match?(/def \w+\(|import \w+|from \w+ import/)
      return 'JavaScript' if content.match?(/function\s+\w+|const\s+\w+|let\s+\w+/)
      'Unknown'
    end
  end
end
```

### Web Integration Tool
```ruby
# ~/.aia/tools/web_client.rb
require 'net/http'
require 'json'
require 'uri'

class WebClient < RubyLLM::Tool
  description "Performs HTTP requests and web API interactions"
  
  def get_url(url, headers = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    
    response = http.request(request)
    
    {
      status: response.code,
      headers: response.to_hash,
      body: response.body
    }.to_json
  end
  
  def post_json(url, data, headers = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    headers.each { |key, value| request[key] = value }
    request.body = data.to_json
    
    response = http.request(request)
    
    {
      status: response.code,
      body: response.body
    }.to_json
  end
  
  def check_url_status(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 10
    
    begin
      response = http.head(uri.path.empty? ? '/' : uri.path)
      "#{url}: #{response.code} #{response.message}"
    rescue => e
      "#{url}: Error - #{e.message}"
    end
  end
  
  def fetch_api_data(endpoint, api_key = nil, params = {})
    uri = URI(endpoint)
    
    # Add query parameters
    unless params.empty?
      uri.query = params.map { |k, v| "#{k}=#{v}" }.join('&')
    end
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}" if api_key
    request['User-Agent'] = 'AIA-Tools/1.0'
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      { error: "API request failed", status: response.code, message: response.body }
    end
  rescue JSON::ParserError
    { error: "Invalid JSON response", raw_body: response.body }
  rescue => e
    { error: e.message }
  end
end
```

### Data Analysis Tool
```ruby
# ~/.aia/tools/data_analyzer.rb
require 'csv'
require 'json'

class DataAnalyzer < RubyLLM::Tool
  description "Analyzes CSV data, JSON files, and performs statistical calculations"
  
  def analyze_csv(file_path, delimiter = ',')
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    begin
      data = CSV.read(file_path, headers: true, col_sep: delimiter)
      
      analysis = {
        rows: data.length,
        columns: data.headers.length,
        headers: data.headers,
        sample_data: data.first(3).map(&:to_h),
        column_types: analyze_column_types(data),
        missing_values: count_missing_values(data)
      }
      
      JSON.pretty_generate(analysis)
    rescue => e
      "Error analyzing CSV: #{e.message}"
    end
  end
  
  def calculate_statistics(file_path, column_name)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    begin
      data = CSV.read(file_path, headers: true)
      values = data[column_name].compact.map(&:to_f)
      
      return "Column not found or no numeric data" if values.empty?
      
      stats = {
        count: values.length,
        mean: values.sum / values.length.to_f,
        median: median(values),
        min: values.min,
        max: values.max,
        range: values.max - values.min,
        std_dev: standard_deviation(values)
      }
      
      JSON.pretty_generate(stats)
    rescue => e
      "Error calculating statistics: #{e.message}"
    end
  end
  
  def find_correlations(file_path, columns = nil)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    begin
      data = CSV.read(file_path, headers: true)
      
      # Get numeric columns
      numeric_columns = columns || data.headers.select do |header|
        data[header].compact.all? { |value| numeric?(value) }
      end
      
      correlations = {}
      
      numeric_columns.combination(2) do |col1, col2|
        values1 = data[col1].compact.map(&:to_f)
        values2 = data[col2].compact.map(&:to_f)
        
        if values1.length == values2.length && values1.length > 1
          corr = correlation(values1, values2)
          correlations["#{col1} vs #{col2}"] = corr.round(4)
        end
      end
      
      JSON.pretty_generate(correlations)
    rescue => e
      "Error calculating correlations: #{e.message}"
    end
  end
  
  def json_summary(file_path)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    begin
      data = JSON.parse(File.read(file_path))
      
      summary = {
        type: data.class.name,
        structure: analyze_json_structure(data),
        size: data.respond_to?(:length) ? data.length : 1,
        keys: data.is_a?(Hash) ? data.keys : nil
      }
      
      JSON.pretty_generate(summary)
    rescue JSON::ParserError => e
      "Invalid JSON file: #{e.message}"
    rescue => e
      "Error analyzing JSON: #{e.message}"
    end
  end
  
  private
  
  def analyze_column_types(data)
    types = {}
    data.headers.each do |header|
      sample_values = data[header].compact.first(100)
      
      if sample_values.all? { |v| numeric?(v) }
        types[header] = 'numeric'
      elsif sample_values.all? { |v| date_like?(v) }
        types[header] = 'date'
      else
        types[header] = 'text'
      end
    end
    types
  end
  
  def count_missing_values(data)
    missing = {}
    data.headers.each do |header|
      missing_count = data[header].count { |v| v.nil? || v.strip.empty? }
      missing[header] = missing_count if missing_count > 0
    end
    missing
  end
  
  def numeric?(value)
    Float(value) rescue false
  end
  
  def date_like?(value)
    Date.parse(value) rescue false
  end
  
  def median(values)
    sorted = values.sort
    len = sorted.length
    len.even? ? (sorted[len/2 - 1] + sorted[len/2]) / 2.0 : sorted[len/2]
  end
  
  def standard_deviation(values)
    mean = values.sum / values.length.to_f
    variance = values.sum { |v| (v - mean) ** 2 } / values.length.to_f
    Math.sqrt(variance)
  end
  
  def correlation(x, y)
    n = x.length
    sum_x = x.sum
    sum_y = y.sum
    sum_x2 = x.sum { |v| v ** 2 }
    sum_y2 = y.sum { |v| v ** 2 }
    sum_xy = x.zip(y).sum { |a, b| a * b }
    
    numerator = n * sum_xy - sum_x * sum_y
    denominator = Math.sqrt((n * sum_x2 - sum_x ** 2) * (n * sum_y2 - sum_y ** 2))
    
    denominator == 0 ? 0 : numerator / denominator
  end
  
  def analyze_json_structure(data, max_depth = 3, current_depth = 0)
    return "..." if current_depth >= max_depth
    
    case data
    when Hash
      sample_keys = data.keys.first(5)
      structure = {}
      sample_keys.each do |key|
        structure[key] = analyze_json_structure(data[key], max_depth, current_depth + 1)
      end
      structure["..."] = "#{data.keys.length - 5} more keys" if data.keys.length > 5
      structure
    when Array
      return [] if data.empty?
      [analyze_json_structure(data.first, max_depth, current_depth + 1)]
    else
      data.class.name
    end
  end
end
```

## Advanced Tool Patterns

### Tool with Configuration
```ruby
class ConfigurableTool < RubyLLM::Tool
  description "Tool that can be configured for different environments"
  
  def initialize
    super
    @config = load_config
  end
  
  def process_data(input, environment = 'development')
    config = @config[environment]
    # Use environment-specific configuration
    process_with_config(input, config)
  end
  
  private
  
  def load_config
    config_file = File.join(Dir.home, '.aia', 'tool_config.yml')
    if File.exist?(config_file)
      YAML.load_file(config_file)
    else
      default_config
    end
  end
  
  def default_config
    {
      'development' => { 'api_endpoint' => 'http://localhost:3000', 'timeout' => 30 },
      'production' => { 'api_endpoint' => 'https://api.example.com', 'timeout' => 10 }
    }
  end
end
```

### Tool with Caching
```ruby
class CachedTool < RubyLLM::Tool
  description "Tool with intelligent caching for expensive operations"
  
  def expensive_operation(input)
    cache_key = Digest::MD5.hexdigest(input)
    cache_file = "/tmp/tool_cache_#{cache_key}.json"
    
    if File.exist?(cache_file) && fresh_cache?(cache_file)
      JSON.parse(File.read(cache_file))
    else
      result = perform_expensive_operation(input)
      File.write(cache_file, result.to_json)
      result
    end
  end
  
  private
  
  def fresh_cache?(cache_file, max_age = 3600)
    (Time.now - File.mtime(cache_file)) < max_age
  end
  
  def perform_expensive_operation(input)
    # Simulate expensive operation
    sleep 2
    { result: "Processed: #{input}", timestamp: Time.now }
  end
end
```

### Error-Resilient Tool
```ruby
class ResilientTool < RubyLLM::Tool
  description "Tool with comprehensive error handling and recovery"
  
  def reliable_operation(input, max_retries = 3)
    attempts = 0
    
    begin
      attempts += 1
      perform_operation(input)
    rescue StandardError => e
      if attempts <= max_retries
        wait_time = 2 ** attempts  # Exponential backoff
        sleep wait_time
        retry
      else
        {
          error: true,
          message: "Operation failed after #{max_retries} attempts",
          last_error: e.message,
          suggestion: "Try with simpler input or check system resources"
        }.to_json
      end
    end
  end
  
  def safe_file_operation(file_path)
    return "File path required" if file_path.nil? || file_path.empty?
    return "File not found: #{file_path}" unless File.exist?(file_path)
    return "Access denied: #{file_path}" unless File.readable?(file_path)
    
    begin
      File.read(file_path)
    rescue => e
      "Error reading file: #{e.message}"
    end
  end
  
  private
  
  def perform_operation(input)
    # Simulate operation that might fail
    raise "Random failure" if rand < 0.3
    { success: true, data: "Processed #{input}" }
  end
end
```

## Tool Integration in Prompts

### Basic Tool Usage
```markdown
# ~/.prompts/file_analysis.txt
//tools file_analyzer.rb

# File Analysis Report

Please analyze the following file:
File path: <%= file_path %>

Use the file_analyzer tool to:
1. Get basic file statistics
2. Perform detailed content analysis
3. Check for security issues

Provide a comprehensive report with recommendations.
```

### Multi-Tool Workflows
```markdown
# ~/.prompts/web_data_analysis.txt
//tools web_client.rb,data_analyzer.rb

# Web Data Analysis Pipeline

Data source URL: <%= api_url %>
API key: <%= api_key %>

## Step 1: Fetch Data
Use the web_client tool to retrieve data from the API endpoint.

## Step 2: Save and Analyze
Save the data to a temporary CSV file and use data_analyzer to:
- Generate summary statistics
- Identify data patterns
- Find correlations

## Step 3: Generate Insights  
Based on the analysis, provide actionable insights and recommendations.
```

### Conditional Tool Usage
```ruby
# ~/.prompts/adaptive_analysis.txt
//ruby
input_file = '<%= input_file %>'
file_ext = File.extname(input_file).downcase

case file_ext
when '.csv'
  puts "//tools data_analyzer.rb"
  analysis_type = "CSV data analysis"
when '.json'
  puts "//tools data_analyzer.rb"
  analysis_type = "JSON structure analysis"
when '.rb', '.py', '.js'
  puts "//tools file_analyzer.rb"
  analysis_type = "Code analysis"
else
  puts "//tools file_analyzer.rb"
  analysis_type = "General file analysis"
end

puts "Selected #{analysis_type} for #{file_ext} file"
```

Perform #{analysis_type} on: <%= input_file %>

Provide detailed insights appropriate for the file type.
```

## Tool Security and Best Practices

### Security Guidelines
1. **Input Validation**: Always validate tool inputs
2. **File System Access**: Limit file access to safe directories
3. **Network Requests**: Validate URLs and handle errors
4. **Resource Limits**: Implement timeouts and size limits
5. **Error Handling**: Never expose system details in errors

### Performance Considerations
1. **Caching**: Cache expensive operations appropriately
2. **Timeouts**: Set reasonable timeouts for external calls
3. **Memory Management**: Handle large data sets efficiently
4. **Async Operations**: Use async patterns for I/O operations
5. **Resource Cleanup**: Properly clean up resources

### Testing Tools
```ruby
# test_tool.rb
require 'minitest/autorun'
require_relative 'my_tool'

class TestMyTool < Minitest::Test
  def setup
    @tool = MyTool.new
  end
  
  def test_basic_functionality
    result = @tool.process_data("test input")
    assert_kind_of String, result
    refute_empty result
  end
  
  def test_error_handling
    result = @tool.process_data(nil)
    assert_includes result, "error"
  end
end
```

## Tool Distribution and Sharing

### Tool Libraries
```bash
# Organize tools in libraries
~/.aia/tools/
├── core/           # Essential tools
│   ├── file_ops.rb
│   ├── web_client.rb
│   └── data_analysis.rb
├── development/    # Development tools
│   ├── code_analyzer.rb
│   ├── test_runner.rb
│   └── deploy_helper.rb
└── specialized/    # Domain-specific tools
    ├── finance_tools.rb
    ├── media_tools.rb
    └── science_tools.rb
```

### Tool Documentation
```ruby
class DocumentedTool < RubyLLM::Tool
  description "Example of well-documented tool with usage examples"
  
  # Processes input data with specified options
  # @param input [String] The input data to process
  # @param format [String] Output format: 'json', 'csv', or 'text'
  # @param options [Hash] Additional processing options
  # @return [String] Processed data in specified format
  # @example
  #   process_data("sample", "json", { detailed: true })
  def process_data(input, format = 'text', options = {})
    # Implementation
  end
end
```

## Troubleshooting Tools

### Common Issues
1. **Tool Not Found**: Check tool file paths and syntax
2. **Permission Errors**: Verify file permissions and access rights
3. **Missing Dependencies**: Install required gems and libraries
4. **Method Errors**: Check method signatures and parameters
5. **Runtime Errors**: Add proper error handling and logging

### Debugging Tools
```ruby
class DebuggingTool < RubyLLM::Tool
  description "Tool with extensive debugging capabilities"
  
  def debug_operation(input)
    debug_log("Starting operation with input: #{input}")
    
    begin
      result = process_input(input)
      debug_log("Operation successful: #{result}")
      result
    rescue => e
      debug_log("Operation failed: #{e.message}")
      debug_log("Backtrace: #{e.backtrace.first(5).join("\n")}")
      raise
    end
  end
  
  private
  
  def debug_log(message)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    puts "[DEBUG #{timestamp}] #{message}" if debug_mode?
  end
  
  def debug_mode?
    ENV['AIA_DEBUG'] == 'true'
  end
end
```

## MCP Client Integration

### Model Context Protocol (MCP) Support

AIA supports MCP clients for extended functionality through external services:

#### GitHub MCP Server
```bash
# Install GitHub MCP server
brew install github-mcp-server

# Set required environment variable
export GITHUB_PERSONAL_ACCESS_TOKEN="your_token_here"

# Use with AIA
aia --tools examples/tools/mcp/github_mcp_server.rb --chat
```

**Capabilities:**
- Repository analysis and management
- Issue tracking and manipulation
- Pull request automation
- Code review assistance
- Project metrics and insights

#### iMCP for macOS
```bash
# Install iMCP (macOS only)
brew install --cask loopwork/tap/iMCP

# Use with AIA  
aia --tools examples/tools/mcp/imcp.rb --chat
```

**Capabilities:**
- Access to macOS Notes app
- Calendar integration
- Contacts management
- System information access
- File system operations

### MCP Client Requirements

MCP clients require:
- The `ruby_llm-mcp` gem (automatically included with AIA)
- Proper MCP server installation and configuration
- Required environment variables and permissions
- Network access for external MCP servers

## Shared Tools Collection

### Using the Shared Tools Gem

AIA can use the [shared_tools gem](https://github.com/madbomber/shared_tools) for common functionality:

```bash
# Access all shared tools (included with AIA)
aia --require shared_tools/ruby_llm --chat

# Access specific shared tool
aia --require shared_tools/ruby_llm/edit_file --chat

# Combine with custom tools
aia --require shared_tools/ruby_llm --tools ~/my-tools/ --chat

# Use in batch prompts
aia --require shared_tools/ruby_llm my_prompt input.txt
```

### Available Shared Tools

The shared_tools collection includes:
- **File Operations**: Reading, writing, editing files
- **Data Processing**: JSON/CSV manipulation, data transformation
- **Web Operations**: HTTP requests, web scraping
- **System Operations**: Process management, system information
- **Utility Functions**: String processing, date manipulation

### ERB Integration with Shared Tools

```ruby
# In prompt files with ERB
//ruby
require 'shared_tools/ruby_llm'
```

Use shared tools directly within your prompts using Ruby directives.

## Related Documentation

- [Chat Mode](chat.md) - Using tools in interactive mode
- [Advanced Prompting](../advanced-prompting.md) - Complex tool integration patterns
- [MCP Integration](../mcp-integration.md) - Model Context Protocol details
- [Configuration](../configuration.md) - Tool configuration options
- [CLI Reference](../cli-reference.md) - Tool-related command-line options
- [Examples](../examples/tools/index.md) - Real-world tool examples

---

Tools transform AIA from a text processor into a powerful automation platform. Start with simple tools and gradually build more sophisticated capabilities as your needs grow!