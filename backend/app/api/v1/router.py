"""Agrega os routers de endpoints da API v1."""

from fastapi import APIRouter

from app.api.v1.endpoints import health

api_router = APIRouter()
api_router.include_router(health.router)

# Routers dos módulos (a implementar): planning, works, fieldwork, closing, fup.
