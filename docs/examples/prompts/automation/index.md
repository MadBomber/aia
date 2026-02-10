# Automation Prompts

Collection of prompts for system administration, process automation, and workflow management.

## Available Prompts

### System Administration
- **system_health.md** - System health monitoring and analysis
- **log_analysis.md** - Log file analysis and insights
- **performance_monitoring.md** - System performance analysis
- **security_audit.md** - Security assessment and audit

### Deployment and DevOps
- **deployment_checklist.md** - Deployment readiness assessment
- **ci_cd_analysis.md** - CI/CD pipeline analysis
- **infrastructure_review.md** - Infrastructure assessment
- **rollback_procedures.md** - Rollback planning and procedures

### Process Automation
- **workflow_optimization.md** - Process optimization suggestions
- **task_automation.md** - Task automation recommendations
- **monitoring_setup.md** - Monitoring and alerting setup
- **maintenance_scheduler.md** - Maintenance task scheduling

### Configuration Management
- **config_validation.md** - Configuration file validation
- **environment_sync.md** - Environment synchronization
- **dependency_check.md** - Dependency analysis and management
- **version_management.md** - Version control and management

### Incident Response
- **incident_analysis.md** - Incident investigation and analysis
- **root_cause_analysis.md** - Root cause identification
- **recovery_procedures.md** - Recovery planning and execution
- **post_mortem.md** - Post-incident analysis and learning

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
1. **pre_deployment.md** - Pre-deployment checks
2. **deployment_execution.md** - Deployment process
3. **post_deployment.md** - Post-deployment validation
4. **rollback_if_needed.md** - Conditional rollback
5. **deployment_report.md** - Deployment summary

### Monitoring Setup
1. **baseline_establishment.md** - Establish performance baselines
2. **alert_configuration.md** - Configure monitoring alerts
3. **dashboard_creation.md** - Create monitoring dashboards
4. **escalation_procedures.md** - Define escalation paths
5. **monitoring_validation.md** - Validate monitoring effectiveness

### Incident Response
1. **incident_detection.md** - Initial incident assessment
2. **impact_analysis.md** - Assess incident impact
3. **mitigation_actions.md** - Define mitigation steps
4. **communication_plan.md** - Stakeholder communication
5. **resolution_verification.md** - Verify resolution

## Integration Points

### Shell Integration
```markdown
/shell systemctl status nginx
/shell df -h
/shell top -b -n 1 | head -20
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
/mcp filesystem,monitoring
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