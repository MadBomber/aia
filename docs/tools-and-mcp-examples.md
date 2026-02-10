# Tools and MCP Examples

This comprehensive collection showcases real-world examples of RubyLLM tools and MCP client integrations, demonstrating practical applications and advanced techniques.

## Real-World Tool Examples

### File Processing Tools

#### Advanced Log Analyzer
```ruby
# ~/.aia/tools/log_analyzer.rb
require 'time'
require 'json'

class LogAnalyzer < RubyLLM::Tool
  description "Analyzes log files for patterns, errors, and performance metrics"
  
  def analyze_logs(log_file, time_range = "24h", error_threshold = 10)
    return "Log file not found: #{log_file}" unless File.exist?(log_file)
    
    logs = parse_log_file(log_file)
    filtered_logs = filter_by_time(logs, time_range)
    
    analysis = {
      total_entries: filtered_logs.length,
      error_count: count_errors(filtered_logs),
      warning_count: count_warnings(filtered_logs),
      top_errors: find_top_errors(filtered_logs, 5),
      performance_stats: calculate_performance_stats(filtered_logs),
      anomalies: detect_anomalies(filtered_logs),
      recommendations: generate_recommendations(filtered_logs, error_threshold)
    }
    
    JSON.pretty_generate(analysis)
  end
  
  def extract_error_patterns(log_file, pattern_limit = 10)
    return "Log file not found: #{log_file}" unless File.exist?(log_file)
    
    errors = []
    File.foreach(log_file) do |line|
      if line.match?(/ERROR|FATAL|EXCEPTION/i)
        errors << extract_error_context(line)
      end
    end
    
    patterns = group_similar_errors(errors)
    top_patterns = patterns.sort_by { |_, count| -count }.first(pattern_limit)
    
    {
      total_errors: errors.length,
      unique_patterns: patterns.length,
      top_patterns: top_patterns.map { |pattern, count| 
        { pattern: pattern, occurrences: count, severity: assess_severity(pattern) }
      }
    }.to_json
  end
  
  def performance_report(log_file, metric = "response_time")
    logs = parse_log_file(log_file)
    performance_data = extract_performance_data(logs, metric)
    
    return "No performance data found for metric: #{metric}" if performance_data.empty?
    
    stats = calculate_detailed_stats(performance_data)
    percentiles = calculate_percentiles(performance_data)
    trends = analyze_trends(performance_data)
    
    {
      metric: metric,
      statistics: stats,
      percentiles: percentiles,
      trends: trends,
      alerts: generate_performance_alerts(stats, percentiles)
    }.to_json
  end
  
  private
  
  def parse_log_file(file_path)
    logs = []
    File.foreach(file_path) do |line|
      parsed = parse_log_line(line.strip)
      logs << parsed if parsed
    end
    logs
  end
  
  def parse_log_line(line)
    # Support multiple log formats
    formats = [
      /^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<message>.*)/,
      /^(?<level>\w+) (?<timestamp>\w{3} \d{2} \d{2}:\d{2}:\d{2}) (?<message>.*)/,
      /^\[(?<timestamp>.*?)\] (?<level>\w+): (?<message>.*)/
    ]
    
    formats.each do |format|
      match = line.match(format)
      if match
        return {
          timestamp: parse_timestamp(match[:timestamp]),
          level: match[:level].upcase,
          message: match[:message],
          raw: line
        }
      end
    end
    
    nil  # Unable to parse
  end
  
  def filter_by_time(logs, time_range)
    cutoff = case time_range
             when /(\d+)h/ then Time.now - ($1.to_i * 3600)
             when /(\d+)d/ then Time.now - ($1.to_i * 86400)
             when /(\d+)m/ then Time.now - ($1.to_i * 60)
             else Time.now - 86400  # Default: 24 hours
             end
    
    logs.select { |log| log[:timestamp] && log[:timestamp] > cutoff }
  end
  
  def count_errors(logs)
    logs.count { |log| ['ERROR', 'FATAL', 'CRITICAL'].include?(log[:level]) }
  end
  
  def count_warnings(logs)
    logs.count { |log| log[:level] == 'WARN' || log[:level] == 'WARNING' }
  end
  
  def find_top_errors(logs, limit)
    error_logs = logs.select { |log| ['ERROR', 'FATAL'].include?(log[:level]) }
    error_groups = error_logs.group_by { |log| normalize_error_message(log[:message]) }
    
    error_groups.map { |error, occurrences| 
      {
        error: error,
        count: occurrences.length,
        first_seen: occurrences.map { |o| o[:timestamp] }.min,
        last_seen: occurrences.map { |o| o[:timestamp] }.max,
        sample: occurrences.first[:raw]
      }
    }.sort_by { |e| -e[:count] }.first(limit)
  end
  
  def detect_anomalies(logs)
    anomalies = []
    
    # Detect error spikes
    hourly_errors = group_by_hour(logs.select { |l| l[:level] == 'ERROR' })
    avg_errors = hourly_errors.values.sum.to_f / hourly_errors.length
    
    hourly_errors.each do |hour, count|
      if count > avg_errors * 3  # 3x average is anomalous
        anomalies << {
          type: 'error_spike',
          hour: hour,
          count: count,
          severity: 'high'
        }
      end
    end
    
    # Detect unusual silence periods
    if hourly_errors.values.any? { |count| count == 0 }
      anomalies << {
        type: 'unusual_silence',
        description: 'Periods with zero activity detected',
        severity: 'medium'
      }
    end
    
    anomalies
  end
end
```

