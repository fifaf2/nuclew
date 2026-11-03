from __future__ import annotations

import os
from sqlalchemy.engine import URL

DATABASE_URL = os.getenv("DATABASE_URL") or URL.create(
    "mysql+pymysql",
    username=os.getenv("MYSQL_USER", "nuclew"),
    password=os.getenv("MYSQL_PASSWORD", "nuclew"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "3306")),
    database=os.getenv("MYSQL_DATABASE", "knowledge_base_db"),
    query={"charset": "utf8mb4"},
)

JWT_SECRET = os.getenv("JWT_SECRET", "change-me-before-deployment")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "1440"))

SUPPORT_USER_IDS = {
    int(value)
    for value in os.getenv("SUPPORT_USER_IDS", "").split(",")
    if value.strip().isdigit()
}
