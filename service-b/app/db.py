from sqlalchemy import Column, Float, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
import os

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:postgres@localhost:5432/service_b")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    item = Column(String, index=True)
    quantity = Column(Integer)
    amount = Column(Float)
