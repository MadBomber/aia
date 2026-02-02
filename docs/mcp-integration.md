# MCP Integration

AIA supports Model Context Protocol (MCP) clients, enabling AI models to interact with external services, databases, and applications through standardized interfaces.

## Understanding MCP

### What is MCP?
Model Context Protocol (MCP) is a standardized way for AI models to interact with external resources:
- **Database Access**: Query and manipulate databases
- **File System Operations**: Safe, sandboxed file operations
- **API Integrations**: Structured access to web APIs
- **Tool Extensions**: Custom functionality through protocol
- **Service Integration**: Connect to external services and platforms

### MCP vs RubyLLM Tools
| Feature | RubyLLM Tools | MCP Clients |
|---------|---------------|-------------|
| **Language** | Ruby only | Any language |
| **Security** | Ruby sandbox | Protocol-level security |
| **Distribution** | Ruby gems/files | Separate processes |
| **Standardization** | AIA-specific | Industry standard |
| **Performance** | Direct calls | IPC overhead |

## Enabling MCP Support

### Configuration
```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: github
    command: /path/to/github-mcp-server
    args: []
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
    timeout: 8000

  - name: filesystem
    command: mcp-server-filesystem
    args:
      - /allowed/path1
      - /allowed/path2

  - name: database
    command: /path/to/db-mcp-server.py
    env:
      DATABASE_URL: "${DATABASE_URL}"
```

### Command Line Usage
```bash
# Load MCP servers from JSON config files
aia --mcp github.json --mcp filesystem.json my_prompt

# List configured MCP servers
aia --mcp-list

# Use only specific MCP servers
aia --mcp-use github,filesystem --chat

# Skip specific MCP servers
aia --mcp-skip playwright --chat

# List all tools including MCP tools
aia --mcp-list --list-tools

# List tools from a specific MCP server
aia --mcp-list --mcp-use github --list-tools

# Debug MCP communication
aia --debug --mcp github.json github_analysis
```

## Available MCP Clients

### GitHub Integration
Connect to GitHub repositories and operations:

```bash
# Install GitHub MCP server
npm install -g @anthropic-ai/mcp-server-github

# Configure in ~/.config/aia/aia.yml
mcp_servers:
  - name: github
    command: npx
    args:
      - "@anthropic-ai/mcp-server-github"
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
```

**Capabilities**:
- Repository analysis
- Issue management  
- Pull request operations
- File content access
- Commit history analysis

### File System Access
Safe file system operations with sandboxing:

```bash
# Install filesystem MCP server
npm install -g @anthropic-ai/mcp-server-filesystem

# Configure with allowed paths
mcp:
  clients:
    - name: filesystem
      command: ["npx", "@anthropic-ai/mcp-server-filesystem"]
      args: ["/home/user/projects", "/tmp/aia-workspace"]
```

**Capabilities**:
- Read files and directories
- Write files (in allowed paths)
- File metadata access
- Directory traversal
- Search operations

### Database Integration
Connect to SQL databases:

```python
# Example database MCP server (Python)
#!/usr/bin/env python3
import asyncio
import os
from mcp.server import Server
from mcp.types import Resource, Tool
import sqlite3

server = Server("database-mcp")

@server.list_tools()
async def list_tools():
    return [
        Tool(name="query", description="Execute SQL query"),
        Tool(name="describe", description="Describe table structure")
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "query":
        return execute_query(arguments["sql"])
    elif name == "describe":
        return describe_table(arguments["table"])
```

## Using MCP Clients in Prompts

### GitHub Analysis
```markdown
# ~/.prompts/github_analysis.txt
//mcp github

# GitHub Repository Analysis

Repository: <%= repo_url %>

## Repository Overview
Use the GitHub MCP client to analyze:
1. Repository structure and organization
2. Recent commit activity and patterns
3. Open issues and their categories
4. Pull request status and reviews
5. Contributors and contribution patterns

## Code Quality Assessment
Examine key files:
- README and documentation quality
- Code organization and structure
- Testing coverage and practices
- Dependency management

Provide comprehensive analysis with actionable recommendations.
```

### File System Operations
```markdown
# ~/.prompts/project_analysis.txt
//mcp filesystem

# Project Structure Analysis

Project directory: <%= project_path %>

## Structure Analysis
Use the filesystem MCP client to:
1. Map directory structure and organization
2. Identify configuration files and their purposes
3. Analyze code distribution across languages
4. Find documentation and README files
5. Locate test files and coverage

## Code Organization Review
Examine:
- Logical grouping of related files
- Naming conventions consistency
- Dependency organization
- Build and deployment configurations

Generate detailed project assessment with improvement suggestions.
```

