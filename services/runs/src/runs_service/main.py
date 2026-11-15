from fastapi import FastAPI


def create_app() -> FastAPI:
    """Build the application. A function (not a global) so tests can create a fresh app each time."""
    app = FastAPI(
        title="Runs service",
        version="0.1.0",
        docs_url="/v1/docs",
        openapi_url="/v1/openapi.json",
    )

    @app.get("/v1/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "runs"}

    return app


app = create_app()
