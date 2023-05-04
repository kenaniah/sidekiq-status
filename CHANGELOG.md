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