### Database Schema Analysis
```markdown
# ~/.prompts/database_analysis.txt
//mcp database

# Database Schema Analysis

Database: <%= database_name %>

## Schema Overview
Use the database MCP client to:
1. List all tables and their relationships
2. Analyze table structures and data types
3. Identify primary keys and foreign key relationships
4. Examine indexes and constraints
5. Review stored procedures and views

## Data Quality Assessment
Check for:
- Naming convention consistency
- Normalization level appropriateness
- Index optimization opportunities
- Data integrity constraints
- Performance bottlenecks

Provide recommendations for schema improvements and optimizations.
```

## Advanced MCP Integration

### Multi-Client Workflows
```markdown
# ~/.prompts/full_project_audit.txt
//mcp github,filesystem,database

# Comprehensive Project Audit

Project: <%= project_name %>
Repository: <%= repo_url %>
Database: <%= db_name %>

## Phase 1: Code Repository Analysis
Using GitHub MCP client:
- Repository health and activity
- Code quality and organization
- Issue and PR management
- Developer productivity metrics

## Phase 2: File System Structure
Using filesystem MCP client:
- Local project organization
- Configuration management
- Documentation completeness
- Build and deployment setup

## Phase 3: Database Architecture  
Using database MCP client:
- Schema design and integrity
- Performance optimization
- Data governance compliance
- Migration and versioning

## Integration Assessment
Cross-analyze findings to identify:
- Consistency across repository and local files
- Database schema alignment with application code
- Documentation accuracy and completeness
- Deployment and configuration coherence

Generate comprehensive audit report with prioritized recommendations.
```

### Conditional MCP Usage
```ruby
# ~/.prompts/adaptive_mcp.txt
//ruby
project_type = '<%= project_type %>'
has_database = '<%= has_database %>' == 'true'
is_open_source = '<%= is_open_source %>' == 'true'

mcp_clients = []
mcp_clients << 'filesystem'  # Always analyze file structure
mcp_clients << 'github' if is_open_source
mcp_clients << 'database' if has_database

puts "//mcp #{mcp_clients.join(',')}"
puts "Selected MCP clients for #{project_type} project: #{mcp_clients.join(', ')}"
```

# Adaptive Project Analysis

Project type: <%= project_type %>
Analysis scope: <%= mcp_clients.join(', ') %>

Perform comprehensive analysis using available MCP clients to provide insights specific to this project type.
```

## Custom MCP Client Development

### Basic MCP Server Structure
```python
# custom_mcp_server.py
import asyncio
from mcp.server import Server
from mcp.types import Resource, Tool, TextContent

server = Server("custom-service")

@server.list_resources()
async def list_resources():
    return [
        Resource(
            uri="service://data/users",
            name="User Data",
            description="Access to user information"
        )
    ]

@server.list_tools() 
async def list_tools():
    return [
        Tool(
            name="get_user",
            description="Retrieve user information by ID",
            inputSchema={
                "type": "object",
                "properties": {
                    "user_id": {"type": "string"}
                },
                "required": ["user_id"]
            }
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "get_user":
        user_data = fetch_user(arguments["user_id"])
        return TextContent(type="text", text=str(user_data))

def fetch_user(user_id):
    # Custom logic to fetch user data
    return {"id": user_id, "name": "Example User"}

if __name__ == "__main__":
    asyncio.run(server.run())
```

### Node.js MCP Server
```javascript
// custom-mcp-server.js
const { Server } = require('@anthropic-ai/mcp-sdk/server');

const server = new Server('custom-service', '1.0.0');

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'process_data',
        description: 'Process custom data',
        inputSchema: {
          type: 'object',
          properties: {
            data: { type: 'string' },
            format: { type: 'string', enum: ['json', 'csv', 'xml'] }
          },
          required: ['data']
        }
      }
    ]
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;
  
  if (name === 'process_data') {
    const result = processData(args.data, args.format || 'json');
    return { content: [{ type: 'text', text: result }] };
  }
  
  throw new Error(`Unknown tool: ${name}`);
});

function processData(data, format) {
  // Custom processing logic
  return `Processed data in ${format} format: ${data}`;
}

server.connect();
```

## MCP Security and Best Practices

### Security Configuration
```yaml
# Secure MCP configuration
mcp:
  security:
    sandbox_mode: true
    allowed_operations: ["read", "list"]
    blocked_operations: ["delete", "execute"]
    
  resource_limits:
    max_file_size: 10485760  # 10MB
    max_query_results: 1000
    timeout_seconds: 30
    
  clients:
    - name: filesystem
      command: ["mcp-server-filesystem"]
      args: ["/safe/path/only"]
      security_context: "restricted"
      
    - name: database
      command: ["database-mcp-server"]
      security_context: "read_only"
      env:
        DB_READ_ONLY: "true"