#### Configuration File Manager
```ruby
# ~/.aia/tools/config_manager.rb
require 'yaml'
require 'json'
require 'fileutils'

class ConfigManager < RubyLLM::Tool
  description "Manages configuration files across different formats (YAML, JSON, ENV)"
  
  def analyze_config(config_file)
    return "Config file not found: #{config_file}" unless File.exist?(config_file)
    
    format = detect_format(config_file)
    config_data = load_config(config_file, format)
    
    analysis = {
      file: config_file,
      format: format,
      structure: analyze_structure(config_data),
      security: security_analysis(config_data),
      completeness: completeness_check(config_data),
      recommendations: generate_config_recommendations(config_data, format)
    }
    
    JSON.pretty_generate(analysis)
  end
  
  def validate_config(config_file, schema_file = nil)
    return "Config file not found: #{config_file}" unless File.exist?(config_file)
    
    format = detect_format(config_file)
    config_data = load_config(config_file, format)
    
    validation_results = {
      syntax_valid: true,
      structure_issues: [],
      security_issues: [],
      recommendations: []
    }
    
    # Syntax validation
    begin
      load_config(config_file, format)
    rescue => e
      validation_results[:syntax_valid] = false
      validation_results[:structure_issues] << "Syntax error: #{e.message}"
    end
    
    # Security validation
    security_issues = find_security_issues(config_data)
    validation_results[:security_issues] = security_issues
    
    # Schema validation if provided
    if schema_file && File.exist?(schema_file)
      schema_validation = validate_against_schema(config_data, schema_file)
      validation_results[:schema_validation] = schema_validation
    end
    
    JSON.pretty_generate(validation_results)
  end
  
  def merge_configs(base_config, override_config, output_file = nil)
    base_format = detect_format(base_config)
    override_format = detect_format(override_config)
    
    base_data = load_config(base_config, base_format)
    override_data = load_config(override_config, override_format)
    
    merged_data = deep_merge(base_data, override_data)
    
    if output_file
      output_format = detect_format(output_file)
      save_config(merged_data, output_file, output_format)
      "Configuration merged and saved to: #{output_file}"
    else
      JSON.pretty_generate(merged_data)
    end
  end
  
  def extract_secrets(config_file, patterns = nil)
    content = File.read(config_file)
    
    default_patterns = [
      /password\s*[:=]\s*["']?([^"'\s]+)["']?/i,
      /api[_-]?key\s*[:=]\s*["']?([^"'\s]+)["']?/i,
      /secret\s*[:=]\s*["']?([^"'\s]+)["']?/i,
      /token\s*[:=]\s*["']?([^"'\s]+)["']?/i,
      /database_url\s*[:=]\s*["']?([^"'\s]+)["']?/i
    ]
    
    patterns ||= default_patterns
    secrets = []
    
    patterns.each do |pattern|
      content.scan(pattern) do |match|
        secrets << {
          type: detect_secret_type(pattern),
          value: mask_secret(match[0]),
          line: content.lines.find_index { |line| line.include?(match[0]) } + 1,
          severity: assess_secret_severity(match[0])
        }
      end
    end
    
    {
      file: config_file,
      secrets_found: secrets.length,
      secrets: secrets,
      recommendations: generate_secret_recommendations(secrets)
    }.to_json
  end
  
  private
  
  def detect_format(file_path)
    ext = File.extname(file_path).downcase
    case ext
    when '.yml', '.yaml' then 'yaml'
    when '.json' then 'json'
    when '.env' then 'env'
    when '.ini' then 'ini'
    else
      # Try to detect from content
      content = File.read(file_path).strip
      return 'json' if content.start_with?('{') || content.start_with?('[')
      return 'yaml' if content.match?(/^\w+:/)
      return 'env' if content.match?(/^\w+=/)
      'unknown'
    end
  end
  
  def load_config(file_path, format)
    content = File.read(file_path)
    
    case format
    when 'yaml'
      YAML.safe_load(content)
    when 'json'
      JSON.parse(content)
    when 'env'
      parse_env_file(content)
    else
      { raw_content: content }
    end
  end
  
  def parse_env_file(content)
    env_vars = {}
    content.lines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      key, value = line.split('=', 2)
      env_vars[key] = value&.gsub(/^["']|["']$/, '') if key
    end
    env_vars
  end
  
  def deep_merge(base, override)
    base.merge(override) do |key, base_val, override_val|
      if base_val.is_a?(Hash) && override_val.is_a?(Hash)
        deep_merge(base_val, override_val)
      else
        override_val
      end
    end
  end
end
```

