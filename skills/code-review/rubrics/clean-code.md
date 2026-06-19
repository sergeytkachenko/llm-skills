# Track: clean-code

Lens: are individual functions and methods simple, honest, and easy to change?
Stack: NestJS, Vue 3, TypeScript. This is a function/method-level pass — leave system
structure to `architecture`, names to `naming`, comments to `comments`.

Check, in priority order:

1. Function shape
   - One job per function. Flag functions doing several unrelated things, and functions long
     enough that you must scroll to understand them.
   - Too many parameters → pass an options object. Flag boolean "flag" parameters that select
     behavior; split into two functions instead.

2. Complexity & nesting
   - Deep nesting / arrow code → guard clauses and early returns. Flag pyramids of `if`.
   - Flag clever one-liners that trade clarity for brevity.

3. Duplication (DRY)
   - Flag copy-pasted logic that should be extracted. Distinguish true duplication from
     coincidental similarity — don't force a bad abstraction.

4. Magic values
   - Flag unexplained numbers/strings; extract named constants or enums.

5. Dead & unreachable code
   - Flag unused variables, parameters, imports, and unreachable branches.

6. Error handling
   - No swallowed errors, no empty `catch`, no `catch` that only logs and silently continues.
   - Errors carry context; don't use exceptions for ordinary control flow.

7. TypeScript discipline
   - Flag `any` (prefer `unknown` + narrowing), lying type assertions (`as`), and non-null `!`
     used to silence the compiler. Prefer `readonly`/immutability; make switches exhaustive.

8. Async correctness
   - Flag floating promises (un-awaited async), missing `await`, and sequential `await` in a
     loop where `Promise.all` is correct.
   - Vue: no side effects inside `computed`; pick `computed` vs method correctly.

Report per the output contract.
