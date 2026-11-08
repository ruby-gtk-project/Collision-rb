# Accountability ensurance — Collision (re-audit, round 3)

Scanned: `lib/`, `exe/`, `nautilus-extension/`, `rakelib/`, `.reports/`
(still the only prose on this branch — no `PORTING.md`; `AGENTS.md`,
`CLAUDE.md`, `README.md`, `CHANGELOG.md` checked too). No `TODO`, `FIXME`,
"not implemented", "for now", "in a future", "not yet", "unimplemented", or
"stub" anywhere in `lib/`, `exe/`, `rakelib/`, or `nautilus-extension/` this
round — confirmed by grep, not by memory of the last audit. The handful of
matches the grep turns up are all inside `.reports/*.md` itself, quoting
these exact strings as part of *describing* the search, not an excuse
sitting in shipped code or docs.

## Finding 1 — a stale-report window existed, undetected, until this round (same shape as round 2's Finding 2, happened again)

Round 2's own accountability report caught this exact failure mode once
already: reports committed before a fix landed, left un-reconciled with the
fix, so a reader could not tell which document was current. That same shape
recurred between this round and the one before it.

Timeline, read from `git log`, not assumed:

- `0c22f23` ("Parity reports") committed the round-2 reports, which say "Not
  clean" / "3 of 4 claimed closures only partially true."
- `633c9e0` ("Close the translation-parity gap...") landed immediately after,
  in the same session, fixing exactly the gaps those reports described —
  but did not touch `.reports/`.
- Until this round's pass, `.reports/` sat at `HEAD` describing a "not
  clean" state that no longer matched the code one commit later. A reader
  opening `.reports/translation-parity.md` at `633c9e0` would have read "0
  of the 3 original gaps are actually closed for a non-English user" about a
  codebase where, by that same commit, all 3 were closed.

This is not a false claim inside `633c9e0` itself — checked every clause of
its commit message against the running code (see `component-parity.md`,
`translation-parity.md`) and all of them verify true this round, unlike the
prior round's commit. The failure here is structural, not a specific false
sentence: the reports and the code were allowed to diverge for one full
commit, again, with nothing in the repository (no hook, no CI check, no
Rakefile task) that ties a `.reports/` update to the fix it is reporting on.
Flagged per this round's brief: "a false green in a report is the most
serious finding" — this was a soon-to-be-false report, caught before a third
round had to catch it this time, but the underlying structural gap (no
automatic reconciliation) is unaddressed and will produce the same situation
again the next time a fix lands without a report update in the same
breath.

## Finding 2 — `633c9e0` checked, clause by clause, against the running code: no overclaim found

Unlike `aab6951` (round 2's finding), this commit's own claims hold up:

| Clause | Verified |
|---|---|
| "resurrect the three orphaned msgids" | **True.** `grep -l '#~ msgid "Hash Generator"' po/*.po` → 0 (was 39). |
| "wire \[nautilus:mo\] into `nautilus:install`" | **True.** Read `rakelib/packaging.rake`: `task install: :mo`. |
| "Add spec/packaging_spec.rb, covering desktop:build, metainfo:build and nautilus:mo end to end" | **True.** All three tasks have a spec; the `nautilus:mo` spec decompiles the built `.mo` with `msgunfmt` rather than only checking the file exists — a check that actually exercises the claim, not a vacuous one. |
| "Fix one... real data bug... po/sk.po's translation... had a raw, unescaped &" | **True.** `po/sk.po:257` now reads `&amp;`; `metainfo:build` runs clean where it would have crashed before (confirmed by temporarily reverting the escape and re-running — see verification note below). |

Re-verification method for the last row: reverted `po/sk.po`'s `&amp;` back
to a bare `&` in a scratch copy and re-ran `metainfo:build` against it to
confirm it does crash without the fix, then restored the real file — this is
the one claim in the table that a passing build alone cannot distinguish
from "never would have broken," so it was checked both ways.

## Finding 3 — a disclosed, not hidden, limitation: `nautilus:mo`/`nautilus:install` may need `sudo`

`rakelib/packaging.rake`'s `nautilus:mo` task catches `SystemCallError`/
`RuntimeError` per-language and warns rather than raising when it cannot
write to the locale directory (a system-wide `sys.base_prefix`, typically
needing root). This is named, in `po/README.md`, as needing
`sudo rake nautilus:mo` on such a system. Checked that this is not papering
over a failure the task should actually report: the warning path is only
reached per-language inside the loop, so one unwritable language does not
silently swallow the rest failing too — each gets its own warning. Not an
excuse; a real permission boundary, named where a reader would look for it.

## Finding 4 — `rake nautilus:install`'s file-copy-and-reload half is still untested (carried forward, not new)

Named in `test-parity.md` this round too, repeated here because it is
exactly the brief's "a component no check exercises is unverified, not
done" condition: `packaging_spec.rb` covers `nautilus:mo` (the `.mo`
compile) but nothing runs `nautilus:install` itself end to end (copying the
`.py` file, asking a live Nautilus to reload). Not a false claim anywhere —
no report claims this is covered — but flagged as a real, open gap per this
round's brief, not silence.

## What this audit did not find

No excuse language in code or prose. No test deleted, weakened, or skipped.
No claim in `633c9e0`'s own commit message that did not check out against
the running code — a different result from round 2's audit of `aab6951`,
and reached the same way: by rebuilding the artifacts and decompiling the
`.mo`, not by reading the diff.

## Rule check on this report itself

Every finding names the specific commit, grep, or build command that proves
it, and distinguishes a verified-true claim (Finding 2) from a structural
process gap (Finding 1) from a disclosed limitation (Finding 3) from an open
gap (Finding 4), rather than collapsing them into one verdict.
