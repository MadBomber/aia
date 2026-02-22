# MCP Examples

Collection of Model Context Protocol (MCP) client examples and configurations for extending AIA with external services.

## Available MCP Clients

### GitHub Integration
- **github_analyzer.py** - Comprehensive GitHub repository analysis
- **github_issue_manager.js** - Issue tracking and management
- **github_pr_analyzer.py** - Pull request analysis and review
- **github_metrics.rb** - Repository metrics and statistics

### File System Access
- **filesystem_analyzer.py** - Safe file system analysis
- **directory_scanner.js** - Directory structure analysis
- **file_watcher.py** - File change monitoring
- **backup_manager.go** - File backup and versioning

### Database Integration
- **postgres_analyzer.py** - PostgreSQL database analysis
- **mysql_connector.js** - MySQL database operations
- **sqlite_manager.py** - SQLite database management
- **schema_validator.rb** - Database schema validation

### API Integration
- **rest_client.py** - RESTful API client and testing
- **graphql_client.js** - GraphQL query and analysis
- **webhook_server.py** - Webhook handling and processing
- **api_monitor.go** - API performance monitoring

### Development Tools
- **docker_manager.py** - Docker container management
- **kubernetes_analyzer.js** - Kubernetes cluster analysis
- **ci_cd_monitor.py** - CI/CD pipeline monitoring
- **log_aggregator.rb** - Distributed log collection

## MCP Client Structure

MCP clients follow the Model Context Protocol specification:

### Python MCP Server
```python
from mcp.server import Server
from mcp.types import Resource, Tool, TextContent
import asyncio

server = Server("client-name", "1.0.0")

@server.list_tools()
async def list_tools():
    return [
        Tool(
            name="tool_name",
            description="Tool description",
            inputSchema={
                "type": "object",
                "properties": {
                    "param": {"type": "string"}
                },
                "required": ["param"]
            }
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "tool_name":
        result = process_request(arguments["param"])
        return TextContent(type="text", text=result)

if __name__ == "__main__":
    asyncio.run(server.run())
```

### Node.js MCP Server
```javascript
const { Server } = require('@anthropic-ai/mcp-sdk/server');

const server = new Server('client-name', '1.0.0');

server.setRequestHandler('tools/list', async () => {
  return {
    tools: [{
      name: 'tool_name',
      description: 'Tool description',
      inputSchema: {
        type: 'object',
        properties: {
          param: { type: 'string' }
        },
        required: ['param']
      }
    }]
  };
});

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;
  
  if (name === 'tool_name') {
    const result = processRequest(args.param);
    return { content: [{ type: 'text', text: result }] };
  }
});

server.connect();
```

## Configuration Examples

### Basic MCP Configuration
```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: github
    command: python
    args:
      - github_analyzer.py
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"

  - name: filesystem
    command: node
    args:
      - filesystem_analyzer.js
      - /allowed/path

  - name: database
    command: python
    args:
      - postgres_analyzer.py
    env:
      DATABASE_URL: "${DATABASE_URL}"
```

### MCP Configuration with Timeouts
```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: github
    command: python
    args:
      - mcp_clients/github_analyzer.py
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
      LOG_LEVEL: "INFO"
    timeout: 30000

  - name: filesystem
    command: node
    args:
      - mcp_clients/filesystem_analyzer.js
      - /home/user/projects
      - /tmp/workspace

  - name: database
    command: python
    args:
      - mcp_clients/postgres_analyzer.py
    env:
      DATABASE_URL: "${READ_ONLY_DB_URL}"
    timeout: 10000
```

## Usage Examples

### GitHub Repository Analysis
```bash
# Configure GitHub MCP client
export GITHUB_TOKEN="your_github_token"

# Use in AIA prompt
aia --mcp github repo_analysis --owner microsoft --repo vscode
```

```markdown
# github_analysis.md
# Requires MCP server "github" configured in ~/.config/aia/aia.yml

# GitHub Repository Analysis

Repository: <%= owner %>/<%= repo %>

Analyze the repository and provide:
1. Repository health and activity metrics
2. Code quality and organization assessment
3. Issue and PR management effectiveness
4. Contributor activity and patterns
5. Security and maintenance status

Generate comprehensive analysis with recommendations.
```

### Database Schema Analysis
```bash
# Configure database MCP client
export DATABASE_URL="postgresql://user:pass@localhost/db"

# Use in AIA prompt
aia --mcp database schema_analysis --schema public
```

```markdown
# database_analysis.md
# Requires MCP server "database" configured in ~/.config/aia/aia.yml

# Database Schema Analysis

Schema: <%= schema %>

Perform comprehensive database analysis:
1. Table structure and relationships
2. Index optimization opportunities
3. Data quality assessment
4. Performance bottlenecks
5. Security considerations

Provide actionable optimization recommendations.
```

### Multi-Client Integration
```markdown
# comprehensive_project_audit.md
# Requires MCP servers: github, filesystem, database
# Run with: aia --mcp-use github,filesystem,database comprehensive_project_audit

# Comprehensive Project Audit

Project: <%= project_name %>

## Phase 1: Repository Analysis (GitHub MCP)
- Repository health and activity
- Code review processes
- Issue management effectiveness
- Release and deployment practices

## Phase 2: File System Analysis (Filesystem MCP)
- Project structure and organization
- Configuration management
- Documentation completeness
- Security file analysis

## Phase 3: Database Analysis (Database MCP)
- Schema design and integrity
- Performance optimization
- Data quality assessment
- Security configuration

## Integration Analysis
Cross-analyze findings from all systems to identify:
- Consistency across different layers
- Integration gaps and opportunities
- Security vulnerabilities
- Performance optimization priorities

Generate unified recommendations with implementation priority.
```

