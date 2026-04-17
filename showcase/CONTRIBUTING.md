# Contributing to HomeGuardian

Thank you for your interest in contributing to HomeGuardian! This document provides guidelines and instructions for contributing to this open-source project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to foster an open and welcoming environment.

## Getting Started

### Prerequisites
- Basic understanding of shell scripting (Bash)
- Familiarity with system administration concepts
- Git version control
- JSON data format

### Development Environment Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/homeguardian.git
   cd homeguardian
   ```
3. **Set up upstream remote**:
   ```bash
   git remote add upstream https://github.com/original-owner/homeguardian.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```

## Development Workflow

### 1. Understanding the Architecture

Before contributing, familiarize yourself with:
- The [ARCHITECTURE.md](ARCHITECTURE.md) document
- Existing monitoring and repair modules
- Communication protocols between agents
- Safety protocols and quality gates

### 2. Making Changes

#### For Monitoring Modules
- Follow the pattern in existing modules (`cpu_monitor.sh`, `memory_monitor.sh`)
- Use the provided helper functions in `monitoring/scripts/helpers.sh`
- Output metrics in JSON format
- Include comprehensive error handling
- Add configuration options to `thresholds.conf`

#### For Repair Modules
- Implement all safety protocols (pre-validation, rollback, post-verification)
- Follow the template in existing repair modules
- Log all actions with timestamps and outcomes
- Include cleanup procedures
- Test rollback functionality

#### For Configuration Changes
- Maintain backward compatibility
- Document new configuration options
- Provide sensible defaults
- Include validation in scripts

### 3. Testing Your Changes

#### Unit Testing
```bash
# Test a monitoring module
./monitoring/modules/cpu_monitor.sh test

# Test a repair module  
./repair/modules/restart_procedures.sh test

# Test the orchestrator
./monitoring/scripts/health_check.sh test
./repair/scripts/repair_orchestrator.sh test
```

#### Integration Testing
```bash
# Test full workflow
./test_monitoring.sh

# Test alert → repair flow
echo '{"test": "alert"}' > monitoring/data/repair_requests/test_alert.json
./repair/scripts/repair_orchestrator.sh check
```

#### Safety Testing
```bash
# Test rollback functionality
./repair/modules/rollback_plans.sh --test

# Test error handling
./monitoring/scripts/health_check.sh single --simulate-errors
```

### 4. Documentation

#### Code Documentation
- Add comments for complex logic
- Document function parameters and return values
- Include usage examples in comments
- Update README.md if adding new features

#### User Documentation
- Update [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) if adding new functionality
- Document configuration changes
- Add troubleshooting tips if applicable

### 5. Commit Guidelines

#### Commit Message Format
```
type(scope): description

[optional body]

[optional footer]
```

#### Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

#### Examples:
```
feat(monitoring): add GPU monitoring module

- Add nvidia-smi integration
- Configure GPU temperature thresholds
- Add to health check summary

Closes #123
```

```
fix(repair): handle service restart timeouts

- Increase timeout from 30s to 60s
- Add progress indicators
- Improve error messages

Fixes #456
```

### 6. Pull Request Process

1. **Update your fork** with latest changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests** to ensure nothing is broken:
   ```bash
   ./test_monitoring.sh
   ```

3. **Ensure code quality**:
   ```bash
   # Check shell script syntax
   find . -name "*.sh" -exec shellcheck {} \;
   
   # Check JSON syntax
   find . -name "*.json" -exec jq . {} > /dev/null \;
   ```

4. **Create Pull Request**:
   - Use descriptive title and description
   - Reference related issues
   - Include test results
   - Add screenshots if UI changes

5. **Address review comments**:
   - Make requested changes
   - Re-run tests
   - Update PR description if needed

## Contribution Areas

### High Priority
1. **New Monitoring Modules**
   - Docker container health
   - Database performance metrics
   - SSL certificate expiration
   - Backup completion status

2. **Enhanced Repair Modules**
   - Automated backup before critical repairs
   - Dependency-aware service restart
   - Configuration file validation
   - Security patch application

3. **Integration Features**
   - Prometheus metrics exporter
   - Grafana dashboard templates
   - Slack/Teams webhook integration
   - Email alert notifications

### Medium Priority
1. **Quality Improvements**
   - Additional test coverage
   - Performance optimizations
   - Better error messages
   - Enhanced logging

2. **Documentation**
   - Video tutorials
   - Troubleshooting guide
   - API documentation
   - Deployment guides

3. **User Experience**
   - Interactive configuration wizard
   - Web-based dashboard
   - Mobile app interface
   - Command-line autocomplete

### Low Priority
1. **Experimental Features**
   - Machine learning anomaly detection
   - Predictive maintenance
   - Natural language interface
   - Multi-server coordination

## Quality Standards

### Code Quality
- **Shell Scripts**: Pass shellcheck with no errors
- **JSON Files**: Valid JSON syntax
- **Documentation**: Clear, concise, and accurate
- **Error Handling**: Comprehensive and informative

### Safety Standards
- **Pre-validation**: All repairs validate system state first
- **Rollback**: Every repair has corresponding rollback plan
- **Isolation**: One change at a time principle
- **Verification**: Post-repair validation required

### Performance Standards
- **Efficiency**: Minimal system resource usage
- **Speed**: Quick detection and repair
- **Scalability**: Handle increasing load gracefully
- **Reliability**: High uptime and consistency

## Review Process

### What Reviewers Look For
1. **Functionality**: Does it work as intended?
2. **Safety**: Are all protocols followed?
3. **Quality**: Does it meet quality standards?
4. **Documentation**: Is it well-documented?
5. **Testing**: Are tests comprehensive?

### Review Timeline
- Initial review within 48 hours
- Feedback and requested changes
- Final approval after all issues addressed
- Merge after successful CI checks

## Community Guidelines

### Asking for Help
1. **Search existing issues** before creating new ones
2. **Use the issue template** for bug reports
3. **Provide detailed information**:
   - System information
   - Error messages
   - Steps to reproduce
   - Expected vs actual behavior

### Providing Help
1. **Be respectful and patient**
2. **Provide clear explanations**
3. **Include code examples** when possible
4. **Follow up** if issue isn't resolved

### Recognition
- Contributors will be listed in CONTRIBUTORS.md
- Significant contributions may receive commit access
- Community feedback helps shape project direction

## Licensing

By contributing to HomeGuardian, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).

## Getting Help

- **Documentation**: Check [README.md](README.md) and [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)
- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **Community**: Join our community chat (link in README)

## Thank You!

Your contributions help make HomeGuardian better for everyone. Whether you're fixing a bug, adding a feature, or improving documentation, your work is appreciated.

Happy contributing! 🚀