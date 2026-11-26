package httpinput

import (
	"strings"
	"unicode/utf8"
)

// ValidText matches PostgreSQL UTF-8 text storage, without filtering study
// content such as markup, punctuation, newlines, or SQL examples.
func ValidText(values ...string) bool {
	for _, value := range values {
		if !utf8.ValidString(value) || strings.ContainsRune(value, '\x00') {
			return false
		}
	}
	return true
}
