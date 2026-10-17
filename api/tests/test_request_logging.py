import logging

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.logging import configure_logging
from app.core.middleware import RequestLoggingMiddleware


@pytest.fixture
def client():
    configure_logging()

    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/test")
    def test_endpoint():
        return {"message": "ok"}

    return TestClient(app)


def test_successful_request_is_logged(client, caplog):
    with caplog.at_level(logging.INFO):
        response = client.get("/test")

    assert response.status_code == 200

    assert any(
        "http_request_completed" in record.message and '"status_code": 200' in record.message
        for record in caplog.records
    )


def test_not_found_request_is_logged(client, caplog):
    with caplog.at_level(logging.INFO):
        response = client.get("/not-found")

    assert response.status_code == 404

    assert any(
        "http_request_completed" in record.message and '"status_code": 404' in record.message
        for record in caplog.records
    )
