package handlers

import (
	"errors"
	"net/http"

	"backend/internal/httperror"
	"backend/internal/httpinput"
	"backend/internal/services"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	service *services.UserService
}

func NewUserHandler(service *services.UserService) *UserHandler {
	return &UserHandler{service: service}
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required,max=72"`
	NewPassword string `json:"new_password" binding:"required,min=8,max=72"`
}

func (h *UserHandler) ChangePassword(c *gin.Context) {
	userID := c.GetString("user_id")
	var req ChangePasswordRequest
	if err := httpinput.BindJSON(c, &req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}
	if len(req.NewPassword) > 72 || len(req.OldPassword) > 72 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password must be between 8 and 72 bytes"})
		return
	}
	err := h.service.ChangePassword(userID, req.OldPassword, req.NewPassword)
	if err != nil {
		if errors.Is(err, services.ErrInvalidOldPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid old password"})
		} else {
			httperror.Internal(c, err)
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "password updated"})
}

func (h *UserHandler) DeleteAccount(c *gin.Context) {
	userID := c.GetString("user_id")
	err := h.service.DeleteAccount(userID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "account deleted"})
}
