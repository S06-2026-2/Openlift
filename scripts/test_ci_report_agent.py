"""Regression tests for the CI report agent's model fallback behavior."""

import io
import json

import ci_report_agent


def test_generate_report_falls_back_after_malformed_json(
    monkeypatch,
) -> None:
    responses = iter(
        [
            io.BytesIO(b"not valid json"),
            io.BytesIO(
                json.dumps(
                    {
                        "candidates": [
                            {"content": {"parts": [{"text": "Fallback report"}]}}
                        ]
                    }
                ).encode("utf-8")
            ),
        ]
    )
    attempted_models = []

    def fake_urlopen(request, timeout):
        attempted_models.append(request.full_url.rsplit("/", 1)[-1].split(":", 1)[0])
        return next(responses)

    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(ci_report_agent.urllib.request, "urlopen", fake_urlopen)

    report = ci_report_agent.generate_report("instructions", "evidence")

    assert attempted_models == ci_report_agent.MODELS[:2]
    assert report == "Fallback report"
