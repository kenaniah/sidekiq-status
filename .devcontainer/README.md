# Sidekiq Status Devcontainer

This devcontainer provides a complete development environment for the sidekiq-status gem.

## What's Included

- **Ruby 3.4**: The same Ruby version used in the project's Dockerfile
- **Redis 7.4.0**: Required for Sidekiq job processing and testing
- **VS Code Extensions**:
  - Ruby LSP for language support
  - Endwise for Ruby code completion
  - Docker support
  - YAML and JSON support
  - Code spell checker

## Getting Started

1. Make sure you have VS Code with the Dev Containers extension installed
2. Open this project in VS Code
3. When prompted, click "Reopen in Container" or use the command palette: `Dev Containers: Reopen in Container`
4. The container will build and install all dependencies automatically

## Development Workflow

Once the container is running:

```bash
# Run tests
bundle exec rake

# Run specific tests
bundle exec rspec spec/lib/sidekiq-status_spec.rb

# Start an interactive Ruby session
bundle exec irb

# Run tests with different Sidekiq versions (using Appraisal)
bundle exec appraisal sidekiq-6.x rspec
bundle exec appraisal sidekiq-7.x rspec
```

## Services

- **Redis**: Available on port 6379 (forwarded to host)
- **Application**: Ruby environment with all gems installed

## Environment Variables

- `REDIS_URL`: Automatically set to `redis://redis:6379` for testing

## Debugging

The devcontainer includes debugging support. You can set breakpoints in VS Code and use the Ruby debugger.

## Customization

You can modify the devcontainer configuration in `.devcontainer/` to add additional tools or change settings as needed.
