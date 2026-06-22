"""Application settings, loaded from the repo-root .env via pydantic-settings."""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# config.py -> core -> app -> backend -> <repo root>
ROOT_DIR = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ROOT_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    app_env: str = "dev"

    # Backend (FastAPI)
    backend_host: str = "0.0.0.0"
    backend_port: int = 8000
    cors_origins: str = "http://localhost:5173"

    # GCP
    gcp_project_id: str = ""
    gcp_region: str = "southamerica-east1"
    gcp_dataset: str = "clai"
    gcs_bucket: str = "clai-dev"
    firestore_database: str = "(default)"

    # Gemini
    use_vertex: bool = False
    gemini_api_key: str = ""
    gemini_model_fast: str = "gemini-2.5-flash"
    gemini_model_lite: str = "gemini-2.5-flash-lite"

    # Vertex AI Vector Search
    vertex_index_id: str = ""
    vertex_index_endpoint_id: str = ""
    vertex_deployed_index_id: str = "clai_index"

    # Isolamento de dados de dev
    dev_namespace: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
