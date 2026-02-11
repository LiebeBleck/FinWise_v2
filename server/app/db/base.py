from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import DeclarativeBase
from typing import Any

# SQLAlchemy 2.0 style base
class Base(DeclarativeBase):
    """Base class for all database models"""
    pass

# For backward compatibility
metadata = Base.metadata
