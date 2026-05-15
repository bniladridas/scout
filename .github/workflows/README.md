# GitHub Workflows

This directory contains Scout's GitHub Actions workflows.

## PR readiness comments

`pr-check.yml` runs on pull requests with a `macos-latest` runner. It builds Scout, packages the DMG, verifies the DMG, and uploads a small `pr-ready` artifact with the run results and runner environment.

`pr-ready.yml` runs after `PR Check` completes. It downloads that artifact and creates or updates the `<!-- scout-pr-ready -->` pull request comment.

Because `pr-ready.yml` is triggered by `workflow_run`, GitHub uses the workflow file from the default branch. Changes to `pr-ready.yml` in a pull request will affect readiness comments only after those changes are merged to `main`.

The readiness comment labels the Actions machine as `Runner macOS` to avoid confusing it with a user's local Mac or Scout's runtime OS display.
