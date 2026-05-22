# Project workflow

This document describes how the [Slack CLI Pi-Pod Refactor](https://github.com/users/efmcuiti/projects/2/views/1) GitHub Project is managed.

## Labels are the single source of truth

Issue labels carry all pod/size/phase/type/tdd metadata. The **Project** sidebar tracks only workflow state (Status).

| Label prefix | Example | Meaning |
|---|---|---|
| `pod:` | `pod:foundation` | Which refactor pod owns this issue |
| `size:` | `size:s` | PR size estimate (s / m / l) |
| `phase:` | `phase:extraction` | Refactor phase (bootstrap / foundation / extraction / cleanup) |
| `type:` | `type:task` | Granularity: `type:epic` vs `type:task` |
| `tdd:` | `tdd:red-gate` | Has at least one `/pi-dev` shipit gate |

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

## Agent housekeeping per task

When an agent picks up a task issue, the required steps are:

1. Assign the issue: `gh issue edit N --add-assignee efmcuiti --repo efmcuiti/slack-status-cli`
2. Set Status to In Progress via GraphQL (`updateProjectV2ItemFieldValue`, Status field + option `47fc9ee4`)
3. Create branch with naming convention `em/<issue#>_<task_slug>`
4. Tick acceptance checkboxes as they clear: `gh issue edit N --body "<updated body>"`
5. Open draft PR assigned to `efmcuiti` with `Closes #N` in the body

Do **not** set Pod, Size, or Phase fields — they no longer exist on the project.
