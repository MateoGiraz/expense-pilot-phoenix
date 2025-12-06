package models

import (
	"time"
)

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error string `json:"error" example:"Invalid request"`
}

// Expense represents an expense record
type Expense struct {
	ID           int64     `json:"id" example:"1" db:"id"`
	Amount       float64   `json:"amount" example:"100.50" db:"amount"`
	Date         time.Time `json:"date" example:"2024-03-20T00:00:00Z" db:"date"`
	CategoryID   int64     `json:"category_id" example:"1" db:"category_id"`
	UserID       int64     `json:"user_id" example:"1" db:"user_id"`
	CompanyID    int64     `json:"company_id" example:"1" db:"company_id"`
	RegisteredAt time.Time `json:"registered_at" db:"registered_at"`
	CreatedAt    time.Time `json:"created_at" example:"2024-03-20T00:00:00Z" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" example:"2024-03-20T00:00:00Z" db:"updated_at"`
	Description  *string   `json:"description,omitempty" example:"Office supplies"`
}

// ExpenseListResponse represents the paginated response for listing expenses
type ExpenseListResponse struct {
	Expenses    []Expense `json:"expenses"`
	TotalCount  int64     `json:"total_count" example:"100"`
	Page        int       `json:"page" example:"1"`
	TotalPages  int       `json:"total_pages" example:"10"`
	PageSize    int       `json:"page_size" example:"10"`
}

// ExpenseCreateRequest represents the request body for creating an expense
type ExpenseCreateRequest struct {
	CompanyID   int64   `json:"company_id" binding:"required" example:"1"`
	UserID      int64   `json:"user_id" binding:"required" example:"1"`
	CategoryID  int64   `json:"category_id" binding:"required" example:"1"`
	Amount      float64 `json:"amount" binding:"required" example:"100.50"`
	Description *string `json:"description,omitempty" example:"Office supplies"`
	Date        time.Time `json:"date" binding:"required" example:"2024-03-20T00:00:00Z"`
}

// ExpenseUpdateRequest represents the request body for updating an expense
type ExpenseUpdateRequest struct {
	CategoryID  *int64    `json:"category_id,omitempty" example:"1"`
	Amount      *float64  `json:"amount,omitempty" example:"100.50"`
	Description *string   `json:"description,omitempty" example:"Office supplies"`
	Date        *time.Time `json:"date,omitempty" example:"2024-03-20T00:00:00Z"`
} 