### Development Tools

#### Code Quality Analyzer
```ruby
# ~/.aia/tools/code_quality.rb
class CodeQualityAnalyzer < RubyLLM::Tool
  description "Analyzes code quality metrics, complexity, and best practices"
  
  def analyze_codebase(directory, language = nil)
    return "Directory not found: #{directory}" unless Dir.exist?(directory)
    
    files = find_code_files(directory, language)
    return "No code files found" if files.empty?
    
    results = {
      summary: {
        total_files: files.length,
        total_lines: 0,
        languages: {}
      },
      quality_metrics: {},
      issues: [],
      recommendations: []
    }
    
    files.each do |file|
      file_analysis = analyze_file(file)
      results[:summary][:total_lines] += file_analysis[:line_count]
      
      lang = detect_language(file)
      results[:summary][:languages][lang] ||= 0
      results[:summary][:languages][lang] += 1
      
      results[:quality_metrics][file] = file_analysis
      results[:issues].concat(file_analysis[:issues])
    end
    
    results[:recommendations] = generate_recommendations(results)
    JSON.pretty_generate(results)
  end
  
  def calculate_complexity(file_path)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    content = File.read(file_path)
    language = detect_language(file_path)
    
    complexity = case language
                 when 'ruby'
                   calculate_ruby_complexity(content)
                 when 'python'
                   calculate_python_complexity(content)
                 when 'javascript'
                   calculate_js_complexity(content)
                 else
                   calculate_generic_complexity(content)
                 end
    
    {
      file: file_path,
      language: language,
      cyclomatic_complexity: complexity[:cyclomatic],
      cognitive_complexity: complexity[:cognitive],
      maintainability_index: complexity[:maintainability],
      complexity_rating: rate_complexity(complexity[:cyclomatic])
    }.to_json
  end
  
  def check_best_practices(file_path)
    return "File not found: #{file_path}" unless File.exist?(file_path)
    
    content = File.read(file_path)
    language = detect_language(file_path)
    
    violations = []
    
    case language
    when 'ruby'
      violations.concat(check_ruby_practices(content))
    when 'python'
      violations.concat(check_python_practices(content))
    when 'javascript'
      violations.concat(check_js_practices(content))
    end
    
    # Generic checks
    violations.concat(check_generic_practices(content, file_path))
    
    {
      file: file_path,
      language: language,
      violations: violations,
      score: calculate_practice_score(violations),
      recommendations: prioritize_fixes(violations)
    }.to_json
  end
  
  private
  
  def find_code_files(directory, language = nil)
    extensions = if language
                   language_extensions(language)
                 else
                   %w[.rb .py .js .java .cpp .c .go .rs .php .cs .swift .kt]
                 end
    
    Dir.glob("#{directory}/**/*").select do |file|
      File.file?(file) && extensions.include?(File.extname(file).downcase)
    end
  end
  
  def analyze_file(file_path)
    content = File.read(file_path)
    lines = content.lines
    
    {
      file: file_path,
      line_count: lines.length,
      blank_lines: lines.count(&:strip.empty?),
      comment_lines: count_comment_lines(content, detect_language(file_path)),
      complexity: calculate_complexity_metrics(content),
      issues: find_code_issues(content, file_path),
      maintainability: assess_maintainability(content)
    }
  end
  
  def calculate_ruby_complexity(content)
    # Simplified Ruby complexity calculation
    cyclomatic = 1  # Base complexity
    
    # Add complexity for control structures
    cyclomatic += content.scan(/\b(if|unless|while|until|for|case|rescue)\b/).length
    cyclomatic += content.scan(/&&|\|\|/).length
    cyclomatic += content.scan(/\?.*:/).length  # Ternary operators
    
    # Method definitions add complexity
    method_count = content.scan(/def\s+\w+/).length
    
    {
      cyclomatic: cyclomatic,
      cognitive: calculate_cognitive_complexity(content, 'ruby'),
      maintainability: calculate_maintainability_index(content, cyclomatic),
      method_count: method_count
    }
  end
  
  def check_ruby_practices(content)
    violations = []
    
    # Check for long methods (>20 lines)
    methods = content.scan(/def\s+\w+.*?end/m)
    methods.each do |method|
      if method.lines.length > 20
        violations << {
          type: 'long_method',
          severity: 'medium',
          message: 'Method exceeds 20 lines',
          line: find_line_number(content, method)
        }
      end
    end
    
    # Check for deep nesting
    max_indent = content.lines.map { |line| line.match(/^\s*/)[0].length }.max
    if max_indent > 8
      violations << {
        type: 'deep_nesting',
        severity: 'medium',
        message: 'Excessive nesting detected',
        max_depth: max_indent / 2
      }
    end
    
    # Check for missing documentation
    if !content.match?(/^#.*/) && content.match?(/class\s+\w+/)
      violations << {
        type: 'missing_documentation',
        severity: 'low',
        message: 'Class lacks documentation'
      }
    end
    
    violations
  end
  
  def generate_recommendations(analysis_results)
    recommendations = []
    
    # File count recommendations
    if analysis_results[:summary][:total_files] > 100
      recommendations << "Consider organizing large codebase into modules or packages"
    end
    
    # Language diversity
    if analysis_results[:summary][:languages].keys.length > 3
      recommendations << "High language diversity may increase maintenance complexity"
    end
    
    # Quality-based recommendations
    high_complexity_files = analysis_results[:quality_metrics].select do |file, metrics|
      metrics[:complexity][:cyclomatic] > 10
    end
    
    if high_complexity_files.any?
      recommendations << "#{high_complexity_files.length} files have high complexity - consider refactoring"
    end
    
    recommendations
  end
end
```

