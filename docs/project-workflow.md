# Project workflow

This document describes how the [slack-status-cli](https://github.com/users/efmcuiti/projects/2/views/1) GitHub Project is managed. The project began life as the Pi-Pod Refactor; post-v1 it runs the maintenance workflow described at the end of this file.

## Labels are the single source of truth

Issue labels carry all pod/size/phase/type/tdd metadata. The **Project** sidebar tracks only workflow state (Status).

| Label prefix | Example | Meaning |
|---|---|---|
| `pod:` | `pod:foundation` | Which refactor pod owns this issue |
| `size:` | `size:s` | PR size estimate (s / m / l) |
| `phase:` | `phase:extraction` | Refactor phase (bootstrap / foundation / extraction / cleanup) |
| `type:` | `type:task` | Granularity: `type:epic` vs `type:task` |
| `tdd:` | `tdd:red-gate` | Has at least one `/ruby-dev` shipit gate |

**Do not recreate Pod, Size, or Phase as custom project fields.** They duplicate labels and will drift out of sync because GitHub does not link labels to custom field values.

## Project fields

Only the built-in **Status** field is used on project items:

| Value | Meaning |
|---|---|
| Todo | Not yet started |
| In Progress | Actively being worked |
| Done | Merged / closed |

Project field IDs (for agent automation):

| Field | ID |
|---|---|
| Project node | `PVT_kwHOABIV3s4BYb61` |
| Status field | `PVTSSF_lAHOABIV3s4BYb61zhThzys` |
| Status → Todo | `f75ad846` |
| Status → In Progress | `47fc9ee4` |
| Status → Done | `98236657` |

## Filtering by label

The table view supports `label:` qualifiers directly in the search bar. Useful filters:

```
label:phase:foundation
label:phase:extraction
label:pod:slack
label:pod:foundation
label:tdd:red-gate
label:size:l
label:phase:extraction label:pod:cli
```

Combine with `status:` to narrow further: `label:pod:foundation status:"In Progress"`.

## Project views — setup

**Table view (primary):** Enable the built-in **Labels** column via *View → Fields → Labels*. Place it after Title/Status so pod/size/phase labels are visible without opening each issue.

**Optional saved views:**

| View name | Filter |
|---|---|
| Foundation | `label:phase:foundation` |
| Extraction | `label:phase:extraction` |
| Cleanup | `label:phase:cleanup` |
| Red gates | `label:tdd:red-gate` |
| By pod: Slack | `label:pod:slack` |

## Agent lifecycle per task

When an agent picks up a task issue (the `/ruby-dev` skill drives this), the lifecycle is:

**On start (pre-flight housekeeping):**

1. Assign the issue: `gh issue edit N --add-assignee efmcuiti --repo efmcuiti/slack-status-cli`
2. Set Status to In Progress via GraphQL (`updateProjectV2ItemFieldValue`, Status field + option `47fc9ee4` — see the recipe below).
3. Create branch with naming convention `em/<issue#>_<task_slug>`.
4. **Cascade the parent epic:** if the task's parent epic (see Native issue relationships below) is still Todo, move it to In Progress and assign it to `efmcuiti`.

**During work:**

5. Tick acceptance checkboxes as they clear: `gh issue edit N --body-file <updated>`. Only tick boxes that are genuinely verified; never tick an unverifiable manual-only item (surface it for a human instead).
6. Open a draft PR assigned to `efmcuiti` with `Closes #N` in the body, pre-checking the test-plan boxes that are already proven.

**On close-out (only when asked to merge/complete):**

7. Final checkbox sweep on the issue and PR.

   7a. **Manual-smoke gate:** scan PR + issue for an unchecked manual/unverifiable box; if present, get an explicit Hold/Skip decision before merging (see "Manual-smoke close-out gate" below).
8. Squash-merge + delete branch: `gh pr merge N --repo efmcuiti/slack-status-cli --squash --delete-branch`.
9. Set the task Status to Done (option `98236657`).
10. Sync local main: `git checkout main && git pull --ff-only`.
11. **Cascade the parent epic:** if every sibling sub-issue is now closed, tick the epic's boxes, set the epic Status to Done, and close it.

Do **not** set Pod, Size, or Phase fields — they no longer exist on the project.

## Native issue relationships (sub-issues & dependencies)

Issues use GitHub's **native sub-issues and dependencies**, so parent/child and blocked-by relationships can be read from the API rather than parsed from markdown.

**Parent epic of a task** (`parent_issue_url` — the trailing number is the epic):

```bash
gh api repos/efmcuiti/slack-status-cli/issues/<N> --jq .parent_issue_url
# -> https://api.github.com/repos/efmcuiti/slack-status-cli/issues/12   (epic = #12)
```

**Is a task blocked?** (skip blocked tasks when selecting the next workable item):

```bash
gh api repos/efmcuiti/slack-status-cli/issues/<N> --jq .issue_dependencies_summary.blocked_by
# 0 = unblocked; >0 = blocked
```

**Is an epic complete?** (last-task detection during close-out):

```bash
# Quick summary — done when completed == total:
gh api repos/efmcuiti/slack-status-cli/issues/<EPIC> --jq .sub_issues_summary
# { "total": 5, "completed": 5, "percent_completed": 100 }

# Per-child detail — complete when every state == "closed":
gh api repos/efmcuiti/slack-status-cli/issues/<EPIC>/sub_issues --jq '[.[] | {number, state}]'
```

## Status field mutations (GraphQL recipes)

The project's **Status does not auto-sync** with issue open/closed state — there is no project workflow automation configured, so closing an issue (even via `Closes #N` on merge) leaves its Status untouched. The agent must set Status explicitly with the mutation below.

First resolve the project item node ID for an issue number:

```bash
gh project item-list 2 --owner efmcuiti --format json --limit 50 \
  | jq -r '.items[] | select(.content.number == <N>) | .id'
```

Then set the Status field (swap in the option ID for the target column):

```bash
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "PVT_kwHOABIV3s4BYb61"
      itemId: "<ITEM_NODE_ID>"
      fieldId: "PVTSSF_lAHOABIV3s4BYb61zhThzys"
      value: { singleSelectOptionId: "<OPTION_ID>" }
    }) { projectV2Item { id } }
  }'
# OPTION_ID: Todo = f75ad846, In Progress = 47fc9ee4, Done = 98236657
```

## PR review response (Copilot)

Every PR in this project is reviewed by GitHub Copilot, which leaves inline review comments and re-reviews on each push. These are the exact recipes the `/ruby-dev` **PR Review Response Loop** (Step 12) uses — use them verbatim instead of re-deriving the API filters each session.

**Bot identities (they differ by context):**

| Context | Login |
|---|---|
| Inline review comment author | `Copilot` |
| Requested reviewer (for re-request) | `copilot-pull-request-reviewer[bot]` |

**1. List open (unaddressed) inline comments** — top-level only, oldest first; replies have a non-null `in_reply_to_id` and are filtered out:

```bash
gh api 'repos/efmcuiti/slack-status-cli/pulls/<N>/comments?sort=created&direction=asc&per_page=100' \
  --jq '.[] | select(.in_reply_to_id==null) | "id=\(.id)\t\(.path):\(.line // .original_line)\t\(.user.login)\n\(.body)\n"'
```

To see review summary bodies (the "Copilot reviewed N changed files" verdicts):

```bash
gh api repos/efmcuiti/slack-status-cli/pulls/<N>/reviews \
  --jq '.[] | select(.user.login | test("[Cc]opilot")) | "\(.submitted_at)\t\(.state)\n\(.body)\n"'
```

**2. Reply to a comment** — post after the fix is committed and pushed, citing the commit SHA:

```bash
gh api repos/efmcuiti/slack-status-cli/pulls/<N>/comments/<COMMENT_ID>/replies \
  -f body="Good catch — fixed in <SHA>. <one-line explanation>."
```

**3. Fetch review-thread IDs + resolution state** (REST comments have no thread ID; you need GraphQL):

```bash
gh api graphql -f query='
{
  repository(owner: "efmcuiti", name: "slack-status-cli") {
    pullRequest(number: <N>) {
      reviewThreads(first: 50) {
        nodes { id isResolved path comments(first: 1) { nodes { author { login } body } } }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | "\(.id)\t\(.isResolved)\t\(.path)\t\(.comments.nodes[0].author.login)"'
```

**4. Resolve a thread** once its comment is addressed and replied to:

```bash
gh api graphql -f query='mutation { resolveReviewThread(input: { threadId: "<PRRT_...>" }) { thread { isResolved path } } }'
```

**5. Re-request Copilot review** — LAST, only after every comment in the round is fixed, pushed, replied to, and resolved:

```bash
gh api repos/efmcuiti/slack-status-cli/pulls/<N>/requested_reviewers \
  -X POST -f "reviewers[]=copilot-pull-request-reviewer[bot]"
```

**Close-out gate:** before the Step 8 merge, re-run recipe 3 — if any thread shows `isResolved=false`, the review loop is not done.

## Manual-smoke close-out gate

At close-out (Step 7a, before the Step 8 merge), a manual/unverifiable checkbox left unchecked must never be silently merged past — this is what let PR #75's live-Slack smoke box slip through. Detect it, then get an explicit Hold/Skip decision from the user.

**1. Detect an unchecked manual/unverifiable box** across both the PR and issue bodies (deduped):

```bash
# Non-empty output => an unchecked manual/unverifiable box exists; run the gate before merging.
{ gh pr view <PR> --json body --jq .body; gh issue view <N> --json body --jq .body; } \
  | grep -E '^[[:space:]]*- \[ \]' \
  | grep -iE 'smoke|manual|live token|real token|hardware|browser|Music\.app|verified manually' \
  | sort -u
```

Any unchecked box inside a `Recommended manual smoke steps` collapsible also counts, even if its wording misses the keywords above.

**2a. Hold & run the smoke test** — do **not** merge or set Status → Done. Re-surface the derived smoke script from the PR collapsible and wait. When the user reports it passed, re-run the Step 7 close-out sweep from the top, tick the box `(verified manually by @efmcuiti)`, then merge.

**2b. Skip & close (waived)** — leave the box unchecked (never tick an unverified item), but annotate it inline so the conscious skip is on the record, then proceed to merge:

```bash
# Append the waiver note to the matched box line, then push the edited body.
gh pr view <PR> --json body --jq .body > /tmp/body.md
# edit /tmp/body.md: append " (waived by @efmcuiti at close — not run)" to the matched "- [ ]" line
gh pr edit <PR> --body-file /tmp/body.md
# repeat with `gh issue view/edit <N>` when the same box lives on the issue
```

## Maintenance workflow (post-v1)

Once v1.0 ships, this project runs the **maintenance mode** defined generically in the `rails-sdlc` skill's `MAINTENANCE.md` (the model, taxonomy, triage table, and command procedures live there). This section records only the slack-status-cli specifics.

### Window model

A **milestone is the time-boxed window** — issues are scheduled into it and it closes at each release:

- Milestone naming is **version-based**: `v1.1`, `v1.2`, ... (a window = "what goes into the next release").
- **No milestone = the triage inbox** — a freshly filed ask sits milestone-less until triaged; assigning a milestone *is* the act of scheduling it.
- `type:epic` is reserved for large features that earn a `/rails-sdlc` breakdown; everything else is a standalone typed issue (below). Milestone and epic are orthogonal — a feature epic's tasks all carry the same milestone.

### Taxonomy additions

On top of the refactor taxonomy, maintenance adds three directly-executable issue types:

| Label | Meaning |
|---|---|
| `type:bug` | Defect against shipped behavior (reproduce-first under `/ruby-dev`) |
| `type:enhancement` | Small improvement / feature ask |
| `type:chore` | Deps, CI, docs, no-behavior-change refactor |

`phase:*` labels are **retired for standalone maintenance issues** (the milestone is the grouping now); they reappear only inside an escalated `/rails-sdlc` feature epic.

### Triage routing

Every intake is classified once:

- **Directly executable** (one PR, clear approach, no open questions) → `/ruby-dev` (most bugs, chores, small enhancements).
- **Needs design** (open questions, >1 substantial class, an "and" in the title, `size:l` not dominated by one hard problem, architectural impact) → `/rails-sdlc` scoped to that single feature (Discovery → Design → Planning), whose tasks flow back to `/ruby-dev`.

### Commands

Day-to-day maintenance is driven by the `rails-sdlc` verbs:

- `/rails-sdlc maintenance setup` — idempotent: ensure the labels above, open the next `vX.Y` milestone, keep this section current.
- `/rails-sdlc maintenance create <bug|enhancement|chore> <context>` — plan mode + `/grill-me` to clarify and triage, then file + route on approval.
- `/rails-sdlc maintenance close-window` — at each release: roll open survivors forward to the next milestone, then close the current one.

### Saved views (manual Projects-v2 UI step)

The project board is not scripted for these; add them once via the Projects UI:

- **Inbox** — filter `no:milestone` (untriaged asks awaiting a window).
- **Current window** — filter `milestone:"v1.1"` (swap per active window).

### Close-out / roll-over recipe

```bash
CUR=v1.1; NEXT=v1.2
# 1. ensure NEXT exists
gh api "repos/efmcuiti/slack-status-cli/milestones" --jq '.[].title' | grep -qx "$NEXT" \
  || gh api "repos/efmcuiti/slack-status-cli/milestones" -f title="$NEXT" -f description="Maintenance window $NEXT"
# 2. roll open survivors forward
gh issue list --repo efmcuiti/slack-status-cli --milestone "$CUR" --state open --json number --jq '.[].number' \
  | xargs -I{} gh issue edit {} --repo efmcuiti/slack-status-cli --milestone "$NEXT"
# 3. close the current milestone
NUM=$(gh api "repos/efmcuiti/slack-status-cli/milestones" --jq ".[] | select(.title==\"$CUR\") | .number")
gh api -X PATCH "repos/efmcuiti/slack-status-cli/milestones/$NUM" -f state=closed
```
