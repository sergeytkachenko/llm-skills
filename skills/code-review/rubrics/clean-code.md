# Track: clean-code

Lens: are individual functions and methods simple, honest, and easy to change?
Checks are language-agnostic; examples lean toward NestJS/Vue/TS but apply to Java, Go,
Python, Rust, C#, etc. This is a function/method-level pass — leave system structure to
`architecture`, names to `naming`, comments to `comments`.

Check, in priority order:

1. Function shape & honesty
   - One job per function. Flag functions doing several unrelated things, and functions long
     enough that you must scroll to understand them.
   - Too many parameters → pass an options object/struct. Flag boolean "flag" parameters that
     select behavior; split into two functions instead.
   - Flag a function that returns different shapes on different paths (object here, `null`
     there, array elsewhere) — pick one contract. Flag getters/predicates with side effects
     (mutation, I/O, logging) — a `get`/`is`/`has` (or `computed`, property getter) must be pure.
   - Flag mutation of parameters or shared/module/global state as a hidden side effect; prefer
     returning a new value. Watch array/object/slice/collection args mutated in place.

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
     (Equally: ignored Go `err` returns, bare `except: pass`, discarded `Result`/`Either`.)
   - Errors carry context; don't use exceptions for ordinary control flow.
   - One failure mode per function: flag code that sometimes throws and sometimes returns an
     empty/`null`/`nil`/sentinel value for the same kind of failure.

7. Type & language discipline
   - Flag escape-hatch casts that silence the type system rather than prove safety: TS
     `any`/`as`/non-null `!` (prefer `unknown` + narrowing, `readonly`); Go `interface{}`/`any`
     and unchecked type assertions (`x.(T)` without the `, ok`); Java raw types, unchecked
     casts, blanket `@SuppressWarnings`; Python `# type: ignore`/`cast()`; C# `dynamic`/`!`.
   - Make decisions over a closed set exhaustive: flag silent fallthrough on a `switch`/`if`
     chain (TS union `never` default; Java sealed types/`switch` exhaustiveness; Rust `match`
     arms; enum switches everywhere). Flag unsafe narrowing (casts inside a type guard,
     truthiness checks on `0`/`""`/empty).
   - Model optionality honestly. Flag `Partial<T>`/optional fields (or sloppy `null`/`nil`)
     used to dodge required data; prefer disciplined `Optional`/`null`/`nil` handling and a
     discriminated union / sealed hierarchy / sum type for state over many independent flags.
   - Prefer immutability where the language offers it: TS `readonly`, Java `final`, Rust
     ownership/borrowing, Go value vs pointer receivers. Prefer string-literal unions over a
     runtime `enum` unless a real runtime enum is needed.

8. Async & resource correctness
   - Flag un-awaited async work whose result/error is dropped: JS floating promises and
     missing `await`; Go goroutines whose error is never collected; un-awaited Python
     coroutines; ignored Java `Future`/`CompletableFuture`. Flag unhandled rejections (no
     `catch`/`try`).
   - Flag serial awaits where work is independent and should run in parallel: `Promise.all`;
     goroutines + `errgroup`; parallel streams / `CompletableFuture.allOf`.
   - Flag resources and lifecycles not torn down: timers, listeners, subscriptions, file
     handles, sockets, connections. (Vue `onUnmounted`; Go `defer Close()` / context cancel;
     Java try-with-resources / `close()`; Python context managers / `with`.) In Vue, also
     keep `computed` pure and use `watch` on an explicit source unless deps are truly implicit.

Report per the output contract.