## MCP Integration Examples

### GitHub Repository Analyzer MCP
```python
# github_analyzer_mcp.py
import asyncio
import os
from mcp.server import Server
from mcp.types import Resource, Tool, TextContent
import aiohttp
import json
from datetime import datetime, timedelta

server = Server("github-analyzer", "1.0.0")

class GitHubAnalyzer:
    def __init__(self, token):
        self.token = token
        self.headers = {
            'Authorization': f'token {token}',
            'Accept': 'application/vnd.github.v3+json'
        }
    
    async def analyze_repository(self, owner, repo):
        """Comprehensive repository analysis"""
        async with aiohttp.ClientSession() as session:
            # Get basic repo info
            repo_info = await self._get_repo_info(session, owner, repo)
            
            # Get commit activity
            commits = await self._get_commit_activity(session, owner, repo)
            
            # Get issues and PRs
            issues = await self._get_issues_analysis(session, owner, repo)
            prs = await self._get_pr_analysis(session, owner, repo)
            
            # Get contributors
            contributors = await self._get_contributors_analysis(session, owner, repo)
            
            # Get code quality indicators
            code_quality = await self._analyze_code_quality(session, owner, repo)
            
            return {
                'repository': repo_info,
                'activity': commits,
                'issues': issues,
                'pull_requests': prs,
                'contributors': contributors,
                'code_quality': code_quality,
                'health_score': self._calculate_health_score(repo_info, commits, issues, prs),
                'recommendations': self._generate_recommendations(repo_info, commits, issues, prs)
            }
    
    async def _get_repo_info(self, session, owner, repo):
        url = f'https://api.github.com/repos/{owner}/{repo}'
        async with session.get(url, headers=self.headers) as response:
            if response.status == 200:
                data = await response.json()
                return {
                    'name': data['name'],
                    'description': data.get('description', ''),
                    'language': data.get('language', 'Unknown'),
                    'stars': data['stargazers_count'],
                    'forks': data['forks_count'],
                    'open_issues': data['open_issues_count'],
                    'created_at': data['created_at'],
                    'updated_at': data['updated_at'],
                    'size': data['size'],
                    'license': data.get('license', {}).get('name', 'None') if data.get('license') else 'None'
                }
            return {}
    
    async def _get_commit_activity(self, session, owner, repo):
        # Get commits from last 30 days
        since = (datetime.now() - timedelta(days=30)).isoformat()
        url = f'https://api.github.com/repos/{owner}/{repo}/commits'
        params = {'since': since, 'per_page': 100}
        
        async with session.get(url, headers=self.headers, params=params) as response:
            if response.status == 200:
                commits = await response.json()
                
                # Analyze commit patterns
                daily_commits = {}
                authors = {}
                
                for commit in commits:
                    date = commit['commit']['author']['date'][:10]
                    author = commit['commit']['author']['name']
                    
                    daily_commits[date] = daily_commits.get(date, 0) + 1
                    authors[author] = authors.get(author, 0) + 1
                
                return {
                    'total_commits_30d': len(commits),
                    'daily_average': len(commits) / 30,
                    'most_active_day': max(daily_commits.items(), key=lambda x: x[1]) if daily_commits else None,
                    'active_contributors': len(authors),
                    'top_contributor': max(authors.items(), key=lambda x: x[1]) if authors else None
                }
        return {}
    
    def _calculate_health_score(self, repo_info, commits, issues, prs):
        """Calculate overall repository health score (0-100)"""
        score = 0
        
        # Activity score (30 points)
        if commits.get('total_commits_30d', 0) > 10:
            score += 30
        elif commits.get('total_commits_30d', 0) > 5:
            score += 20
        elif commits.get('total_commits_30d', 0) > 0:
            score += 10
        
        # Documentation score (20 points)
        if repo_info.get('description'):
            score += 10
        # Additional checks would go here (README, wiki, etc.)
        
        # Community score (25 points)
        if repo_info.get('stars', 0) > 100:
            score += 15
        elif repo_info.get('stars', 0) > 10:
            score += 10
        elif repo_info.get('stars', 0) > 0:
            score += 5
        
        if issues.get('response_time_avg', float('inf')) < 7:  # Average response < 7 days
            score += 10
        
        # Maintenance score (25 points)
        last_update = datetime.fromisoformat(repo_info.get('updated_at', '1970-01-01T00:00:00Z').replace('Z', '+00:00'))
        days_since_update = (datetime.now(last_update.tzinfo) - last_update).days
        
        if days_since_update < 30:
            score += 25
        elif days_since_update < 90:
            score += 15
        elif days_since_update < 365:
            score += 5
        
        return min(score, 100)

@server.list_tools()
async def list_tools():
    return [
        Tool(
            name="analyze_repository",
            description="Analyze GitHub repository health, activity, and metrics",
            inputSchema={
                "type": "object",
                "properties": {
                    "owner": {"type": "string", "description": "Repository owner"},
                    "repo": {"type": "string", "description": "Repository name"}
                },
                "required": ["owner", "repo"]
            }
        ),
        Tool(
            name="compare_repositories",
            description="Compare multiple repositories across key metrics",
            inputSchema={
                "type": "object",
                "properties": {
                    "repositories": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "owner": {"type": "string"},
                                "repo": {"type": "string"}
                            }
                        }
                    }
                }
            }
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    token = os.getenv('GITHUB_TOKEN')
    if not token:
        return TextContent(type="text", text="Error: GITHUB_TOKEN environment variable not set")
    
    analyzer = GitHubAnalyzer(token)
    
    if name == "analyze_repository":
        result = await analyzer.analyze_repository(arguments["owner"], arguments["repo"])
        return TextContent(type="text", text=json.dumps(result, indent=2))
    
    elif name == "compare_repositories":
        comparisons = []
        for repo_data in arguments["repositories"]:
            analysis = await analyzer.analyze_repository(repo_data["owner"], repo_data["repo"])
            comparisons.append({
                "repository": f"{repo_data['owner']}/{repo_data['repo']}",
                "analysis": analysis
            })
        
        return TextContent(type="text", text=json.dumps(comparisons, indent=2))
    
    return TextContent(type="text", text=f"Unknown tool: {name}")

if __name__ == "__main__":
    asyncio.run(server.run())
```

