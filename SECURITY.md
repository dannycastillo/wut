# Security policy

## Reporting

Report a vulnerability privately, not in a public issue: the Security tab
on GitHub, then "Report a vulnerability".

Include the version (`wut --version`), what you did, and what happened.

## Supported versions

The latest tagged release only. There are no backports.

## What is by design

Not vulnerabilities:

- `wut` reads every `*.txt` file under `~/.wut` and treats each one as
  snippets. Files there are the user's own.
- The command you pick is copied to the clipboard, never run. Pasting it is
  the user's decision.
