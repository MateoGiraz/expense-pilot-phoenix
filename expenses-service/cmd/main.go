package main

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/expense_pilot/expenses-service/internal/handlers"
	"github.com/expense_pilot/expenses-service/internal/repository"
	"github.com/expense_pilot/expenses-service/internal/config"
	"github.com/expense_pilot/expenses-service/internal/middleware"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	_ "github.com/expense_pilot/expenses-service/docs" // Generated docs
	"github.com/newrelic/go-agent/v3/newrelic"
	nrgin "github.com/newrelic/go-agent/v3/integrations/nrgin"
)

// @title           Expense Service API
// @version         1.0
// @description     A microservice for managing expenses
// @termsOfService  http://swagger.io/terms/

// @contact.name   API Support
// @contact.url    http://www.swagger.io/support
// @contact.email  support@swagger.io

// @license.name  Apache 2.0
// @license.url   http://www.apache.org/licenses/LICENSE-2.0.html

// @host      localhost:4000
// @BasePath  /api

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.
func main() {
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: .env file not found")
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatalf("DATABASE_URL is not set")
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := setupDatabase(db); err != nil {
		log.Fatalf("Failed to setup database: %v", err)
	}

	// Seed the database with sample data
	if err := config.SeedExpenses(db); err != nil {
		log.Printf("Warning: Failed to seed database: %v", err)
	}

	licenseKey := os.Getenv("NEW_RELIC_LICENSE_KEY")
	appName := os.Getenv("NEW_RELIC_APP_NAME")

	app, err := newrelic.NewApplication(
		newrelic.ConfigAppName(appName),
		newrelic.ConfigLicense(licenseKey),
		newrelic.ConfigAppLogForwardingEnabled(true),
	  )


	expenseRepo := repository.NewExpenseRepository(db)
	expenseHandler := handlers.NewExpenseHandler(expenseRepo)

	r := gin.Default()
	r.Use(nrgin.Middleware(app))

	// CORS middleware
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Swagger documentation
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "expenses-service"})
	})

	// Expense routes with authentication
	expenses := r.Group("/api/companies/:company_id/expenses")
	expenses.Use(middleware.AuthMiddleware())
	{
		expenses.GET("", expenseHandler.ListExpenses)
		expenses.GET("/:id", expenseHandler.GetExpense)
		expenses.POST("", expenseHandler.CreateExpense)
		expenses.PUT("/:id", expenseHandler.UpdateExpense)
		expenses.DELETE("/:id", expenseHandler.DeleteExpense)
		expenses.GET("/by-date", expenseHandler.ListExpensesByDateRange)
	}

	port := os.Getenv("EXPENSES_SERVICE_PORT")
	if port == "" {
		port = "4001"
	}

	fmt.Printf("🚀 Expenses service running on port %s\n", port)
	fmt.Printf("📊 Swagger documentation available at: http://localhost:%s/swagger/index.html\n", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func setupDatabase(db *sql.DB) error {
	if err := db.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %v", err)
	}

	// Create migrations tracking table (drop first to avoid conflicts)
	_, err := db.Exec(`DROP TABLE IF EXISTS schema_migrations`)
	if err != nil {
		log.Printf("Warning: Failed to drop existing migrations table: %v", err)
	}
	
	_, err = db.Exec(`
		CREATE TABLE schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	if err != nil {
		return fmt.Errorf("failed to create migrations table: %v", err)
	}

	// Run all migrations
	if err := runAllMigrations(db); err != nil {
		return fmt.Errorf("failed to run migrations: %v", err)
	}

	log.Println("✅ Database setup completed!")
	return nil
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