```

### Access Control
```ruby
# MCP access control in prompts
//ruby
user_role = '<%= user_role %>'
allowed_mcp = case user_role
             when 'admin'
               ['github', 'filesystem', 'database']
             when 'developer'
               ['github', 'filesystem']  
             when 'analyst'
               ['database']
             else
               []
             end

if allowed_mcp.empty?
  puts "No MCP access for role: #{user_role}"
else
  puts "//mcp #{allowed_mcp.join(',')}"
  puts "MCP access granted: #{allowed_mcp.join(', ')}"
end
```

## Performance Optimization

### Connection Pooling
```yaml
mcp:
  connection_pooling:
    enabled: true
    max_connections: 5
    idle_timeout: 300
    
  caching:
    enabled: true
    ttl: 3600  # 1 hour
    max_size: 100  # Cache entries
```

### Async Operations
```python
# Async MCP server for better performance
import asyncio
import aiohttp
from mcp.server import Server

server = Server("async-service")

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "fetch_data":
        async with aiohttp.ClientSession() as session:
            async with session.get(arguments["url"]) as response:
                data = await response.text()
                return TextContent(type="text", text=data)
```

## Troubleshooting MCP

### Common Issues

#### Client Connection Failures
```bash
# Debug MCP client connections
aia --debug --mcp github test_prompt

# Check client status
aia --mcp-status

# Test individual client
aia --test-mcp github
```

#### Protocol Errors
```yaml
# Enable detailed MCP logging
mcp:
  logging:
    level: debug
    file: /tmp/aia-mcp.log
    
  error_handling:
    retry_attempts: 3
    retry_delay: 1000  # milliseconds
    fallback_mode: graceful
```

#### Performance Issues
```bash
# Monitor MCP performance
aia --mcp-metrics github filesystem

# Profile MCP operations
aia --profile --mcp database analysis_prompt
```

### Debugging Tools
```python
# MCP debugging utilities
async def debug_mcp_call(client, tool, args):
    start_time = time.time()
    try:
        result = await client.call_tool(tool, args)
        duration = time.time() - start_time
        print(f"MCP call successful: {tool} in {duration:.2f}s")
        return result
    except Exception as e:
        duration = time.time() - start_time
        print(f"MCP call failed: {tool} after {duration:.2f}s - {e}")
        raise
```

## MCP Examples Repository

### GitHub Repository Analysis
```markdown
# ~/.prompts/mcp_examples/github_repo_health.txt
//mcp github

# GitHub Repository Health Check

Repository: <%= repository %>

## Comprehensive Health Analysis
1. **Activity Metrics**
   - Commit frequency and patterns
   - Contributor activity and distribution
   - Issue resolution time and patterns
   - Pull request merge rates

2. **Code Quality Indicators**
   - Documentation coverage
   - Test file presence and organization
   - Dependency management practices
   - Security vulnerability reports

3. **Community Engagement**
   - Issue discussion quality
   - Response times to community contributions
   - Maintainer activity levels
   - Project governance clarity

4. **Technical Debt Assessment**
   - Outstanding bugs and technical issues
   - Code review thoroughness
   - Deprecated dependency usage
   - Architecture evolution patterns

Generate detailed health score with specific improvement recommendations.
```

### File System Audit
```markdown
# ~/.prompts/mcp_examples/filesystem_audit.txt
//mcp filesystem

# File System Security and Organization Audit

Target directory: <%= target_path %>

## Security Assessment
1. **Permission Analysis**
   - File and directory permissions
   - Ownership consistency
   - Sensitive file exposure
   - Configuration file security

2. **Organization Review**
   - Directory structure logic
   - File naming consistency
   - Duplicate file detection
   - Orphaned file identification

3. **Compliance Check**
   - Standard directory compliance
   - Required file presence
   - Documentation completeness
   - License file availability

4. **Optimization Opportunities**
   - Large file identification
   - Unused file detection
   - Archive opportunities
   - Cleanup recommendations

Provide prioritized action plan for security and organization improvements.
```

## Related Documentation

- [Tools Integration](guides/tools.md) - RubyLLM tools vs MCP comparison
- [Advanced Prompting](advanced-prompting.md) - Complex MCP integration patterns
- [Configuration](configuration.md) - MCP configuration options
- [Security Best Practices](security.md) - MCP security guidelines
- [Examples](examples/mcp/index.md) - Real-world MCP examples

---

MCP integration extends AIA's capabilities beyond Ruby tools, providing standardized access to external services and enabling complex, multi-system workflows. Start with simple integrations and gradually build more sophisticated MCP-based solutions!