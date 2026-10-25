# Data-Coloured House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Visualize random ASCII data streams (`Data::Coloured`, `DDC`). Contract table: skill
`data-coloured-core`.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `data-coloured-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `data-coloured-release-manager` |
| Read-only research, audit, gap analysis | `data-coloured-worker` ("read-only, change nothing") |

Behavior-relevant = anything in `lib/`, the tests, the exported function set, the character
classification and its rendering, and the export tiers. `README.md` and `Changes` wording are
not.

## Release

The last CPAN release is 0.003 (2015); the next is 0.004, derived at release time by
`getty-perl-release-author-getty` — not copied back from CPAN.

## Deviations from the house rules

- **A new dependency needs a real justification.**
- The 2014 Unicode issue (GitHub #1) is tracked on the internal board; work happens there, not
  on the issue.

## Hazards

- **The rendering contract is the product — don't regress it silently.** This tiny module's
  whole value is *how a byte is rendered*. The three-way classification (control characters by
  name in square brackets, printable as-is, everything else as hex in angle brackets), the
  exact colour per class, the delimiters, the `TAB` naming of control code 9 and the two export
  tiers are what callers depend on. Any change to them is user-visible: `Changes` entry plus
  test.
- **The unit question — byte or character — is the sharp edge.** Both branches of the
  classification must agree on it; a fix that widens the printable branch without deciding what
  the hex branch means leaves the rendering incoherent.
