// Package httpinput validates JSON envelopes before the normal typed binding.
package httpinput

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"reflect"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
)

var errJSON = errors.New("invalid or ambiguous JSON object")

// BindJSON preserves Gin's field validation and permissive unknown-field policy.
// Body limits remain the caller's responsibility, including MaxBytesReader errors.
func BindJSON(c *gin.Context, destination any) error {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		return err
	}
	return DecodeObject(body, destination, false)
}

// DecodeObject rejects duplicate members and trailing documents before decoding.
// It scans tokens iteratively, without creating a second object tree. Case aliases
// are checked only for typed root fields; extension metadata remains case-sensitive.
func DecodeObject(body []byte, destination any, disallowUnknown bool) error {
	if !utf8.Valid(body) {
		return errJSON
	}
	fields := []string{}
	t := reflect.TypeOf(destination)
	if t != nil && t.Kind() == reflect.Pointer {
		t = t.Elem()
	}
	if t != nil && t.Kind() == reflect.Struct {
		for i := 0; i < t.NumField(); i++ {
			field := t.Field(i)
			if field.PkgPath != "" {
				continue
			}
			name := strings.Split(field.Tag.Get("json"), ",")[0]
			if name == "-" {
				continue
			}
			if name == "" {
				name = field.Name
			}
			fields = append(fields, name)
		}
	}
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.UseNumber()
	first, err := decoder.Token()
	if err != nil {
		return err
	}
	if first != json.Delim('{') {
		return errJSON
	}
	type frame struct {
		keys map[string]struct{}
		key  bool
	}
	stack := []frame{{keys: make(map[string]struct{}), key: true}}
	for len(stack) > 0 {
		token, err := decoder.Token()
		if err != nil {
			return err
		}
		current := &stack[len(stack)-1]
		if current.keys != nil && current.key && token != json.Delim('}') {
			key, ok := token.(string)
			if !ok {
				return errJSON
			}
			if len(stack) == 1 {
				for _, field := range fields {
					if strings.EqualFold(key, field) {
						key = field
						break
					}
				}
			}
			if _, exists := current.keys[key]; exists {
				return errJSON
			}
			current.keys[key] = struct{}{}
			current.key = false
			continue
		}
		if delimiter, ok := token.(json.Delim); ok {
			switch delimiter {
			case '}', ']':
				stack = stack[:len(stack)-1]
			case '{':
				current.key = true
				stack = append(stack, frame{keys: make(map[string]struct{}), key: true})
			case '[':
				current.key = true
				stack = append(stack, frame{})
			}
		} else {
			current.key = true
		}
	}
	if _, err := decoder.Token(); err != io.EOF {
		return errJSON
	}
	decoder = json.NewDecoder(bytes.NewReader(body))
	if disallowUnknown {
		decoder.DisallowUnknownFields()
	}
	if err := decoder.Decode(destination); err != nil {
		return err
	}
	return binding.Validator.ValidateStruct(destination)
}
