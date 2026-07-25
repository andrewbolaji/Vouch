---
description: Plan, build, review adversarially until approved, verify like a user, then present
argument-hint: [what to build]
---

Ship: $ARGUMENTS

Never present a first draft. The steps below are sequential, and step 3 is a
loop, not a formality.

## 1. Plan

Read the code paths this touches before proposing anything. Say what you will
change, which files, and what could break. For anything non-trivial, get the
plan agreed before writing code.

State up front which of the three suites this change can affect: Flutter (310),
Cloud Functions (63), Firestore rules (79). If it touches `functions/` or
`firestore.rules`, the emulator suites are in scope.

## 2. Build

Write the change and its tests together. The test must fail against the old
code. If you cannot write a test that would have caught the bug, say so
explicitly and explain why rather than quietly skipping it.

Follow `CLAUDE.md` house style: no em dashes, sentence case headings, comments
that say why rather than what.

## 3. Adversarial review, until approved

Invoke the `reviewer` subagent on the diff. Hand it the actual diff and the
context, not a summary that flatters the change.

Then:

- Fix every BLOCKER.
- Fix each SHOULD FIX, or state plainly why you are not.
- Re-invoke the reviewer on the updated diff.
- Repeat until the verdict is APPROVE, up to three rounds. If it is still
  REQUEST CHANGES after three, stop and escalate to the user with the
  outstanding findings rather than looping.

Do not argue the reviewer into approving, and do not skip the re-review because
the fixes "were small." If you disagree with a finding, say why in your response
to the user and let them decide, rather than overriding it silently.

## 4. Verify like a user

Tests passing is not the same as the feature working.

For UI changes, run the app and screenshot the actual screen, including the
states people hit and forget to check: loading, empty, error, offline, signed
out, and free tier versus paid tier. Attach the screenshots.

For backend changes, exercise the real path against the emulator and show the
resulting Firestore state, not just the unit test output.

If you could not verify something, name it. Do not let it pass as verified.

## 5. Present

Give the user:

- What changed and why.
- The reviewer's final verdict and anything you pushed back on.
- Test counts for every suite you ran, with actual numbers.
- Screenshots or emulator output from step 4.
- What you did not verify, and what you would check next.

Then commit and push. Uncommitted work does not exist.
