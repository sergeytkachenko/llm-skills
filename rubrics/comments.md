# Track: comments

Lens: do comments earn their place by explaining what the code cannot say itself?
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Why, not what
   - Good comments explain intent, a tradeoff, or a non-obvious constraint. Flag comments that
     merely restate what the code already says.

2. Self-explanatory code first
   - If a comment is patching unclear code, the fix is usually a better name or an extracted
     function — recommend that instead of keeping the comment.

3. Dead weight
   - Flag commented-out code (it belongs in version control), banner/ASCII noise, and
     auto-generated boilerplate comments.

4. Truthfulness
   - A comment that contradicts the current code is worse than none. Flag stale comments that
     no longer match behavior — especially after the change under review.

5. TODO / FIXME hygiene
   - Each should carry context and ideally an owner or ticket. Flag orphaned TODOs with no
     explanation.

6. Public API documentation
   - TSDoc/JSDoc on exported functions, services, and DTOs where it adds value: document
     non-obvious parameters, thrown errors, and side effects. Don't document the obvious.

Report per the output contract.
