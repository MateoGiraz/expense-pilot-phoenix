package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/expense_pilot/expenses-service/internal/models"
	"github.com/expense_pilot/expenses-service/internal/repository"
)

type ExpenseHandler struct {
	repo *repository.ExpenseRepository
}

func NewExpenseHandler(repo *repository.ExpenseRepository) *ExpenseHandler {
	return &ExpenseHandler{repo: repo}
}

// @Summary      List expenses
// @Description  Get a paginated list of expenses for a company
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        page query int false "Page number" default(1)
// @Param        page_size query int false "Items per page" default(10)
// @Success      200  {object}  models.ExpenseListResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses [get]
func (h *ExpenseHandler) ListExpenses(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	offset := (page - 1) * pageSize

	expenses, err := h.repo.ListExpenses(c.Request.Context(), companyID, pageSize, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, expenses)
}

// @Summary      Get expense
// @Description  Get a single expense by ID
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        id path int true "Expense ID"
// @Success      200  {object}  models.Expense
// @Failure      400  {object}  models.ErrorResponse
// @Failure      404  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses/{id} [get]
func (h *ExpenseHandler) GetExpense(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid expense ID"})
		return
	}

	expense, err := h.repo.GetExpense(c.Request.Context(), id, companyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if expense == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Expense not found"})
		return
	}

	c.JSON(http.StatusOK, expense)
}

// @Summary      Create expense
// @Description  Create a new expense
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        expense body models.ExpenseCreateRequest true "Expense data"
// @Success      201  {object}  models.Expense
// @Failure      400  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses [post]
func (h *ExpenseHandler) CreateExpense(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	var req models.ExpenseCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.CompanyID = companyID
	expense, err := h.repo.CreateExpense(c.Request.Context(), &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, expense)
}

// @Summary      Update expense
// @Description  Update an existing expense
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        id path int true "Expense ID"
// @Param        expense body models.ExpenseUpdateRequest true "Expense data"
// @Success      200  {object}  models.Expense
// @Failure      400  {object}  models.ErrorResponse
// @Failure      404  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses/{id} [put]
func (h *ExpenseHandler) UpdateExpense(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid expense ID"})
		return
	}

	var req models.ExpenseUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	expense, err := h.repo.UpdateExpense(c.Request.Context(), id, companyID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if expense == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Expense not found"})
		return
	}

	c.JSON(http.StatusOK, expense)
}

// @Summary      Delete expense
// @Description  Delete an expense
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        id path int true "Expense ID"
// @Success      204  "No Content"
// @Failure      400  {object}  models.ErrorResponse
// @Failure      404  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses/{id} [delete]
func (h *ExpenseHandler) DeleteExpense(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid expense ID"})
		return
	}

	if err := h.repo.DeleteExpense(c.Request.Context(), id, companyID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Status(http.StatusNoContent)
}

// @Summary      List expenses by date range
// @Description  Get a paginated list of expenses for a company within a date range
// @Tags         expenses
// @Accept       json
// @Produce      json
// @Param        company_id path int true "Company ID"
// @Param        start_date query string true "Start date (YYYY-MM-DD)"
// @Param        end_date query string true "End date (YYYY-MM-DD)"
// @Param        page query int false "Page number" default(1)
// @Param        page_size query int false "Items per page" default(10)
// @Param        category_id query int false "Category ID"
// @Success      200  {object}  models.ExpenseListResponse
// @Failure      400  {object}  models.ErrorResponse
// @Failure      500  {object}  models.ErrorResponse
// @Security     BearerAuth
// @Router       /companies/{company_id}/expenses/by-date [get]
func (h *ExpenseHandler) ListExpensesByDateRange(c *gin.Context) {
	companyID, err := strconv.ParseInt(c.Param("company_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid company ID"})
		return
	}

	startDate, err := time.Parse("2006-01-02", c.Query("start_date"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start date"})
		return
	}

	endDate, err := time.Parse("2006-01-02", c.Query("end_date"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end date"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	offset := (page - 1) * pageSize

	var categoryID *int64
	if catID := c.Query("category_id"); catID != "" {
		id, err := strconv.ParseInt(catID, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid category ID"})
			return
		}
		categoryID = &id
	}

	expenses, err := h.repo.ListExpensesByDateRange(c.Request.Context(), companyID, startDate, endDate, pageSize, offset, categoryID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, expenses)
} 