### Database Schema Analyzer MCP
```python
# database_schema_mcp.py
import asyncio
import os
from mcp.server import Server
from mcp.types import Resource, Tool, TextContent
import asyncpg
import json
from datetime import datetime

server = Server("database-analyzer", "1.0.0")

class DatabaseAnalyzer:
    def __init__(self, connection_string):
        self.connection_string = connection_string
    
    async def analyze_schema(self, schema_name='public'):
        """Comprehensive database schema analysis"""
        conn = await asyncpg.connect(self.connection_string)
        
        try:
            # Get all tables
            tables = await self._get_tables(conn, schema_name)
            
            # Analyze each table
            table_analyses = {}
            for table in tables:
                table_analyses[table['table_name']] = await self._analyze_table(conn, schema_name, table['table_name'])
            
            # Get relationships
            relationships = await self._get_relationships(conn, schema_name)
            
            # Get indexes
            indexes = await self._get_indexes(conn, schema_name)
            
            # Performance analysis
            performance = await self._analyze_performance(conn, schema_name)
            
            return {
                'schema': schema_name,
                'tables': table_analyses,
                'relationships': relationships,
                'indexes': indexes,
                'performance': performance,
                'recommendations': self._generate_schema_recommendations(table_analyses, relationships, indexes)
            }
            
        finally:
            await conn.close()
    
    async def _get_tables(self, conn, schema_name):
        query = """
        SELECT table_name, 
               pg_total_relation_size(quote_ident(table_name)) as size_bytes
        FROM information_schema.tables 
        WHERE table_schema = $1 AND table_type = 'BASE TABLE'
        ORDER BY table_name
        """
        return await conn.fetch(query, schema_name)
    
    async def _analyze_table(self, conn, schema_name, table_name):
        # Get columns
        columns_query = """
        SELECT column_name, data_type, is_nullable, column_default,
               character_maximum_length, numeric_precision, numeric_scale
        FROM information_schema.columns 
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position
        """
        columns = await conn.fetch(columns_query, schema_name, table_name)
        
        # Get row count
        try:
            row_count = await conn.fetchval(f'SELECT COUNT(*) FROM {schema_name}.{table_name}')
        except:
            row_count = 0
        
        # Get primary keys
        pk_query = """
        SELECT column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_schema = $1 AND tc.table_name = $2 AND tc.constraint_type = 'PRIMARY KEY'
        """
        primary_keys = await conn.fetch(pk_query, schema_name, table_name)
        
        return {
            'columns': [dict(col) for col in columns],
            'row_count': row_count,
            'primary_keys': [pk['column_name'] for pk in primary_keys],
            'data_quality': await self._assess_data_quality(conn, schema_name, table_name, columns)
        }
    
    async def _assess_data_quality(self, conn, schema_name, table_name, columns):
        quality_issues = []
        
        for column in columns:
            col_name = column['column_name']
            
            # Check for null values in non-nullable columns
            if column['is_nullable'] == 'NO':
                null_count = await conn.fetchval(
                    f'SELECT COUNT(*) FROM {schema_name}.{table_name} WHERE {col_name} IS NULL'
                )
                if null_count > 0:
                    quality_issues.append({
                        'type': 'unexpected_nulls',
                        'column': col_name,
                        'count': null_count
                    })
            
            # Check for duplicate values in potential key columns
            if 'id' in col_name.lower() or col_name.lower().endswith('_key'):
                duplicate_query = f"""
                SELECT COUNT(*) FROM (
                    SELECT {col_name}, COUNT(*) as cnt 
                    FROM {schema_name}.{table_name} 
                    WHERE {col_name} IS NOT NULL
                    GROUP BY {col_name} 
                    HAVING COUNT(*) > 1
                ) duplicates
                """
                duplicate_count = await conn.fetchval(duplicate_query)
                if duplicate_count > 0:
                    quality_issues.append({
                        'type': 'duplicates',
                        'column': col_name,
                        'duplicate_groups': duplicate_count
                    })
        
        return quality_issues

@server.list_tools()
async def list_tools():
    return [
        Tool(
            name="analyze_schema",
            description="Analyze database schema structure, relationships, and quality",
            inputSchema={
                "type": "object",
                "properties": {
                    "schema_name": {"type": "string", "default": "public"}
                }
            }
        ),
        Tool(
            name="performance_analysis",
            description="Analyze database performance metrics and slow queries",
            inputSchema={
                "type": "object",
                "properties": {
                    "time_period": {"type": "string", "default": "1h"}
                }
            }
        ),
        Tool(
            name="suggest_indexes",
            description="Suggest database indexes based on query patterns",
            inputSchema={
                "type": "object",
                "properties": {
                    "table_name": {"type": "string"},
                    "schema_name": {"type": "string", "default": "public"}
                }
            }
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict):
    connection_string = os.getenv('DATABASE_URL')
    if not connection_string:
        return TextContent(type="text", text="Error: DATABASE_URL environment variable not set")
    
    analyzer = DatabaseAnalyzer(connection_string)
    
    try:
        if name == "analyze_schema":
            schema_name = arguments.get("schema_name", "public")
            result = await analyzer.analyze_schema(schema_name)
            return TextContent(type="text", text=json.dumps(result, indent=2, default=str))
        
        elif name == "performance_analysis":
            # Implementation for performance analysis
            return TextContent(type="text", text="Performance analysis not yet implemented")
        
        elif name == "suggest_indexes":
            # Implementation for index suggestions
            return TextContent(type="text", text="Index suggestions not yet implemented")
            
    except Exception as e:
        return TextContent(type="text", text=f"Error: {str(e)}")
    
    return TextContent(type="text", text=f"Unknown tool: {name}")

if __name__ == "__main__":
    asyncio.run(server.run())
```

