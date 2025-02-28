package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

var db *sql.DB

type Product struct {
	Name        string  `json:"name"`
	Price       float64 `json:"price"`
	Description string  `json:"description"`
	Article     string  `json:"article"`
}

func initDB() {
	query := `
        CREATE TABLE IF NOT EXISTS products (
            name TEXT,
            price NUMERIC,
            description TEXT,
            article VARCHAR(255)
        );
    `
	_, err := db.Exec(query)
	if err != nil {
		log.Fatalf("Ошибка при создании таблицы: %v\n", err)
	}

	insertQuery := `
        INSERT INTO products (name, price, description, article) VALUES
            ('Google Pixel', 37000, 'Описание Google Pixel', 'GPX123'),
            ('Redmi', 10000, 'Описание Redmi', 'RDM456'),
            ('Samsung Galaxy', 60000, 'Описание Samsung Galaxy', 'SGZ789')
        ON CONFLICT DO NOTHING;
    `
	_, err = db.Exec(insertQuery)
	if err != nil {
		log.Fatalf("Ошибка при вставке данных: %v\n", err)
	}
}

func getProducts(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT name, price, description, article FROM products")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var products []Product
	for rows.Next() {
		var p Product
		if err := rows.Scan(&p.Name, &p.Price, &p.Description, &p.Article); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		products = append(products, p)
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(products); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println(".env file not found, using env vars")
	}

	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		log.Fatal("DATABASE_URL env var is not set")
	}

	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("DB connection error: %v\n", err)
	}
	defer db.Close()

	initDB()

	http.HandleFunc("/products", getProducts)
	log.Println("Server is listening on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
