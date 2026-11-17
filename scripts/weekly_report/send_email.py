"""Send the weekly HTML report using Gmail SMTP."""

import os
import smtplib

from datetime import datetime
from email.message import EmailMessage
from pathlib import Path
from zoneinfo import ZoneInfo


def main() -> None:
    sender = os.environ["SMTP_EMAIL"].strip()
    password = os.environ["SMTP_PASSWORD"]

    recipients = [
        email.strip()
        for email in os.environ["REPORT_EMAIL_TO"].split(",")
        if email.strip()
    ]

    if not recipients:
        raise ValueError(
            "REPORT_EMAIL_TO must contain at least one email"
        )

    html = Path(
        "reports/weekly/WEEKLY_REPORT.html"
    ).read_text(encoding="utf-8")

    markdown = Path(
        "reports/weekly/WEEKLY_REPORT.md"
    ).read_text(encoding="utf-8")

    repository = os.environ["GITHUB_REPOSITORY"]
    run_id = os.environ["GITHUB_RUN_ID"]

    run_url = (
        f"https://github.com/{repository}/actions/runs/{run_id}"
    )

    date = datetime.now(
        ZoneInfo("America/Sao_Paulo")
    ).strftime("%d/%m/%Y")

    message = EmailMessage()

    message["Subject"] = (
        f"OpenLift | Relatório semanal - {date}"
    )

    message["From"] = sender
    message["To"] = sender

    # Send to team members using blind carbon copy.
    message["Bcc"] = ", ".join(recipients)

    message.set_content(
        markdown
        + "\n\nRelatório completo e artifacts:\n"
        + run_url
    )

    html_body = html.replace(
        "</body>",
        (
            '<p style="text-align:center;margin:20px">'
            f'<a href="{run_url}">'
            "Abrir relatório completo no GitHub"
            "</a></p></body>"
        ),
    )

    message.add_alternative(
        html_body,
        subtype="html",
    )

    with smtplib.SMTP_SSL(
        "smtp.gmail.com",
        465,
        timeout=30,
    ) as smtp:
        smtp.login(sender, password)
        smtp.send_message(message)

    print(
        f"Weekly report sent to "
        f"{len(recipients)} recipient(s)"
    )


if __name__ == "__main__":
    main()