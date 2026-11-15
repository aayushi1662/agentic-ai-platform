from fastapi.testclient import TestClient
from runs_service.main import create_app


def test_health_returns_ok():
    client = TestClient(create_app())
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "runs"}


def test_unversioned_path_does_not_exist():
    client = TestClient(create_app())
    assert client.get("/health").status_code == 404
