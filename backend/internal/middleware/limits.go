package middleware

import (
	"container/heap"
	"context"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const MaxRequestBytes int64 = 4 << 20

// RequestLimits bounds work and body size before JSON decoding or database access.
func RequestLimits() gin.HandlerFunc {
	slots := make(chan struct{}, 64)
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("Cache-Control", "no-store")
		if c.Request.ContentLength > MaxRequestBytes {
			c.AbortWithStatusJSON(http.StatusRequestEntityTooLarge, gin.H{"error": "Request is too large. Sync fewer records at a time."})
			return
		}
		select {
		case slots <- struct{}{}:
			defer func() { <-slots }()
		default:
			c.Header("Retry-After", "5")
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "The server is busy. Please try again shortly."})
			return
		}
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, MaxRequestBytes)
		ctx, cancel := context.WithTimeout(c.Request.Context(), 25*time.Second)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}

type rateEntry struct {
	key   string
	count int
	reset time.Time
	index int
}

type rateExpiryHeap []*rateEntry

func (h rateExpiryHeap) Len() int           { return len(h) }
func (h rateExpiryHeap) Less(i, j int) bool { return h[i].reset.Before(h[j].reset) }
func (h rateExpiryHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i]; h[i].index = i; h[j].index = j }
func (h *rateExpiryHeap) Push(value any) {
	entry := value.(*rateEntry)
	entry.index = len(*h)
	*h = append(*h, entry)
}
func (h *rateExpiryHeap) Pop() any {
	old := *h
	entry := old[len(old)-1]
	old[len(old)-1] = nil
	*h = old[:len(old)-1]
	return entry
}

const maxRateEntries = 10000
const maxRateExpiryWork = 128

type rateLimiter struct {
	mu       sync.Mutex
	entries  map[string]*rateEntry
	expiries rateExpiryHeap
	limit    int
	window   time.Duration
}

func (l *rateLimiter) allow(key string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	// Expiry order avoids scanning the full map on every denied request at
	// capacity. Bound cleanup per request so an idle window cannot cause a pause.
	for work := 0; work < maxRateExpiryWork && len(l.expiries) > 0 && !now.Before(l.expiries[0].reset); work++ {
		entry := heap.Pop(&l.expiries).(*rateEntry)
		delete(l.entries, entry.key)
	}
	entry := l.entries[key]
	if entry != nil && !now.Before(entry.reset) {
		heap.Remove(&l.expiries, entry.index)
		delete(l.entries, key)
		entry = nil
	}
	if entry == nil {
		if len(l.entries) >= maxRateEntries {
			return false
		}
		entry = &rateEntry{key: key, reset: now.Add(l.window)}
		l.entries[key] = entry
		heap.Push(&l.expiries, entry)
	}
	if entry.count >= l.limit {
		return false
	}
	entry.count++
	return true
}

// RateLimit uses the authenticated user, or the validated client IP for anonymous
// requests, and bounds its own memory. Proxy CIDRs must be configured explicitly.
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	limiter := &rateLimiter{entries: make(map[string]*rateEntry), limit: limit, window: window}
	return func(c *gin.Context) {
		now := time.Now()
		key := c.GetString("user_id")
		if key == "" {
			key = c.ClientIP()
		}
		if !limiter.allow(key, now) {
			c.Header("Retry-After", "60")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "Too many requests. Please wait a minute and try again."})
			return
		}
		c.Next()
	}
}

// Recovery returns the same JSON error envelope as other failures without logging request secrets.
func Recovery() gin.HandlerFunc {
	return gin.CustomRecoveryWithWriter(io.Discard, func(c *gin.Context, recovered any) {
		c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "The server could not complete this request. Please try again shortly."})
	})
}
