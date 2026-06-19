# Track: comments

Lens: do comments earn their place by explaining what the code cannot say itself — and do they
do it in as few words as possible, in the right place, in the right form?
Checks are language-agnostic; examples lean toward NestJS/Vue/TypeScript.

Check, in priority order:

1. Why, not what
   - Good comments explain intent, a tradeoff, or a non-obvious constraint. Flag comments that
     merely restate what the code already says.

2. Verbosity & volume
   - Comments must be terse. Cut multi-line/paragraph comments to the single non-obvious fact;
     flag any block where comment lines outweigh the code they annotate. Note what to delete.
   - AI-generated explanation prose is the usual offender: it over-explains the obvious and
     re-narrates the diff. Strip it to the one line a human couldn't infer from the code.

3. No narrative / history / cross-references
   - Comments are not a changelog or decision log. Flag and recommend deleting: internal
     decision-record IDs (`ADR-00xx`), ticket/story numbers, dates, commit SHAs, incident or
     codename references, "see PR #…", and internal harness/file-path breadcrumbs.
   - That history belongs in version control, the PR description, or the ADR file — not inline.
     The code comment should stand on its own without the reader needing to look any of it up.

4. Right place: declaration doc vs in-body
   - An explanation of what a method/function/class does, its parameters, return, or contract
     belongs in a **doc comment on the declaration** (above the signature), not as loose
     inline comments inside the body. This holds in any language. Flag in-body comments that are
     really API documentation and say "move to the declaration".
   - In-body comments should be short, line-specific notes about a single non-obvious step.

5. Right form: IDE-visible doc comments
   - Docs a reader wants on hover must use the language's **doc-comment form**, not a plain
     inline comment. A plain `//` (or any non-doc comment) never reaches tooltips, IntelliSense,
     or generated docs. Use the form the tooling recognizes:
     - TypeScript/JavaScript — TSDoc/JSDoc `/** … */`
     - Java/Kotlin — Javadoc/KDoc `/** … */`
     - Python — docstrings `"""…"""` (first statement in the module/class/function)
     - Go — doc comments: a `// Name …` comment directly above the declaration
     - Rust — `///` (item docs) / `//!` (module docs)
     - C# — XML-doc `///`
   - Flag a non-doc comment used where the doc form is required. Flag HTML tags inside comments
     when they're noise that doesn't render where it matters.

6. Self-explanatory code first
   - If a comment is patching unclear code, the fix is usually a better name or an extracted
     function — recommend that instead of keeping the comment.

7. Dead weight
   - Flag commented-out code (it belongs in version control), banner/ASCII noise, divider
     comments that only restate a section name, and auto-generated boilerplate comments.

8. Truthfulness
   - A comment that contradicts the current code is worse than none. Flag stale comments that no
     longer match behavior — especially after the change under review. Doc tags must be accurate:
     flag deprecation/throws/param/return tags (e.g. `@deprecated`/`@throws`/`@param`/`@returns`,
     or their docstring/XML-doc equivalents) that name the wrong thing or describe behavior the
     code no longer has.

9. TODO / FIXME hygiene
   - Each should carry context and ideally an owner or ticket. Flag orphaned TODOs with no
     explanation.

10. Public API documentation
    - Doc comments on exported/public surfaces — exported functions, public classes and services,
      DTOs/structs — where they add value: document non-obvious parameters, thrown errors, and
      side effects. The doc-comment form is the language's own (TSDoc, Javadoc/KDoc, Python
      docstrings, Go doc comments, Rust `///`, C# XML-doc). Don't document the obvious — a param/
      return note that just restates what the types and signature already say is noise. Flag it.

11. Suppressions
    - Any tool or compiler suppression must state why. The comment should justify the escape
      hatch, not just silence the tool. Flag bare ones, in whatever the stack uses:
     - TS/JS — `eslint-disable`, `@ts-ignore`/`@ts-expect-error`
     - Java — `@SuppressWarnings`
     - Python — `# noqa`, `# type: ignore`
     - Go — `//nolint`
     - Rust — `#[allow(...)]`
     - C# — `#pragma warning disable`

Report per the output contract. The default bias is **delete**: when a comment isn't clearly
earning its place, the recommendation is to remove it, not to reword it.
