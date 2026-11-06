<!-- Plan item 3976. One topic per pull request; small is better. -->

## What

<!-- What changes for the player or for operations, in a few lines. Plan item numbers if any. -->

## Why

## Tests

<!-- Which tests were added or changed. New behaviour needs a test (GUT under tests/, SQL under tools/online/sql_test/). -->

## Checklist

- [ ] One topic only
- [ ] Tests added or updated, all CI checks green (GUT, SQL, IP check, release check)
- [ ] `tools/ip_check.sh` passes, also for commit messages and the title
- [ ] New player texts are in `tools/i18n/de_*.py`, new art and sound in `docs/ASSET_LOG.md`
- [ ] `SAVE_VERSION` raised only with a fixture and a migration test
- [ ] Privacy texts and `docs/legal/VVT.md` updated if data or periods change
