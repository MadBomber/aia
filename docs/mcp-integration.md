<!-- Tocer[start]: Auto-generated, don't remove. -->

## Table of Contents

- [MCP Integration](#mcp-integration)
  - [Understanding MCP](#understanding-mcp)
    - [What is MCP?](#what-is-mcp)
    - [MCP vs RubyLLM Tools](#mcp-vs-rubyllm-tools)
  - [Enabling MCP Support](#enabling-mcp-support)
    - [Configuration](#configuration)
    - [Command Line Usage](#command-line-usage)
  - [Available MCP Clients](#available-mcp-clients)
    - [GitHub Integration](#github-integration)
    - [File System Access](#file-system-access)
    - [Database Integration](#database-integration)
  - [Using MCP Clients in Prompts](#using-mcp-clients-in-prompts)
    - [GitHub Analysis](#github-analysis)
    - [File System Operations](#file-system-operations)
    - [Database Schema Analysis](#database-schema-analysis)
  - [Advanced MCP Integration](#advanced-mcp-integration)
    - [Multi-Client Workflows](#multi-client-workflows)
    - [Conditional MCP Usage](#conditional-mcp-usage)
  - [Custom MCP Client Development](#custom-mcp-client-development)
    - [Basic MCP Server Structure](#basic-mcp-server-structure)
    - [Node.js MCP Server](#nodejs-mcp-server)
  - [MCP Security and Best Practices](#mcp-security-and-best-practices)
    - [Access Control](#access-control)
    - [Server Configuration Security](#server-configuration-security)
    - [Parallel Connections](#parallel-connections)
  - [Troubleshooting MCP](#troubleshooting-mcp)
    - [Common Issues](#common-issues)
      - [Client Connection Failures](#client-connection-failures)
      - [Protocol Errors](#protocol-errors)
  - [MCP Examples Repository](#mcp-examples-repository)
    - [GitHub Repository Analysis](#github-repository-analysis)
    - [File System Audit](#file-system-audit)
  - [Related Documentation](#related-documentation)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

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

# Configure in ~/.config/aia/aia.yml
mcp_servers:
  - name: filesystem
    command: npx
    args:
      - "@anthropic-ai/mcp-server-filesystem"
      - /home/user/projects
      - /tmp/aia-workspace
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
# ~/.prompts/github_analysis.md
# Requires MCP server "github" configured in ~/.config/aia/aia.yml

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
# ~/.prompts/project_analysis.md
# Requires MCP server "filesystem" configured in ~/.config/aia/aia.yml

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
# ~/.prompts/database_analysis.md
# Requires MCP server "database" configured in ~/.config/aia/aia.yml

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
# ~/.prompts/full_project_audit.md
# Requires MCP server "github" configured in ~/.config/aia/aia.yml,filesystem,database

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

Use `--mcp-use` on the command line to select which MCP servers to activate:

```bash
# Use only specific MCP servers for a prompt
aia --mcp-use github,filesystem my_prompt

# Skip specific servers
aia --mcp-skip database my_prompt
```

Within prompts, you can document which MCP servers are expected:

```markdown
# ~/.prompts/adaptive_analysis.md
# Requires MCP servers: github, filesystem, database
# Run with: aia --mcp-use github,filesystem,database adaptive_analysis

# Adaptive Project Analysis

Project type: <%= project_type %>

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

### Access Control

Control which MCP servers are available using CLI flags:

```bash
# Allow only specific MCP servers
aia --mcp-use github,filesystem --chat

# Skip specific MCP servers
aia --mcp-skip database --chat

# Use --allowed-tools and --rejected-tools to filter MCP tools
aia --mcp-use github --allowed-tools "github_*" --chat
```

### Server Configuration Security

Limit what each MCP server can access through its own configuration:

```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: filesystem
    command: mcp-server-filesystem
    args:
      - /safe/path/only    # Restrict to specific directories

  - name: database
    command: database-mcp-server
    env:
      DB_READ_ONLY: "true"  # Use server-level env vars for restrictions
      DATABASE_URL: "${DATABASE_URL}"
    timeout: 8000
```

### Parallel Connections

When multiple MCP servers are configured, AIA connects to them in parallel using fiber-based concurrency (via the `simple_flow` gem) for faster startup.

## Troubleshooting MCP

### Common Issues

#### Client Connection Failures
```bash
# Debug MCP client connections
aia --debug --mcp github.json test_prompt

# List configured servers to verify setup
aia --mcp-list

# List MCP server tools to verify connectivity
aia --mcp-list --list-tools
```

#### Protocol Errors

Enable detailed MCP logging via the logger configuration:

```yaml
# ~/.config/aia/aia.yml
logger:
  mcp:
    file: /tmp/aia-mcp.log
    level: debug
    flush: true
```

Or via CLI:
```bash
aia --debug my_prompt  # Sets all loggers to debug level
```

## MCP Examples Repository

### GitHub Repository Analysis
```markdown
# ~/.prompts/mcp_examples/github_repo_health.md
# Requires MCP server "github" configured in ~/.config/aia/aia.yml

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
# ~/.prompts/mcp_examples/filesystem_audit.md
# Requires MCP server "filesystem" configured in ~/.config/aia/aia.yml

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