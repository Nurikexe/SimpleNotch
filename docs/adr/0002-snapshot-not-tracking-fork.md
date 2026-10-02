# Import a snapshot of boring.notch into a fresh repo; do not track upstream

SimpleNotch starts as a fresh Git repository containing a one-time snapshot of boring.notch (the commit is recorded in the initial import commit message), rather than a GitHub fork that keeps upstream history or is periodically merged. We rename, remove features and restructure the main view heavily, so upstream merges would be constant conflicts; a clean history makes the project read as its own. Upstream fixes worth having (e.g. for new macOS releases or notch hardware) are ported by hand, case by case. Attribution and the GPL-3.0 obligation are carried by the LICENSE file and the README's credits section, never by Git history — keep both intact.

## Considered Options

- **GitHub fork, regularly merging upstream**: most fixes for free, but painful merges given how far SimpleNotch diverges. Rejected.
- **GitHub fork with history, cherry-picking only**: stronger visible link to upstream; rejected in favour of a clean, standalone history.
