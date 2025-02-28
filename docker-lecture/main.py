from fastapi import FastAPI, HTTPException
import asyncpg
import os

app = FastAPI()

DB_URL = os.getenv("DB_URL")


async def init_db():
    conn = await asyncpg.connect(DB_URL)
    try:
        await conn.execute('''CREATE TABLE IF NOT EXISTS products (
            name TEXT,
            price NUMERIC,
            description TEXT,
            article VARCHAR(255)
        )''')
        await conn.execute('''INSERT INTO products (name, price, description, article) VALUES
            ('Google Pixel', 37000, 'Описание Google Pixel', 'GPX123'),
            ('Redmi', 10000, 'Описание Redmi', 'RDM456'),
            ('Samsung Galaxy', 60000, 'Описание Samsung Galaxy', 'SGZ789');
        ''')
    finally:
        await conn.close()


async def get_products():
    conn = await asyncpg.connect(DB_URL)
    rows = await conn.fetch('SELECT * FROM products')
    await conn.close()
    return rows


@app.on_event("startup")
async def startup_event():
    await init_db()

    
@app.get("/products", response_model=list[dict])
async def read_products():
    products = await get_products()
    if not products:
        raise HTTPException(status_code=404, detail="No products found")
    return [dict(p) for p in products]

