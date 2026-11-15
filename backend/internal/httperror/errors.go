package httperror

import (
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

// Internal keeps storage and implementation details out of API responses.
func Internal(c *gin.Context, err error) {
	log.Printf("request failed: method=%s route=%s error_type=%T", c.Request.Method, c.FullPath(), err)
	c.JSON(http.StatusInternalServerError, gin.H{"error": "The server could not complete this request. Please try again shortly."})
}

// InvalidJSON exposes only field names and validation rules, never submitted values.
func InvalidJSON(c *gin.Context, err error) {
	var sizeErr *http.MaxBytesError
	if errors.As(err, &sizeErr) {
		c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "Request is too large. Sync fewer records at a time."})
		return
	}
	var fields validator.ValidationErrors
	if errors.As(err, &fields) && len(fields) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid " + fields[0].Field() + ": check the required format and length."})
		return
	}
	c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON request. Check the field types and try again."})
}
