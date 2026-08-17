"""Pydantic schemas for the health records API."""

from pydantic import BaseModel, Field


class HealthRecordIn(BaseModel):
    type: str
    value: float
    unit: str = ""
    date_from: str
    date_to: str


class UploadBatch(BaseModel):
    source: str = "unknown"
    records: list[HealthRecordIn] = Field(default_factory=list)


class SummaryParams(BaseModel):
    types: list[str] | None = None
    group_by: str = "type"