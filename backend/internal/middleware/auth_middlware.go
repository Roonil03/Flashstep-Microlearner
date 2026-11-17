package middleware

import (
	"backend/internal/httperror"
	"backend/internal/repositories"
	"database/sql"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"backend/pkg/utils"
	"github.com/google/uuid"
)

// RequireActiveUser revokes access immediately after account deletion, including existing JWTs.
func RequireActiveUser(conn *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var active bool
		if err := conn.QueryRowContext(c.Request.Context(), `SELECT EXISTS (SELECT 1 FROM users WHERE id=$1 AND is_deleted=false)`, c.GetString("user_id")).Scan(&active); err != nil {
			httperror.Internal(c, err)
			c.Abort()
			return
		}
		if !active {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Your account is unavailable. Please sign in again."})
			return
		}
		if err := repositories.NewUserRepository(conn).CleanupDeletedContent(c.Request.Context(), c.GetString("user_id")); err != nil {
			httperror.Internal(c, err)
			c.Abort()
			return
		}
		c.Next()
	}
}

func CleanupDeletedAccounts(conn *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		if err := repositories.NewUserRepository(conn).CleanupDeletedUsers(c.Request.Context()); err != nil {
			httperror.Internal(c, err)
			c.Abort()
			return
		}
		c.Next()
	}
}

func Auth(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "authorization header missing",
			})
			return
		}
		parts := strings.Fields(header)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid authorization format",
			})
			return
		}
		tokenStr := parts[1]
		if tokenStr == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "empty token",
			})
			return
		}
		claims, err := utils.ParseJWT(jwtSecret, tokenStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid token",
			})
			return
		}
		userID, err := uuid.Parse(claims.UserID)
		if err != nil || userID == uuid.Nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}
		for _, key := range []string{"id", "deck_id"} {
			if value := c.Param(key); value != "" {
				if _, err := uuid.Parse(value); err != nil {
					c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": key + " must be a valid UUID"})
					return
				}
			}
		}
		c.Set("user_id", userID.String())
		c.Set("email", claims.Email)
		c.Next()
	}
}
