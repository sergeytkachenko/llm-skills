# Track: clean-code

Lens: are individual functions and methods simple, honest, and easy to change?
Stack: NestJS, Vue 3, TypeScript. This is a function/method-level pass — leave system
structure to `architecture`, names to `naming`, comments to `comments`.

Check, in priority order:

1. Function shape & honesty
   - One job per function. Flag functions doing several unrelated things, and functions long
     enough that you must scroll to understand them.
   - Too many parameters → pass an options object. Flag boolean "flag" parameters that select
     behavior; split into two functions instead.
   - Flag a function that returns different shapes on different paths (object here, `null`
     there, array elsewhere) — pick one contract. Flag getters/`computed`/predicates with
     side effects (mutation, I/O, logging) — a `get`/`is`/`has` must be pure.
   - Flag mutation of parameters or shared/module state as a hidden side effect; prefer
     returning a new value. Watch array/object args mutated in place.

2. Complexity & nesting
   - Deep nesting / arrow code → guard clauses and early returns. Flag pyramids of `if`.
   - Flag clever one-liners that trade clarity for brevity, and defensive checks for states
     that can't occur (over-guarding) — they hide the real contract.

3. Duplication (DRY)
   - Flag copy-pasted logic that should be extracted. Distinguish true duplication from
     coincidental similarity — don't force a bad abstraction.

4. Magic values & primitive obsession
   - Flag unexplained numbers/strings; extract named constants or enums.
   - Flag a bag of loose primitives (e.g. `string` id + `string` currency passed everywhere)
     that should be one cohesive type/value object.

5. Dead & unreachable code
   - Flag unused variables, parameters, imports, and unreachable branches.
   - Flag premature optimization (caching/micro-tuning) on code that isn't a proven hot path;
     prefer the clear version until measured.

6. Error handling
   - No swallowed errors, no empty `catch`, no `catch` that only logs and silently continues.
   - Errors carry context; don't use exceptions for ordinary control flow.
   - One failure mode per function: flag code that sometimes throws and sometimes returns
     `null`/`undefined` for the same kind of failure.

7. TypeScript discipline
   - Flag `any` (prefer `unknown` + narrowing), lying assertions (`as`), and non-null `!`
     used to silence the compiler. Prefer `readonly`/immutability.
   - Make `switch`/`if` chains over a union exhaustive (`never` default); flag silent fallthrough.
   - Flag unsafe narrowing (`as`-casts in type guards, truthiness checks on `0`/`""`).
   - Flag `Partial<T>`/optional fields used to dodge required data — model real optionality;
     use a discriminated union for state instead of many independent optional flags.
   - Prefer string-literal unions over `enum` unless a runtime enum is genuinely needed.

8. Async correctness
   - Flag floating promises (un-awaited async), missing `await`, and sequential `await` in a
     loop where `Promise.all` is correct. Flag unhandled rejections (no `catch`/`try`).
   - Vue: no async/side effects inside `computed` (must be pure); `watchEffect` only when deps
     are truly implicit — otherwise `watch` an explicit source. Flag timers, listeners, and
     subscriptions not torn down in `onUnmounted` (lifecycle leak).

Report per the output contract.
