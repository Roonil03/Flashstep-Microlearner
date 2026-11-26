package v1

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// contentParam validates UUID path values before PostgreSQL attempts a cast.
func contentParam(c *gin.Context, name, label string) (uuid.UUID, bool) {
	id, err := uuid.Parse(strings.TrimSpace(c.Param(name)))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": label + " must be a valid UUID"})
		return uuid.Nil, false
	}
	return id, true
}
