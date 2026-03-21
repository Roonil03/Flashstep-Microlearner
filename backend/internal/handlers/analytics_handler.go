package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

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
	return from, to, nil
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *AnalyticsHandler) DeckPerformance(c *gin.Context) {
	userID := c.GetString("user_id")
	deckID := c.Query("deck_id")
	if deckID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deck_id is required"})
		return
	}
	out, err := h.service.DeckPerformance(c.Request.Context(), userID, deckID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, out)
}
