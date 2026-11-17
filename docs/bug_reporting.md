# Authenticated public bug reporting

## User behavior

Settings → Report a Bug opens an ordered form: title, description, optional reproduction steps, expected behavior, and actual behavior. Required fields and limits are validated in both clients and server. A separate dialog explains that the report will be public on GitHub and requires “Post publicly” before transmission. The app attaches no account details, logs, device identifiers, or learning data. Reports go only to `Roonil03/Flashstep-Microlearner`.

`POST /api/v1/bug-reports` requires the normal bearer session of an active, nondeleted account. It accepts exactly `title` (5–120 characters), `description` (20–4,000), `reproduction` (0–3,000), `expected` (5–2,000), `actual` (5–2,000), and `public_confirmed: true`. Leading/trailing whitespace is removed. Titles are single line. Unknown keys, extra JSON values, unsupported controls, invalid UTF-8, and request bodies over 48 KiB are rejected. Only these explicitly entered fields and an opaque report UUID leave the server for GitHub.

The server returns 202 only after GitHub accepts a workflow dispatch, with a report identifier. This means queued, not that an issue has already been created. The UI displays that distinction and preserves the form on failure. The operator must monitor failed Actions jobs and rerun a failed job using the same event/report UUID.

## Required operator setup

1. Use the existing PostgreSQL schema. Public bug reporting requires no additional database tables or migrations.
2. Merge `.github/workflows/bug-report.yml` into the target repository's `main` branch (and ensure the repository default branch recognizes the dispatch workflow). Enable Actions and Issues. The destination, workflow filename, and dispatch branch are intentionally fixed in server source. Forks do not publish reports because the job checks the exact repository and main ref.
3. Create an expiring **fine-grained personal access token** restricted to **only** `Roonil03/Flashstep-Microlearner`, granting repository **Actions: write** and GitHub's mandatory metadata read permission. Do not grant Contents write, Issues write, classic `repo`, or organization-wide access. Store it only in the backend host's secret store as `BUG_REPORT_GITHUB_TOKEN`, then restart the backend. Rotate it before expiry and after any suspected compromise. An empty value disables delivery with 503. This credential authorizes workflow dispatch, so maintainers must review all dispatchable workflows in this repository and protect changes to main.
4. The workflow uses GitHub's automatically scoped `GITHUB_TOKEN` with **Issues: write only**; every other permission is disabled. It does not need a repository secret, checkout, third-party action, deployment key, GitHub password, or a client-side credential. Repository/organization policy must allow this workflow permission. Do not change the form to call GitHub directly.
5. Allow backend HTTPS egress to `api.github.com`. Ensure infrastructure does not record bearer headers or JSON report bodies. Monitor endpoint 429/503 rates, Actions delivery failures, token expiry, and GitHub rate limits. Verify schema and credentials in a private staging repository with an intentionally adapted fixed destination; never generate test issues in the upstream repository.

GitHub documents [workflow dispatch permissions](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event) and [workflow token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions).

## Abuse limits, deduplication, and retries

The handler checks that the account is active in the existing users table. Bounded process memory stores opaque identifiers, timestamps, and acceptance status. It retains no report text. Reservations count toward rolling limits even if dispatch fails. Limits are three attempts per account in 24 hours, 30 per backend process in one hour, and five minutes between distinct reports from an account. Identical retries wait at least one minute. These quotas reset when the process restarts and apply independently to each replica. Infrastructure limits can supplement them.

Report identifiers are derived from the account and normalized fields using a domain-separated HMAC with the configured JWT secret. The same account and unchanged report produce the same opaque UUID across restarts and replicas using that secret. Rotating the secret changes the identifier and its deduplication scope. An already accepted submission returns its existing UUID while its in-memory entry is retained. The handler bounds metadata to 24,000 entries and 720 rolling attempt records. Metadata expires after 30 days, and attempts leave the quota window after 24 hours.

Workflow concurrency serializes the same UUID. The bot checks open and closed issues for its own report marker before posting, preserving deduplication after a backend restart. It performs one issue POST per workflow run. A failed or ambiguous delivery can be retried with the same report UUID. Closed reports stay closed. After GitHub accepts a dispatch, monitor the Actions job to confirm issue creation and rerun a failed job with the same UUID.

## Handling untrusted report text

The server destination and workflow branch are constants; neither comes from the request. Tokens and raw GitHub responses are never returned or logged by the handler. The workflow reads inputs from `GITHUB_EVENT_PATH` as JSON and validates them again. It never interpolates report text into shell, Python, Actions expressions, filenames, API destinations, or commands. Report bodies are put in literal code fences longer than any backtick run in the submitted text, making Markdown/HTML and mentions inert. Title `@` characters become fullwidth equivalents to avoid unwanted mention notifications. The issue is authored by `github-actions[bot]`, with no reporter identity attached.

GitHub stores dispatch input/event data and public issues under its own retention and access policies. A public issue can outlive an account or be copied by others. The privacy notice and confirmation explicitly disclose this; operators must provide a contact and process for sensitive content removal before production release.
