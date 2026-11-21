package handlers

import (
	"backend/internal/httperror"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"backend/internal/services"
)

type AnalyticsHandler struct {
	service *services.AnalyticsService
}

func NewAnalyticsHandler(service *services.AnalyticsService) *AnalyticsHandler {
	return &AnalyticsHandler{service: service}
}

func parseRange(c *gin.Context) (time.Time, time.Time, error) {
	layout := "2006-01-02"
	fromStr := c.Query("from")
	toStr := c.Query("to")
	from, err := time.Parse(layout, fromStr)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	to, err := time.Parse(layout, toStr)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	to = to.Add(23*time.Hour + 59*time.Minute + 59*time.Second)
	if to.Before(from) || to.Sub(from) > 366*24*time.Hour {
		return time.Time{}, time.Time{}, errors.New("date range must be ordered and at most 366 days")
	}
	return from.UTC(), to.UTC(), nil
}

func (h *AnalyticsHandler) DailyReviewCount(c *gin.Context) {
	userID := c.GetString("user_id")
	from, to, err := parseRange(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid from/to format, use YYYY-MM-DD"})
		return
	}
	out, err := h.service.DailyReviewCount(c.Request.Context(), userID, from, to)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *AnalyticsHandler) AverageSessionLength(c *gin.Context) {
	userID := c.GetString("user_id")
	from, to, err := parseRange(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid from/to format, use YYYY-MM-DD"})
		return
	}
	out, err := h.service.AverageSessionLength(c.Request.Context(), userID, from, to)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"average_session_length": out,
	})
}

func (h *AnalyticsHandler) AccuracyTrends(c *gin.Context) {
	userID := c.GetString("user_id")
	from, to, err := parseRange(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid from/to format, use YYYY-MM-DD"})
		return
	}
	out, err := h.service.AccuracyTrends(c.Request.Context(), userID, from, to)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *AnalyticsHandler) DeckPerformance(c *gin.Context) {
	userID := c.GetString("user_id")
	deckID := c.Query("deck_id")
	if _, err := uuid.Parse(deckID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deck_id must be a valid UUID"})
		return
	}
	out, err := h.service.DeckPerformance(c.Request.Context(), userID, deckID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *AnalyticsHandler) Dashboard(c *gin.Context) {
	userID := c.GetString("user_id")
	rangeDays, err := strconv.Atoi(c.DefaultQuery("range_days", "30"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "range_days must be 7, 30, or 90"})
		return
	}
	if rangeDays != 7 && rangeDays != 30 && rangeDays != 90 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "range_days must be 7, 30, or 90"})
		return
	}
	out, err := h.service.Dashboard(c.Request.Context(), userID, rangeDays)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}
