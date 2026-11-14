# Commands

Quick reference for running the pre-commit hooks and checking Checkov findings.
Run everything from the repo root (`encore-live-ops/`).

## Pre-commit

| What | Command |
|---|---|
| Run all hooks on **staged** files (same as `git commit`) | `pre-commit run` |
| Run all hooks on **every** file | `pre-commit run --all-files` |
| Run all hooks on one file | `pre-commit run --files bootstrap/main.tf` |
| Run only Checkov | `pre-commit run terraform_checkov --all-files` |
| Run only fmt | `pre-commit run terraform_fmt --all-files` |
| Run only validate | `pre-commit run terraform_validate --all-files` |
| Run only tflint | `pre-commit run terraform_tflint --all-files` |
| Update hook versions in the config | `pre-commit autoupdate` |
| Clear pre-commit's cache | `pre-commit clean` |

> Hooks only check **staged** files unless you pass `--all-files` or `--files`.
> If fmt rewrites a file, `git add` it again before re-running.

## Checkov (run directly, for reading findings)

Running Checkov directly is easier to read than the pre-commit output.

| What | Command |
|---|---|
| Scan the bootstrap folder | `checkov -d bootstrap` |
| Failed checks only, no code snippets | `checkov -d bootstrap --compact --quiet` |
| Check a single rule | `checkov -d bootstrap --check CKV_AWS_21` |
| Save results as JSON | `checkov -d bootstrap -o json > checkov.json` |

Each finding has a `Guide:` link that explains the rule and shows how to fix it.

### Suppressing a check (with a reason)

Put this inline comment inside the resource block:

```hcl
# checkov:skip=CKV_AWS_144:Reason why this check does not apply here
```

## Terraform (inside `bootstrap/`)

| What | Command |
|---|---|
| Download providers | `terraform init` |
| Check config is valid | `terraform validate` |
| Check formatting (no changes) | `terraform fmt -check` |
| Fix formatting | `terraform fmt` |

## Commit

| What | Command |
|---|---|
| Normal commit (runs all hooks) | `git commit -m "message"` |
| Skip only Checkov, once (PowerShell) | `$env:SKIP = "terraform_checkov"; git commit -m "message"; Remove-Item Env:SKIP` |
| Skip only Checkov, once (cmd) | `set SKIP=terraform_checkov && git commit -m "message" && set SKIP=` |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `'pre-commit' is not recognized` | Close **all** VS Code windows and reopen (PATH is read at startup). |
| `WSL ... execvpe(/bin/bash) failed` | Same as above: the terminal has an old PATH. Check with `where bash`. `C:\Program Files\Git\bin\bash.exe` must be listed first. |
| tflint hook fails with a Docker error | Start Docker Desktop. tflint runs in a container because Smart App Control blocks the unsigned `tflint.exe`. |
| `tflint` not found in PowerShell/cmd | Expected. It's a bash wrapper (`C:\Users\Steven\bin\tflint`), only usable from hooks or Git Bash. |