## Integration Workflows

### Full-Stack Application Analysis
```markdown
# ~/.prompts/full_stack_analysis.md
/tools file_analyzer.rb,code_quality.rb,config_manager.rb
/mcp github,filesystem,database

# Full-Stack Application Analysis

Application: <%= app_name %>
Repository: <%= repo_url %>
Environment: <%= environment %>

## Phase 1: Repository Analysis
Using GitHub MCP client:
1. Repository health and activity metrics
2. Issue and PR management effectiveness
3. Contributor activity and code review patterns
4. Release and deployment frequency

## Phase 2: Codebase Quality Assessment
Using code analysis tools:
1. Code quality metrics across all languages
2. Complexity analysis and refactoring opportunities
3. Security vulnerability scanning
4. Test coverage and quality assessment

## Phase 3: Configuration Management
Using configuration tools:
1. Configuration file analysis and security
2. Environment-specific settings validation
3. Secret management assessment
4. Deployment configuration review

## Phase 4: Database Architecture
Using database MCP client:
1. Schema design and normalization analysis
2. Index optimization opportunities
3. Query performance analysis
4. Data integrity and quality assessment

## Phase 5: File System Organization
Using filesystem MCP client:
1. Project structure and organization
2. Build and deployment artifacts
3. Documentation completeness
4. Security file analysis

## Integration Report
Cross-analyze findings to provide:
- Overall application health score
- Security risk assessment
- Performance optimization priorities
- Maintenance burden analysis
- Deployment readiness checklist
- Prioritized improvement recommendations

Generate comprehensive analysis with actionable insights for each identified area.
```

