package handlers

import (
	"backend/internal/httperror"
	"backend/internal/repositories"
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"backend/internal/models"
	"backend/internal/services"
)

type AuthHandler struct {
	service *services.AuthService
}

func NewAuthHandler(service *services.AuthService) *AuthHandler {
	return &AuthHandler{service: service}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}
	resp, err := h.service.Register(c.Request.Context(), services.RegisterInput{
		Username: req.Username,
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		switch {
		case errors.Is(err, services.ErrEmailAlreadyExists), errors.Is(err, services.ErrUsernameAlreadyExists):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		case errors.Is(err, services.ErrInvalidRegistration):
			c.JSON(http.StatusBadRequest, gin.H{"error": "Use a username of 3 to 50 characters, a valid email up to 100 characters, and a password of 8 to 72 bytes."})
		default:
			httperror.Internal(c, err)
		}
		return
	}
	c.JSON(http.StatusCreated, resp)
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}
	resp, err := h.service.Login(c.Request.Context(), services.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		if errors.Is(err, services.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		} else {
			httperror.Internal(c, err)
		}
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (h *AuthHandler) Me(c *gin.Context) {
	userID, _ := c.Get("user_id")
	id, _ := userID.(string)
	if strings.TrimSpace(id) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user id"})
		return
	}
	user, err := h.service.Me(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, repositories.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Account not found."})
		} else {
			httperror.Internal(c, err)
		}
		return
	}
	c.JSON(http.StatusOK, user)
}

func (h *AuthHandler) UpdateUsername(c *gin.Context) {
	userID, _ := c.Get("user_id")
	id, _ := userID.(string)
	if strings.TrimSpace(id) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing user id"})
		return
	}

	var req models.UpdateUsernameRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}

	if err := h.service.UpdateUsername(c.Request.Context(), id, req.Username); err != nil {
		switch {
		case errors.Is(err, services.ErrUsernameAlreadyExists):
			c.JSON(http.StatusConflict, gin.H{"error": "username already exists"})
		case errors.Is(err, services.ErrInvalidRegistration):
			c.JSON(http.StatusBadRequest, gin.H{"error": "Use a username of 3 to 50 characters."})
		default:
			httperror.Internal(c, err)
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "username updated successfully"})
}
