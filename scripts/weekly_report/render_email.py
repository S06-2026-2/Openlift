
"""Render a readable, email-safe HTML version of the weekly Markdown report."""
from __future__ import annotations

import html
import re
from pathlib import Path

SOURCE = Path('reports/weekly/WEEKLY_REPORT.md')
DESTINATION = Path('reports/weekly/WEEKLY_REPORT.html')


def inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(
        r'\[([^\]]+)\]\((https?://[^\s)]+)\)',
        lambda m: (
            f'<a href="{html.unescape(m.group(2))}" '
            f'style="color:#147d84;text-decoration:underline">'
            f'{m.group(1)}</a>'
        ),
        escaped
    )
    escaped = re.sub(
        r'`([^`]+)`',
        r'<code style="background:#e9f0f1;padding:2px 4px;border-radius:3px">\1</code>',
        escaped
    )
    escaped = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', escaped)
    return escaped


def convert(markdown: str) -> str:
    output = []
    in_list = False

    for line in markdown.splitlines():
        stripped = line.strip()

        if not stripped:
            if in_list:
                output.append('</ul>')
                in_list = False
            continue

        heading = re.match(r'^(#{1,3})\s+(.+)$', stripped)
        bullet = re.match(r'^[-*]\s+(.+)$', stripped)

        if heading:
            if in_list:
                output.append('</ul>')
                in_list = False

            level = len(heading.group(1))
            size = {1: '24px', 2: '19px', 3: '16px'}[level]

            output.append(
                f'<h{level} style="font-size:{size};'
                f'color:#153542;margin:24px 0 10px">'
                f'{inline(heading.group(2))}</h{level}>'
            )

        elif bullet:
            if not in_list:
                output.append('<ul style="padding-left:22px;margin:10px 0">')
                in_list = True

            output.append(
                f'<li style="margin:7px 0">{inline(bullet.group(1))}</li>'
            )

        else:
            if in_list:
                output.append('</ul>')
                in_list = False

            output.append(
                f'<p style="margin:10px 0;line-height:1.65">'
                f'{inline(stripped)}</p>'
            )

    if in_list:
        output.append('</ul>')

    return '\n'.join(output)


def main() -> None:
    content = SOURCE.read_text(encoding='utf-8')
    body = convert(content)

    document = f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenLift | Relatório Semanal</title>
</head>
<body style="margin:0;background:#f2f5f6;font-family:Arial,Helvetica,sans-serif;color:#253c46">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f2f5f6">
<tr>
<td align="center" style="padding:30px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"
style="max-width:680px;background:#ffffff;border-radius:12px;overflow:hidden">

<tr>
<td style="background:#142b38;padding:30px 36px">
<div style="color:#ffffff;font-size:28px;font-weight:bold">OpenLift</div>
<div style="color:#c5d7df;font-size:15px;margin-top:8px">
Relatório semanal de desenvolvimento
</div>
</td>
</tr>

<tr>
<td style="padding:28px 36px;font-size:15px">
{body}
</td>
</tr>

<tr>
<td style="background:#edf3f4;padding:18px 36px;color:#58717b;font-size:12px">
Relatório gerado automaticamente pelo Weekly Project Report Agent.
</td>
</tr>

</table>
</td>
</tr>
</table>
</body>
</html>'''

    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    DESTINATION.write_text(document, encoding='utf-8')

    print(f'HTML generated: {DESTINATION}')


if __name__ == '__main__':
    main()