### DevOps Pipeline Assessment
```markdown
# ~/.prompts/devops_pipeline_analysis.md
/tools log_analyzer.rb,config_manager.rb
/mcp github,filesystem

# DevOps Pipeline Analysis

Project: <%= project_name %>
Pipeline type: <%= pipeline_type %>

## CI/CD Configuration Analysis
Using configuration tools:
1. Build configuration validation (GitHub Actions, Jenkins, etc.)
2. Deployment script analysis and security
3. Environment configuration consistency
4. Secret management in CI/CD

## Pipeline Performance Analysis
Using log analysis tools:
1. Build time trends and optimization opportunities
2. Failure rate analysis and common failure patterns
3. Deployment frequency and success rates
4. Resource utilization during builds

## Repository Integration Assessment
Using GitHub MCP:
1. Branch protection rules and policies
2. Automated testing integration
3. Code review automation
4. Release management processes

## Infrastructure as Code Review
Using filesystem MCP:
1. Terraform/CloudFormation template analysis
2. Docker configuration optimization
3. Kubernetes manifest validation
4. Infrastructure security assessment

## Recommendations
Generate prioritized recommendations for:
- Pipeline speed improvements
- Security enhancements
- Reliability improvements
- Cost optimization opportunities
- Automation enhancement suggestions

Provide implementation timeline and impact assessment for each recommendation.
```

