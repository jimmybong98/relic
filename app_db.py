import os
from typing import List, Dict, Any

from fastapi import FastAPI, HTTPException, Query
import mysql.connector

app = FastAPI(title="Relic Quality Reports")


def get_connection():
    """Create a database connection using environment variables."""
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "relic_quality"),
    )


@app.get("/reports", response_model=List[Dict[str, Any]])
def read_reports(view: str = Query("vw_reports", description="Database view to read")):
    """Fetch records from the specified SQL view and return them as a list of dicts."""
    try:
        conn = get_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(f"SELECT * FROM {view}")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return rows
    except mysql.connector.Error as exc:
        raise HTTPException(status_code=500, detail=str(exc))
