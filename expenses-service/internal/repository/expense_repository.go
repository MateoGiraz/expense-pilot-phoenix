package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/expense_pilot/expenses-service/internal/models"
)

type ExpenseRepository struct {
	db *sql.DB
}

func NewExpenseRepository(db *sql.DB) *ExpenseRepository {
	return &ExpenseRepository{db: db}
}

func (r *ExpenseRepository) ListExpenses(ctx context.Context, companyID int64, limit, offset int) (*models.ExpenseListResponse, error) {
	query := `
		SELECT id, amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at
		FROM expenses
		WHERE company_id = $1
		ORDER BY date DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.QueryContext(ctx, query, companyID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("error querying expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.Expense
	for rows.Next() {
		var e models.Expense
		var description sql.NullString
		if err := rows.Scan(
			&e.ID, &e.Amount, &e.Date, &e.CategoryID, &e.UserID, &e.CompanyID, &description,
			&e.RegisteredAt, &e.CreatedAt, &e.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("error scanning expense: %w", err)
		}
		if description.Valid {
			e.Description = &description.String
		}
		expenses = append(expenses, e)
	}

	// Get total count
	var totalCount int64
	countQuery := `SELECT COUNT(*) FROM expenses WHERE company_id = $1`
	if err := r.db.QueryRowContext(ctx, countQuery, companyID).Scan(&totalCount); err != nil {
		return nil, fmt.Errorf("error getting total count: %w", err)
	}

	return &models.ExpenseListResponse{
		Expenses:    expenses,
		TotalCount:  totalCount,
		PageSize:    limit,
		Page:        offset/limit + 1,
		TotalPages:  int((totalCount + int64(limit) - 1) / int64(limit)),
	}, nil
}

func (r *ExpenseRepository) GetExpense(ctx context.Context, id, companyID int64) (*models.Expense, error) {
	query := `
		SELECT id, amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at
		FROM expenses
		WHERE id = $1 AND company_id = $2
	`

	var expense models.Expense
	var description sql.NullString
	err := r.db.QueryRowContext(ctx, query, id, companyID).Scan(
		&expense.ID, &expense.Amount, &expense.Date, &expense.CategoryID, &expense.UserID, &expense.CompanyID, &description,
		&expense.RegisteredAt, &expense.CreatedAt, &expense.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error getting expense: %w", err)
	}

	if description.Valid {
		expense.Description = &description.String
	}

	return &expense, nil
}

func (r *ExpenseRepository) CreateExpense(ctx context.Context, req *models.ExpenseCreateRequest) (*models.Expense, error) {
	query := `
		INSERT INTO expenses (amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at, inserted_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at
	`

	now := time.Now()
	var expense models.Expense
	var description sql.NullString
	
	var descParam interface{}
	if req.Description != nil {
		descParam = *req.Description
	} else {
		descParam = nil
	}
	
	err := r.db.QueryRowContext(ctx, query,
		req.Amount, req.Date, req.CategoryID, req.UserID, req.CompanyID, descParam,
		now, now, now, now, // registered_at, created_at, updated_at, inserted_at
	).Scan(
		&expense.ID, &expense.Amount, &expense.Date, &expense.CategoryID, &expense.UserID, &expense.CompanyID, &description,
		&expense.RegisteredAt, &expense.CreatedAt, &expense.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating expense: %w", err)
	}

	if description.Valid {
		expense.Description = &description.String
	}

	return &expense, nil
}

func (r *ExpenseRepository) UpdateExpense(ctx context.Context, id, companyID int64, req *models.ExpenseUpdateRequest) (*models.Expense, error) {
	query := `
		UPDATE expenses
		SET amount = COALESCE($1, amount),
			date = COALESCE($2, date),
			category_id = COALESCE($3, category_id),
			description = COALESCE($4, description),
			updated_at = $5
		WHERE id = $6 AND company_id = $7
		RETURNING id, amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at
	`

	var descParam interface{}
	if req.Description != nil {
		descParam = *req.Description
	} else {
		descParam = nil
	}

	var expense models.Expense
	var description sql.NullString
	err := r.db.QueryRowContext(ctx, query,
		req.Amount, req.Date, req.CategoryID, descParam, time.Now(), id, companyID,
	).Scan(
		&expense.ID, &expense.Amount, &expense.Date, &expense.CategoryID, &expense.UserID, &expense.CompanyID, &description,
		&expense.RegisteredAt, &expense.CreatedAt, &expense.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error updating expense: %w", err)
	}

	if description.Valid {
		expense.Description = &description.String
	}

	return &expense, nil
}

func (r *ExpenseRepository) DeleteExpense(ctx context.Context, id, companyID int64) error {
	query := `DELETE FROM expenses WHERE id = $1 AND company_id = $2`
	result, err := r.db.ExecContext(ctx, query, id, companyID)
	if err != nil {
		return fmt.Errorf("error deleting expense: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("error getting rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return nil // Expense not found
	}

	return nil
}

func (r *ExpenseRepository) ListExpensesByDateRange(ctx context.Context, companyID int64, startDate, endDate time.Time, limit, offset int, categoryID *int64) (*models.ExpenseListResponse, error) {
	query := `
		SELECT id, amount, date, category_id, user_id, company_id, description, registered_at, created_at, updated_at
		FROM expenses
		WHERE company_id = $1
		AND date >= $2
		AND date <= $3
	`

	args := []interface{}{companyID, startDate, endDate}
	argCount := 3

	if categoryID != nil {
		query += fmt.Sprintf(" AND category_id = $%d", argCount+1)
		args = append(args, *categoryID)
		argCount++
	}

	query += fmt.Sprintf(" ORDER BY date DESC LIMIT $%d OFFSET $%d", argCount+1, argCount+2)
	args = append(args, limit, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("error querying expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.Expense
	for rows.Next() {
		var e models.Expense
		var description sql.NullString
		if err := rows.Scan(
			&e.ID, &e.Amount, &e.Date, &e.CategoryID, &e.UserID, &e.CompanyID, &description,
			&e.RegisteredAt, &e.CreatedAt, &e.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("error scanning expense: %w", err)
		}
		if description.Valid {
			e.Description = &description.String
		}
		expenses = append(expenses, e)
	}

	// Get total count
	countQuery := `
		SELECT COUNT(*)
		FROM expenses
		WHERE company_id = $1
		AND date >= $2
		AND date <= $3
	`
	countArgs := []interface{}{companyID, startDate, endDate}
	if categoryID != nil {
		countQuery += " AND category_id = $4"
		countArgs = append(countArgs, *categoryID)
	}

	var totalCount int64
	if err := r.db.QueryRowContext(ctx, countQuery, countArgs...).Scan(&totalCount); err != nil {
		return nil, fmt.Errorf("error getting total count: %w", err)
	}

	return &models.ExpenseListResponse{
		Expenses:    expenses,
		TotalCount:  totalCount,
		PageSize:    limit,
		Page:        offset/limit + 1,
		TotalPages:  int((totalCount + int64(limit) - 1) / int64(limit)),
	}, nil
} 