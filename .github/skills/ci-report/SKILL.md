---
name: ci-report
description: Analyze OpenLift CI results and generate a concise Markdown report about code quality, tests, coverage, and detected failures.
---

# OpenLift CI Report Skill

Analyze the Continuous Integration results of the OpenLift project.

## Responsibilities

1. Analyze the available CI results.
2. Identify successful and failed checks.
3. Summarize backend static analysis results.
4. Summarize backend and frontend test results.
5. Report code coverage when coverage data is available.
6. Explain relevant failures in clear technical language.
7. Suggest actions for problems detected by the pipeline.

## Backend checks

Analyze results from:

- Ruff
- Black
- MyPy
- Pytest
- Pytest coverage

## Frontend checks

Analyze results from:

- Flutter Analyze
- Flutter Test
- Flutter coverage

## Rules

- Never invent test results.
- Never invent coverage values.
- Clearly state when information is unavailable.
- Do not modify source code.
- Do not determine whether a pull request should be merged.
- CI tools remain responsible for determining pipeline success or failure.
- Recommendations must be based only on the provided CI results.

## Output

Generate a Markdown report with the following structure:

# OpenLift CI Report

## Pipeline Summary

Provide a concise overview of the CI execution.

## Backend

Summarize static analysis, tests, and coverage.

## Frontend

Summarize static analysis, tests, and coverage.

## Problems Detected

Describe relevant failures or quality problems.

If no problems were detected, explicitly state that no problems were found.

## Recommendations

Provide concise technical recommendations based on the detected problems.