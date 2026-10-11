import os
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db import SessionLocal, Item, Base, engine
from app.otel import configure_otel, logger, tracer

configure_otel(os.getenv("SERVICE_NAME", "service-b"))

app = FastAPI(title="service-b")

from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
FastAPIInstrumentor.instrument_app(app)


class IngestRequest(BaseModel):
    customer: str
    item: str
    quantity: int
    amount: float


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "service-b"}


@app.get("/items")
def list_items() -> list[dict[str, Any]]:
    with SessionLocal() as session:
        rows = session.query(Item).all()
        return [{"id": row.id, "item": row.item, "quantity": row.quantity, "amount": row.amount} for row in rows]


@app.post("/ingest")
def ingest_order(order: IngestRequest) -> dict[str, Any]:
    if order.quantity <= 0:
        raise HTTPException(status_code=400, detail="quantity must be positive")

    with tracer.start_as_current_span("service_b.process_ingest") as span:
        span.set_attribute("customer", order.customer)
        span.set_attribute("item", order.item)
        span.set_attribute("quantity", order.quantity)

        with tracer.start_as_current_span("service_b.calculate_order_value"):
            normalized_amount = float(order.amount) * 1.05
            logger.info("downstream_order_value", extra={"customer": order.customer, "value": normalized_amount})

        with SessionLocal() as session:
            db_row = Item(item=order.item, quantity=order.quantity, amount=float(normalized_amount))
            session.add(db_row)
            session.commit()
            session.refresh(db_row)

        logger.info(
            "service_b_order_ingested",
            extra={"customer": order.customer, "item": order.item, "db_id": db_row.id, "value": round(normalized_amount, 2)},
        )

        return {
            "status": "ingested",
            "service": "service-b",
            "customer": order.customer,
            "item": order.item,
            "quantity": order.quantity,
            "amount": round(normalized_amount, 2),
            "db_id": db_row.id,
        }


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "service-b", "status": "ok"}
