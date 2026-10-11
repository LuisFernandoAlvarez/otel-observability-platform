import os
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import SessionLocal, Item, Base, engine
from app.otel import configure_otel, logger, tracer

configure_otel(os.getenv("SERVICE_NAME", "service-a"))

app = FastAPI(title="service-a")

from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
FastAPIInstrumentor.instrument_app(app)


class OrderRequest(BaseModel):
    customer: str
    item: str
    quantity: int
    amount: float


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "service-a"}


@app.get("/items")
def list_items() -> list[dict[str, Any]]:
    with SessionLocal() as session:
        rows = session.query(Item).all()
        return [{"id": row.id, "item": row.item, "quantity": row.quantity, "amount": row.amount} for row in rows]


@app.post("/process")
def process_order(order: OrderRequest) -> dict[str, Any]:
    if order.quantity <= 0:
        raise HTTPException(status_code=400, detail="quantity must be positive")

    with tracer.start_as_current_span("service_a.process_order") as span:
        span.set_attribute("customer", order.customer)
        span.set_attribute("item", order.item)
        span.set_attribute("quantity", order.quantity)
        total = float(order.amount) * float(order.quantity)

        with tracer.start_as_current_span("service_a.calculate_total"):
            span_total = total * 1.08
            logger.info("order_total_calculated", extra={"customer": order.customer, "total": span_total})

        with SessionLocal() as session:
            db_row = Item(item=order.item, quantity=order.quantity, amount=float(total))
            session.add(db_row)
            session.commit()
            session.refresh(db_row)

        downstream_url = os.getenv("SERVICE_B_URL", "http://service-b:8000")
        import requests
        downstream_payload = {
            "customer": order.customer,
            "item": order.item,
            "quantity": order.quantity,
            "amount": float(total),
        }
        with tracer.start_as_current_span("service_a.call_service_b"):
            response = requests.post(f"{downstream_url}/ingest", json=downstream_payload, timeout=5)
            response.raise_for_status()

        logger.info(
            "service_a_order_processed",
            extra={"customer": order.customer, "item": order.item, "total": round(span_total, 2), "db_id": db_row.id},
        )

        return {
            "status": "processed",
            "service": "service-a",
            "customer": order.customer,
            "item": order.item,
            "quantity": order.quantity,
            "amount": round(float(total), 2),
            "total_with_tax": round(span_total, 2),
            "db_id": db_row.id,
            "downstream_status": response.status_code,
        }


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "service-a", "status": "ok"}
