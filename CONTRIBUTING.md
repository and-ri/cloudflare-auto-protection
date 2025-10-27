# Contributing to Cloudflare Under Attack Mode Automation

First off, thank you for considering contributing to this project! 🎉

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- Use a clear and descriptive title
- Describe the exact steps to reproduce the problem
- Provide specific examples and log outputs
- Describe the behavior you observed and what you expected
- Include your environment details (OS, bash version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- Use a clear and descriptive title
- Provide a detailed description of the suggested enhancement
- Explain why this enhancement would be useful
- List any alternative solutions you've considered

### Pull Requests

1. Fork the repository
2. Create a new branch for your feature (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit your changes with clear commit messages
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

#### Pull Request Guidelines

- Follow the existing code style
- Add comments for complex logic
- Update documentation (README.md) if needed
- Test the script in different scenarios
- Ensure backward compatibility when possible

### Code Style

- Use meaningful variable names
- Add comments for non-obvious logic
- Keep functions focused and single-purpose
- Use consistent indentation (4 spaces)
- Follow bash best practices

### Testing

Before submitting a PR, please test:

1. Script runs without errors
2. CPU monitoring works correctly
3. Cloudflare API calls succeed
4. Telegram notifications work (if enabled)
5. State files are created and managed properly
6. Edge cases (high CPU, low CPU, API failures)

### Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests when relevant

Example:
```
Add support for custom security levels

- Allow users to specify custom security level
- Update documentation with examples
- Add validation for security level values

Fixes #123
```

## Development Setup

1. Clone your fork:
```bash
git clone https://github.com/your-username/cf-under-attack-automaticly.git
cd cf-under-attack-automaticly
```

2. Create a test configuration:
```bash
cp cf_protection.sh cf_protection_test.sh
# Edit with test credentials
```

3. Make the script executable:
```bash
chmod +x cf_protection_test.sh
```

4. Test your changes:
```bash
./cf_protection_test.sh --test-telegram
./cf_protection_test.sh
```

## Questions?

Feel free to create an issue with the "question" label if you need help or clarification.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for your contribution! 🙏
