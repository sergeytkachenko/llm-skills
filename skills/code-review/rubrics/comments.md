# Track: comments

Lens: do comments earn their place by explaining what the code cannot say itself — and do they
do it in as few words as possible, in the right place, in the right form?
Stack: NestJS, Vue 3, TypeScript.

Check, in priority order:

1. Why, not what
   - Good comments explain intent, a tradeoff, or a non-obvious constraint. Flag comments that
     merely restate what the code already says.

2. Verbosity & volume
   - Comments must be terse. Flag multi-line/paragraph comments where one line carries the same
     "why"; cut narrative to the single non-obvious fact. A reader skims code, not prose.
   - Flag any block where the comments outweigh the code they annotate (roughly: more comment
     lines than code lines in a method, or a wall of `//` before a short body). Note the ratio
     and what to delete.
   - AI-generated explanation prose is the usual offender: it over-explains the obvious and
     re-narrates the diff. Strip it down to the one line a human couldn't infer from the code.

3. No narrative / history / cross-references
   - Comments are not a changelog or decision log. Flag and recommend deleting: internal
     decision-record IDs (`ADR-00xx`), ticket/story numbers, dates, commit SHAs, incident or
     codename references, "see PR #…", and internal harness/file-path breadcrumbs.
   - That history belongs in version control, the PR description, or the ADR file — not inline.
     The code comment should stand on its own without the reader needing to look any of it up.

4. Right place: declaration doc vs in-body
   - An explanation of what a method/function/class does, its parameters, return, or contract
     belongs in a **doc comment on the declaration** (above the signature), not as loose `//`
     lines inside the body. Flag in-method comments that are really API documentation and say
     "move to the declaration".
   - In-body comments should be short, line-specific notes about a single non-obvious step.

5. Right form: IDE-visible doc comments
   - Documentation a reader will want on hover must use the doc-comment form the IDE surfaces:
     TSDoc/JSDoc `/** … */` in TypeScript (not a plain `//` block, which IDEs don't show as a
     tooltip). Flag `//` used where `/** */` is required for the comment to reach tooltips and
     IntelliSense. Flag HTML tags inside comments — they add noise and don't render where it
     matters.

6. Self-explanatory code first
   - If a comment is patching unclear code, the fix is usually a better name or an extracted
     function — recommend that instead of keeping the comment.

7. Dead weight
   - Flag commented-out code (it belongs in version control), banner/ASCII noise, divider
     comments that only restate a section name, and auto-generated boilerplate comments.

8. Truthfulness
   - A comment that contradicts the current code is worse than none. Flag stale comments that
     no longer match behavior — especially after the change under review.

9. TODO / FIXME hygiene
   - Each should carry context and ideally an owner or ticket. Flag orphaned TODOs with no
     explanation.

10. Public API documentation
    - TSDoc/JSDoc on exported functions, services, and DTOs where it adds value: document
      non-obvious parameters, thrown errors, and side effects. Don't document the obvious — a
      doc comment that just repeats the signature is noise, not documentation.

Report per the output contract. The default bias is **delete**: when a comment isn't clearly
earning its place, the recommendation is to remove it, not to reword it.
