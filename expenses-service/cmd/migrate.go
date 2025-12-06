package main

import (
	"database/sql"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: .env file not found")
	}

	// Connect to postgres database first to create our target database
	postgresURL := "postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable"
	if dbURL := os.Getenv("POSTGRES_URL"); dbURL != "" {
		postgresURL = dbURL
	}

	db, err := sql.Open("postgres", postgresURL)
	if err != nil {
		log.Fatalf("Failed to connect to postgres database: %v", err)
	}
	defer db.Close()

	// Create the expenses_service_db database if it doesn't exist
	_, err = db.Exec("CREATE DATABASE expenses_service_db")
	if err != nil {
		// Database might already exist, that's okay
		log.Printf("Database creation result: %v", err)
	} else {
		log.Println("Database expenses_service_db created successfully")
	}

	// Now connect to our target database
	targetURL := "postgresql://postgres:postgres@localhost:5432/expenses_service_db?sslmode=disable"
	if dbURL := os.Getenv("DATABASE_URL"); dbURL != "" {
		targetURL = dbURL
	}

	targetDB, err := sql.Open("postgres", targetURL)
	if err != nil {
		log.Fatalf("Failed to connect to target database: %v", err)
	}
	defer targetDB.Close()

	if err := targetDB.Ping(); err != nil {
		log.Fatalf("Failed to ping target database: %v", err)
	}

	// Create migrations tracking table (drop first to avoid conflicts)
	_, err = targetDB.Exec(`DROP TABLE IF EXISTS schema_migrations`)
	if err != nil {
		log.Printf("Warning: Failed to drop existing migrations table: %v", err)
	}
	
	_, err = targetDB.Exec(`
		CREATE TABLE schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		log.Fatalf("Failed to create migrations table: %v", err)
	}

	// Run all migrations
	if err := runAllMigrations(targetDB); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	log.Println("Database setup completed!")
}

func runAllMigrations(db *sql.DB) error {
	// Read migration files
	files, err := ioutil.ReadDir("migrations")
	if err != nil {
		return err
	}

	// Filter and sort .up.sql files
	var upFiles []string
	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".up.sql") {
			upFiles = append(upFiles, file.Name())
		}
	}
	sort.Strings(upFiles)

	// Apply each migration
	for _, filename := range upFiles {
		version := strings.TrimSuffix(filename, ".up.sql")
		
		// Check if migration already applied
		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM schema_migrations WHERE version = $1", version).Scan(&count)
		if err != nil {
			return err
		}

		if count > 0 {
			log.Printf("Migration %s already applied, skipping", version)
			continue
		}

		// Read migration file
		content, err := ioutil.ReadFile(filepath.Join("migrations", filename))
		if err != nil {
			return err
		}

		// Execute migration
		_, err = db.Exec(string(content))
		if err != nil {
			return err
		}

		// Record migration as applied
		_, err = db.Exec("INSERT INTO schema_migrations (version) VALUES ($1)", version)
		if err != nil {
			return err
		}

		log.Printf("Applied migration: %s", version)
	}

	return nil
} 