## Security Considerations

### MCP Security Best Practices

Control MCP server access using CLI flags:

```bash
# Allow only specific MCP servers
aia --mcp-use github,filesystem --chat

# Skip specific MCP servers
aia --mcp-skip database --chat

# Disable all MCP servers
aia --no-mcp --chat
```

Limit what each MCP server can access through its configuration:

```yaml
# ~/.config/aia/aia.yml
mcp_servers:
  - name: filesystem
    command: mcp-server-filesystem
    args:
      - /home/user/projects     # Restrict to safe directories
      - /tmp/aia-workspace

  - name: database
    command: database-mcp-server
    env:
      DATABASE_URL: "${READ_ONLY_DB_URL}"  # Use read-only credentials
    timeout: 10000
```

### Access Control
```python
# MCP client with access control
class SecureGitHubAnalyzer:
    def __init__(self, allowed_operations=None):
        self.allowed_operations = allowed_operations or ['read', 'list']
    
    async def analyze_repository(self, owner, repo):
        if 'read' not in self.allowed_operations:
            raise PermissionError("Read access not allowed")
        
        # Safe repository analysis
        return await self._safe_analyze(owner, repo)
    
    async def _safe_analyze(self, owner, repo):
        # Implementation with safety checks
        pass
```

## Performance Optimization

### Caching Strategies
```python
# MCP client with caching
import asyncio
from datetime import datetime, timedelta
import json

class CachedMCPClient:
    def __init__(self):
        self.cache = {}
        self.cache_ttl = timedelta(hours=1)
    
    async def cached_request(self, cache_key, request_func, *args):
        now = datetime.now()
        
        if cache_key in self.cache:
            cached_result, timestamp = self.cache[cache_key]
            if now - timestamp < self.cache_ttl:
                return cached_result
        
        # Fetch new data
        result = await request_func(*args)
        self.cache[cache_key] = (result, now)
        return result
```

### Connection Pooling
```javascript
// Node.js MCP client with connection pooling
const { Pool } = require('pg');

class DatabaseMCPClient {
  constructor() {
    this.pool = new Pool({
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });
  }
  
  async query(sql, params) {
    const client = await this.pool.connect();
    try {
      const result = await client.query(sql, params);
      return result;
    } finally {
      client.release();
    }
  }
}
```

## Troubleshooting

### Common MCP Issues

#### Connection Failures
```bash
# Debug MCP client connections
aia --debug --mcp github test_connection

# Check client process status
ps aux | grep mcp

# Test client directly
python github_analyzer.py --test
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

#### Performance Issues
```python
# MCP performance monitoring
import time
import logging

class PerformanceMCP:
    def __init__(self):
        self.logger = logging.getLogger('mcp_performance')
    
    async def timed_operation(self, operation_name, func, *args):
        start_time = time.time()
        try:
            result = await func(*args)
            duration = time.time() - start_time
            self.logger.info(f"{operation_name}: {duration:.2f}s")
            return result
        except Exception as e:
            duration = time.time() - start_time
            self.logger.error(f"{operation_name} failed after {duration:.2f}s: {e}")
            raise
```

## Development Guidelines

### MCP Client Development
1. **Follow Protocol** - Implement MCP specification correctly
2. **Error Handling** - Comprehensive error handling and reporting
3. **Security First** - Validate inputs and limit access
4. **Performance** - Optimize for concurrent requests
5. **Testing** - Include unit and integration tests

### Example Test Suite
```python
# test_github_mcp.py
import pytest
import asyncio
from unittest.mock import patch
from github_analyzer import GitHubAnalyzer

@pytest.fixture
def analyzer():
    return GitHubAnalyzer()

@pytest.mark.asyncio
async def test_repository_analysis(analyzer):
    with patch('aiohttp.ClientSession.get') as mock_get:
        mock_get.return_value.__aenter__.return_value.json.return_value = {
            'name': 'test-repo',
            'stargazers_count': 100
        }
        
        result = await analyzer.analyze_repository('owner', 'repo')
        assert result['repository']['name'] == 'test-repo'
        assert result['repository']['stars'] == 100

@pytest.mark.asyncio
async def test_error_handling(analyzer):
    with patch('aiohttp.ClientSession.get') as mock_get:
        mock_get.side_effect = Exception("Network error")
        
        with pytest.raises(Exception):
            await analyzer.analyze_repository('owner', 'repo')
```

## Related Documentation

- [MCP Integration Guide](../../mcp-integration.md) - Detailed MCP integration
- [Tools Examples](../tools/index.md) - Alternative Ruby tools approach
- [Advanced Prompting](../../advanced-prompting.md) - Complex MCP usage patterns
- [Configuration](../../configuration.md) - MCP configuration options

---

MCP clients provide powerful integration capabilities for AIA. Start with simple read-only clients and gradually build more sophisticated integrations as your needs grow!