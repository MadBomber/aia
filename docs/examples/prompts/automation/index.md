# Automation Prompts

Collection of prompts for system administration, process automation, and workflow management.

## Available Prompts

### System Administration
- **system_health.txt** - System health monitoring and analysis
- **log_analysis.txt** - Log file analysis and insights
- **performance_monitoring.txt** - System performance analysis
- **security_audit.txt** - Security assessment and audit

### Deployment and DevOps
- **deployment_checklist.txt** - Deployment readiness assessment
- **ci_cd_analysis.txt** - CI/CD pipeline analysis
- **infrastructure_review.txt** - Infrastructure assessment
- **rollback_procedures.txt** - Rollback planning and procedures

### Process Automation
- **workflow_optimization.txt** - Process optimization suggestions
- **task_automation.txt** - Task automation recommendations
- **monitoring_setup.txt** - Monitoring and alerting setup
- **maintenance_scheduler.txt** - Maintenance task scheduling

### Configuration Management
- **config_validation.txt** - Configuration file validation
- **environment_sync.txt** - Environment synchronization
- **dependency_check.txt** - Dependency analysis and management
- **version_management.txt** - Version control and management

### Incident Response
- **incident_analysis.txt** - Incident investigation and analysis
- **root_cause_analysis.txt** - Root cause identification
- **recovery_procedures.txt** - Recovery planning and execution
- **post_mortem.txt** - Post-incident analysis and learning

## Usage Examples

```bash
# Analyze system health
aia system_health --logs /var/log/ --timeframe "24h"

# Validate deployment readiness
aia deployment_checklist --environment production --service api

# Perform security audit
aia security_audit --scope "web_application" --depth comprehensive
```

## Automation Workflows

### Deployment Pipeline
1. **pre_deployment.txt** - Pre-deployment checks
2. **deployment_execution.txt** - Deployment process
3. **post_deployment.txt** - Post-deployment validation
4. **rollback_if_needed.txt** - Conditional rollback
5. **deployment_report.txt** - Deployment summary

### Monitoring Setup
1. **baseline_establishment.txt** - Establish performance baselines
2. **alert_configuration.txt** - Configure monitoring alerts
3. **dashboard_creation.txt** - Create monitoring dashboards
4. **escalation_procedures.txt** - Define escalation paths
5. **monitoring_validation.txt** - Validate monitoring effectiveness

### Incident Response
1. **incident_detection.txt** - Initial incident assessment
2. **impact_analysis.txt** - Assess incident impact
3. **mitigation_actions.txt** - Define mitigation steps
4. **communication_plan.txt** - Stakeholder communication
5. **resolution_verification.txt** - Verify resolution

## Integration Points

### Shell Integration
```markdown
//shell systemctl status nginx
//shell df -h
//shell top -b -n 1 | head -20
```

### Tool Integration
```bash
# Use with system monitoring tools
aia --tools system_monitor.rb system_health

# Combine with log analysis tools
aia --tools log_analyzer.rb incident_analysis /var/log/app.log
```

### MCP Integration
```markdown
//mcp filesystem,monitoring
```

## Customization Parameters

- **Environment** - target environment (dev, staging, prod)
- **Service** - specific service or application
- **Timeframe** - analysis time window
- **Depth** - analysis depth level
- **Scope** - analysis scope and boundaries

## Related

- [Development Prompts](../development/index.md) - Development automation
- [Analysis Prompts](../analysis/index.md) - System analysis
- [MCP Examples](../../mcp/index.md) - External system integration