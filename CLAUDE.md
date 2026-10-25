# Data-Coloured

Renders a byte stream as ANSI-coloured text: control characters by name in square
brackets (`[ETX]`), printable characters as-is, everything else as hex in angle
brackets (`<ff>`). Built for eyeballing TCP and UART streams.

Released to CPAN as `Data-Coloured`, built with `Dist::Zilla` via `[@Author::GETTY]`.
Two modules — `Data::Coloured` holds the logic, `DDC` is a thin re-export alias — plus
the `ddc` CLI script.

The export contract, the colour classes and the encoding rules live in skill
`data-coloured-core` — they are not repeated here.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
the principle is a shared house rule (skilletor bundle `getty-cpan-dist@getty`); the lane
boundaries are in `.claude/rules/data-coloured-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `data-coloured-worker` (default) |
| Commits, `Changes`, card → done, pre-release audit | `data-coloured-release-manager` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main
agent delegates rather than loading them. Skill sources live under `.claude/skills/` —
`getty-perl-core`, `getty-perl-pod` and the karr skills are installed from the shared
sources; `data-coloured-core` is owned by this repo.

Work is coordinated on the repo's `karr` board (`karr board`).

## State of the code

This distribution has not been touched since 2015 (CPAN release 0.003). It predates the
current house structures — the CI is a Travis file, the `cpanfile` is missing its
runtime dependency, `LICENSE`, `Changes` and `README.md` do not exist, and the
character split mishandles multi-byte UTF-8 (open GitHub issue #1, tracked on the
internal board). The `Changes` file and the release history start with the current
work, not with the 2014/2015 releases.
