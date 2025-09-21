**Version 4.0.0**
 - Adds support for Ruby 3.3 and 3.4
 - Adds support for Sidekiq 8.x
 - Drops support for Sidekiq 6.x
 - Drops support for Ruby versions that are now end-of-life (Ruby 2.7.x - Ruby 3.1.x)
 - **BREAKING CHANGE**: Introduces breaking changes in job timestamp storage in Redis
 - **BREAKING CHANGE**: Renames `#working_at` to `#updated_at`
 - Major UI improvements with enhanced progress bars and better web interface styling
 - Adds fallback routes for retry and delete buttons
 - Adds a devcontainer to simplify development
 - Improved elapsed time and ETA calculations

**Version 3.0.3**
 - Fixes a Sidekiq warning about the deprecated `hmset` redis command (https://github.com/kenaniah/sidekiq-status/pull/37)

**Version 3.0.2**
 - Avoids setting statuses for non-status jobs when an exception is thrown (https://github.com/kenaniah/sidekiq-status/pull/32)

**Version 3.0.1**
 - Adds elapsed time and ETA to the job status page (https://github.com/kenaniah/sidekiq-status/pull/13)

**Version 3.0.0**
 - Drops support for Sidekiq 5.x
 - Adds support for Sidekiq 7.x
 - Migrates from Travis CI to GitHub Actions

**Version 2.1.3**
 - Fixes redis deprecation warnings (https://github.com/kenaniah/sidekiq-status/issues/11)

**Version 2.1.2**
 - Casts values to strings when HTML-encoding

**Version 2.1.1**
 - Ensures parameter outputs are properly HTML-encoded

**Version 2.1.0**
 - Adds support for Sidekiq 6.2.2+ (https://github.com/mperham/sidekiq/issues/4955)

**Version 2.0.2**
 - Fixes for dark mode theme

**Version 2.0.1**
 - Adds support for dark mode to the job status page

**Version 2.0.0**
 - Adds support for Ruby 2.7, 3.0
 - Adds support for Sidekiq 6.x
 - Removes support for Ruby 2.3, 2.4, 2.5
 - Removes support for Sidekiq 3.x, 4.x

**Versions 1.1.4 and prior**

See https://github.com/utgarda/sidekiq-status/blob/master/CHANGELOG.md.
