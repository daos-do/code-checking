# Git Commit Message Guidelines

This guide captures recommended commit message conventions for this
repository.

Structured commit messages also help review, release notes, and future
history browsing.

## Format

Recommended structure:

1. Subject line
2. Blank line
3. Body (one or more wrapped paragraphs)
4. Optional grouped bullet sections
5. Optional trailers (`Refs:`, `Co-authored-by:`, and similar)

## Subject Line

- Start with the ticket ID when available (for example: `SRE-3706`).
- Keep it short and action-oriented.
- Target about 50 characters when practical.
- Use imperative style (`Add`, `Fix`, `Update`, `Refactor`).
- Avoid a trailing period.

Common subject variants:

- `<ticket-id>: <short imperative title>`
- `<ticket-id>: <area> <short imperative title>`

Examples:

- `SRE-3706: Add Python linting with flake8 + pylint`
- `SRE-3706: Add groovylint and markdownlint`

## Body

- Leave the second line blank.
- Wrap lines around 72 characters.
- Explain what changed and why.
- Include useful validation context when it adds review value.

Good pattern:

- Paragraph 1: primary change and intent.
- Paragraph 2: related fixes discovered during validation.
- Paragraph 3: validation scope or consumer testing notes.

## Large or Multi-Area Commits

For broad commits, group the body by area so future readers can scan it
quickly.

Examples:

- `Linter framework wiring:`
- `Script implementation:`
- `Docs and tooling updates:`

Prefer grouped scope summaries over a long unstructured file list.

## Drafting Workflow

For larger commits, draft the message in a local scratch file first, such as:

- `zzz-commit-messages.txt`

Benefits:

- IDE spellcheck can catch typos.
- Easier line wrapping and wording cleanup before commit.
- Helpful for collecting validation notes during active review.

Suggested flow:

1. Draft and refine the message in a scratch file.
2. Commit with `git commit -F <file>` or paste it into the editor.
3. Keep or trim the scratch notes based on your local workflow.

## Style Recommendations

- Keep wording factual and concise.
- Avoid vague phrases like `misc fixes`.
- Remove stale notes before committing.
- Keep the subject focused even if the body explains added scope.

## Signed-off-by Policy

HPE baseline policy requires a `Signed-off-by:` trailer for non-employee
contributors.

Local group policy is stricter: require `Signed-off-by:` for all commits,
including employee-authored commits.

Add it automatically with:

```bash
git commit -s
```

Meaning:

- `Signed-off-by` is author attestation under DCO-style contribution terms.
- It does not replace normal review or approval requirements.

## References

For broader background, see the Git Book section on commit guidelines:

- [Git Book: Commit Guidelines](https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project)
- [Git Project: Documentation/SubmittingPatches](https://github.com/git/git/blob/master/Documentation/SubmittingPatches)

That section aligns well with the conventions used here, especially the
short summary line, blank-line separation, imperative mood, and wrapping
the body around 72 columns.

## Example Template

```text
SRE-XXXX: Short imperative summary

One or two sentences describing the primary change and purpose.

If needed, summarize related fixes discovered during validation and why
they were included in the same commit.

Validation summary (optional): list tested platforms, consumer repos, or
commands.

Linter framework wiring:
- ...

Script implementation:
- ...

Docs and tooling updates:
- ...
```
