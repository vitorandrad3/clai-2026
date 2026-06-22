"""Endpoint de readiness sob /api/v1."""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/ping")
def ping() -> dict[str, str]:
    return {"message": "pong"}
