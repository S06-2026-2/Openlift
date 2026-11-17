import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

API = "https://api.github.com"
REPO = os.environ["GITHUB_REPOSITORY"]
TOKEN = os.environ["GITHUB_TOKEN"]


def github_get(endpoint, params=None):
    """Consulta uma coleção da API do GitHub, com paginação."""
    items = []
    page = 1

    while True:
        query = dict(params or {})
        query.update(per_page=100, page=page)
        url = f"{API}/repos/{REPO}/{endpoint}?"
        url += urllib.parse.urlencode(query)

        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {TOKEN}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )

        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.load(response)

        if isinstance(data, dict):
            data = data.get("workflow_runs", [])

        items.extend(data)

        if len(data) < 100:
            break

        page += 1

    return items


def parse_date(value):
    if not value:
        return None
    return datetime.fromisoformat(
        value.replace("Z", "+00:00")
    )


def in_period(value, start, end):
    date = parse_date(value)
    return date is not None and start <= date < end


def collect(start, end):
    since = start.isoformat().replace("+00:00", "Z")
    until = end.isoformat().replace("+00:00", "Z")

    # PRs fechados: filtrar por data real de merge.
    pulls = github_get(
        "pulls",
        {"state": "closed", "sort": "updated", "direction": "desc"},
    )
    merged = [
        {
            "number": pr["number"],
            "title": pr["title"],
            "url": pr["html_url"],
            "author": pr["user"]["login"],
            "merged_at": pr["merged_at"],
            "body": (pr.get("body") or "")[:3000],
        }
        for pr in pulls
        if pr["base"]["ref"] == "main"
        and in_period(pr.get("merged_at"), start, end)
    ]

    # Issues: o endpoint também retorna PRs.
    issues = github_get(
        "issues",
        {"state": "all", "sort": "updated", "direction": "desc"},
    )
    issues = [
        issue for issue in issues
        if "pull_request" not in issue
    ]

    opened = [
        {
            "number": issue["number"],
            "title": issue["title"],
            "url": issue["html_url"],
        }
        for issue in issues
        if in_period(issue["created_at"], start, end)
    ]

    closed = [
        {
            "number": issue["number"],
            "title": issue["title"],
            "url": issue["html_url"],
        }
        for issue in issues
        if in_period(issue.get("closed_at"), start, end)
    ]

    commits = github_get(
        "commits",
        {"sha": "main", "since": since, "until": until},
    )
    commits = [
        {
            "sha": commit["sha"],
            "message": commit["commit"]["message"].splitlines()[0],
            "url": commit["html_url"],
        }
        for commit in commits
    ]

    runs = github_get(
        "actions/runs",
        {"branch": "main", "created": f"{start.date()}..{end.date()}"},
    )
    runs = [
        {
            "name": run["name"],
            "conclusion": run["conclusion"],
            "url": run["html_url"],
            "created_at": run["created_at"],
        }
        for run in runs
        if in_period(run["created_at"], start, end)
        and run["status"] == "completed"
    ]

    return {
        "repository": REPO,
        "period": {
            "start": since,
            "end_exclusive": until,
        },
        "summary": {
            "merged_prs": len(merged),
            "opened_issues": len(opened),
            "closed_issues": len(closed),
            "commits": len(commits),
            "completed_workflows": len(runs),
            "failed_workflows": sum(
                r["conclusion"] == "failure" for r in runs
            ),
        },
        "merged_pull_requests": merged,
        "opened_issues": opened,
        "closed_issues": closed,
        "commits": commits,
        "workflow_runs": runs,
    }


def main():
    now = datetime.now(timezone.utc)

    # Janela padrão: últimos 7 dias.
    end = datetime.fromisoformat(
        os.environ["REPORT_END"].replace("Z", "+00:00")
    ) if os.getenv("REPORT_END") else now

    start = end - timedelta(days=7)

    report = collect(start, end)

    output = Path("reports/weekly")
    output.mkdir(parents=True, exist_ok=True)

    destination = output / "weekly-data.json"
    destination.write_text(
        json.dumps(report, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(json.dumps(report["summary"], indent=2))
    print(f"Saved: {destination}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Collection failed: {exc}", file=sys.stderr)
        sys.exit(1)
