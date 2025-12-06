package config

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"time"
)

// SeedData contains seeded expense data
func SeedExpenses(db *sql.DB) error {
	log.Println("Starting expenses database seeding...")

	// Check if we already have expenses
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM expenses").Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to count existing expenses: %v", err)
	}

	if count > 0 {
		log.Printf("Database already has %d expenses, skipping seeding", count)
		return nil
	}

	// Sample expense descriptions based on the Phoenix categories
	expenseData := []struct {
		categoryID  int64
		description string
		minAmount   float64
		maxAmount   float64
	}{
		{1, "Lunch meeting with clients", 25.0, 100.0},
		{1, "Office catering for team meeting", 50.0, 200.0},
		{1, "Business dinner", 75.0, 300.0},
		{2, "Taxi to airport", 20.0, 60.0},
		{2, "Uber to client meeting", 15.0, 45.0},
		{2, "Gas for company vehicle", 40.0, 80.0},
		{3, "Hotel stay for conference", 150.0, 400.0},
		{3, "Airbnb for business trip", 100.0, 250.0},
		{4, "Office printer paper", 25.0, 50.0},
		{4, "Pens and notebooks", 15.0, 35.0},
		{4, "Desk organizers", 20.0, 60.0},
		{5, "Google Ads campaign", 200.0, 1000.0},
		{5, "Social media advertising", 100.0, 500.0},
		{5, "Print marketing materials", 50.0, 200.0},
		{8, "Slack subscription", 80.0, 150.0},
		{8, "Adobe Creative Suite", 50.0, 100.0},
		{8, "Project management tool", 30.0, 80.0},
		{9, "Flight to client site", 200.0, 800.0},
		{9, "Train ticket for conference", 50.0, 200.0},
		{10, "Team lunch", 100.0, 300.0},
		{10, "Client entertainment", 150.0, 500.0},
	}

	// Create 50 realistic expenses
	rand.Seed(time.Now().UnixNano())
	
	for i := 0; i < 50; i++ {
		// Select random expense template
		template := expenseData[rand.Intn(len(expenseData))]
		
		// Generate random amount within template range
		amount := template.minAmount + rand.Float64()*(template.maxAmount-template.minAmount)
		amount = float64(int(amount*100)) / 100 // Round to 2 decimal places
		
		// Generate random date within the last year
		daysAgo := rand.Intn(365)
		expenseDate := time.Now().AddDate(0, 0, -daysAgo).Format("2006-01-02")
		
		// Generate random registered_at within a few days of the expense date
		registeredDaysOffset := rand.Intn(7) // 0-6 days after expense date
		registeredAt := time.Now().AddDate(0, 0, -daysAgo+registeredDaysOffset)
		
		// Use company_id 1 (Demo Company) and user_id 1 (demo user)
		companyID := int64(1)
		userID := int64(1)
		
		query := `
			INSERT INTO expenses (amount, date, category_id, user_id, company_id, description, registered_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
		`
		
		_, err := db.Exec(query, amount, expenseDate, template.categoryID, userID, companyID, template.description, registeredAt)
		if err != nil {
			return fmt.Errorf("failed to insert expense %d: %v", i+1, err)
		}
	}

	log.Println("Successfully seeded 50 expenses!")
	return nil
} 