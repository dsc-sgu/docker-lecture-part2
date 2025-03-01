package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Привет, мир!")
	})

	fmt.Println("Server running on :8080")
	http.ListenAndServe(":8080", nil)
}
