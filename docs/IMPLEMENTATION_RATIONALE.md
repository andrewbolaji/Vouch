# Implementation rationale

Why specific implementations are shaped the way they are, for a
reviewer who has the code but not the history.

Entries are added when the reasoning is not recoverable from the diff.
If a reader can work out why from the code alone, it does not belong
here.

---

## Verifying that gated data is not in the release binary

**The claim.** Paid content, meaning ranks above `kFreeTierMaxRank`
and all insider notes, is not compiled into the iOS release binary.

**Why the claim needs a method at all.** `lib/data/seed_data.dart` is
the offline fallback. It ships inside the app. Anyone willing to unzip
an `.ipa` can read it, so its contents are effectively public
regardless of what `firestore.rules` says. Reading the Dart source
does not settle the question, because the question is not what the
source says, it is what survives compilation into the AOT snapshot.

### The method that works

```
flutter build ios --release --no-codesign
strings -a build/ios/iphoneos/Runner.app/Frameworks/App.framework/App \
  | grep -cF "<canary>"
```

### Two methods that produce a confident false pass

Both were tried, both "passed," and both were wrong.

1. **`flutter build web --release`, then grep `main.dart.js`.**
   Compiles cleanly and the canary is absent. So is `Mensho`, and
   every other seed string. `dart2js` does not preserve them
   greppably, so the grep returns nothing whatever the input is.

2. **`grep -c` directly on the binary, without `strings`.** Returns 0
   for everything, controls included.

Both fail the same way: they return zero for a reason unrelated to
the thing being tested. A gate that cannot fail is not a gate.

### The rule that catches this: grep before, and carry controls

**Run the grep before the change and show it finds the canary.** A
grep returning nothing after a fix proves nothing unless it returned
something before. That single step killed both bad methods above.

**Include controls that must survive.** This is the half that is easy
to skip. Canaries prove content left. Controls prove the measurement
still works. A build that dropped every string, or a grep pointed at
the wrong file, produces a perfect-looking column of zeros.

Measured at `e3205bd`, then again after:

| Canary | Kind | Before | After |
|---|---|---|---|
| `Joey Uptown` | rank 9 | 1 | **0** |
| `No reservations and lines form...` | insiderTip | 1 | **0** |
| `Wagyu Texas BBQ Tantanmen` | whatToOrder | 1 | **0** |
| `Top Sushi` | rank 7 | 2 | **1** |
| `The Better Box` | rank 8 | 2 | **1** |
| `Mensho` | **control**, rank 1 | 3 | **3** |
| `Corkscrew BBQ` | **control**, rank 5 | 3 | **3** |

### Why the two canaries that did not reach zero make the table more credible, not less

`Top Sushi` and `The Better Box` went from 2 to 1 rather than to 0.

The temptation is to report five of seven as a partial success, or to
round it off. Both are wrong, because the residue is not noise. It is
a second, independent leak with its own cause, and the number is what
exposed it.

The seed was not the only thing shipping those names.
`lib/config/demo_image_overrides.dart` maps restaurant name to a
bundled asset path, and `assets/demo/` is declared in `pubspec.yaml`,
so it ships. Three of its keys are gated restaurant names. The names
and the photographs of three gated restaurants were in the binary
regardless of what the seed held. Emptying the seed could not close
it, and no amount of re-reading `seed_data.dart` would have revealed
it.

That channel was found **because the number was 1 and not 0**, and
because the before-column said 2 rather than "present."

Three things follow, and they generalise past this project:

1. **A partial result is information.** "5 of 7" invites a judgement
   call about whether that is good enough. "2 became 1, and here is
   the second thing writing that string" is a finding. Counts do this;
   present-or-absent does not.

2. **Controls are what make the zeros mean anything.** Without
   `Mensho` and `Corkscrew BBQ` holding at 3, the three genuine zeros
   are indistinguishable from a broken measurement. The controls are
   the difference between "the data left" and "the grep stopped
   working."

3. **Reporting the residue is what makes the rest of the table
   trustworthy.** A table that resolves perfectly is the shape a
   reader has learned to be suspicious of. One that explains its own
   imperfection, by name, with a cause, is one they can check. The
   two ones are the most load-bearing numbers in it.

### Applying this elsewhere

The generalisable form: **before, after, and a control, with counts
rather than booleans.** Prove the check can fail before trusting it to
pass, prove it still works after, and treat anything that does not
land where predicted as a lead rather than a rounding error.

This is standing rule 3c ("verify that your verification commands
actually verify") with a worked example attached. See also 3e, on the
difference between a path existing and a path being reachable, which
is the same class of mistake in a different register.