## Advanced Integration Patterns

### Multi-Environment Consistency Checker
```ruby
# ~/.aia/tools/environment_checker.rb
class EnvironmentChecker < RubyLLM::Tool
  description "Compares configurations and deployments across multiple environments"
  
  def compare_environments(environments_config)
    environments = JSON.parse(environments_config)
    comparison_results = {}
    
    environments.each do |env_name, config|
      comparison_results[env_name] = analyze_environment(env_name, config)
    end
    
    # Cross-environment analysis
    consistency_report = analyze_consistency(comparison_results)
    drift_analysis = detect_configuration_drift(comparison_results)
    
    {
      environments: comparison_results,
      consistency: consistency_report,
      drift: drift_analysis,
      recommendations: generate_consistency_recommendations(consistency_report, drift_analysis)
    }.to_json
  end
  
  def validate_deployment_readiness(environment, checklist_items = nil)
    default_checklist = [
      'configuration_files_present',
      'secrets_configured',
      'database_migrations_applied',
      'dependencies_installed',
      'health_checks_passing',
      'monitoring_configured',
      'backup_procedures_verified'
    ]
    
    checklist = checklist_items || default_checklist
    results = {}
    
    checklist.each do |item|
      results[item] = check_deployment_item(environment, item)
    end
    
    readiness_score = calculate_readiness_score(results)
    blocking_issues = identify_blocking_issues(results)
    
    {
      environment: environment,
      readiness_score: readiness_score,
      checklist_results: results,
      blocking_issues: blocking_issues,
      deployment_recommended: blocking_issues.empty? && readiness_score > 80
    }.to_json
  end
  
  private
  
  def analyze_environment(env_name, config)
    # Analyze single environment
    {
      name: env_name,
      config_files: find_config_files(config['path']),
      services: check_services(config['services']),
      database: check_database_connection(config['database']),
      monitoring: check_monitoring(config['monitoring']),
      last_deployment: get_last_deployment_info(env_name)
    }
  end
  
  def analyze_consistency(environments)
    consistency_issues = []
    
    # Compare configuration structures
    config_structures = environments.map { |env, data| data[:config_files] }
    unless config_structures.all? { |structure| structure.keys.sort == config_structures.first.keys.sort }
      consistency_issues << "Configuration file structures differ between environments"
    end
    
    # Compare service configurations
    service_configs = environments.map { |env, data| data[:services] }
    unless service_configs.all? { |config| config.keys.sort == service_configs.first.keys.sort }
      consistency_issues << "Service configurations differ between environments"
    end
    
    {
      consistent: consistency_issues.empty?,
      issues: consistency_issues,
      score: calculate_consistency_score(consistency_issues)
    }
  end
end
```

## Related Documentation

- [Tools Integration](guides/tools.md) - Detailed tool development guide
- [MCP Integration](mcp-integration.md) - MCP client development and usage
- [Advanced Prompting](advanced-prompting.md) - Complex integration patterns
- [Configuration](configuration.md) - Tool and MCP configuration
- [Examples Directory](examples/index.md) - Additional examples and templates

---

These examples demonstrate the power of combining RubyLLM tools with MCP clients to create sophisticated analysis and automation workflows. Use them as templates and inspiration for building your own integrated solutions!