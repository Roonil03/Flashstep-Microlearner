package middleware

import (
	"container/heap"
	"context"
	"io"
	"math"
	"net/http"
	"strconv"
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
	key     string
	count   int
	reset   time.Time
	index   int
	tokens  float64
	updated time.Time
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
	burst    int
}

func (l *rateLimiter) allow(key string, now time.Time) (bool, time.Duration) {
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
			return false, l.expiries[0].reset.Sub(now)
		}
		entry = &rateEntry{key: key, reset: now.Add(l.window), tokens: float64(l.burst), updated: now}
		l.entries[key] = entry
		heap.Push(&l.expiries, entry)
	}
	if l.burst > 0 {
		entry.tokens = math.Min(float64(l.burst), entry.tokens+now.Sub(entry.updated).Seconds()*float64(l.limit)/l.window.Seconds())
		entry.updated = now
		if entry.tokens < 1 {
			return false, time.Duration(math.Ceil((1 - entry.tokens) * float64(l.window) / float64(l.limit)))
		}
		entry.tokens--
		// Forget an idle bucket only after it has completely refilled. This also
		// prevents a fixed-window boundary from granting a second auth burst.
		entry.reset = now.Add(time.Duration(math.Ceil((float64(l.burst) - entry.tokens) * float64(l.window) / float64(l.limit))))
		heap.Fix(&l.expiries, entry.index)
		return true, 0
	}
	if entry.count >= l.limit {
		return false, entry.reset.Sub(now)
	}
	entry.count++
	return true, 0
}

// RateLimit uses the authenticated user, or the validated client IP for anonymous
// requests, and bounds its own memory. Proxy CIDRs must be configured explicitly.
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	return newRateLimit(limit, window, 0)
}

// RateLimitWithBurst refills limit requests per window, allowing at most burst
// immediate requests after an idle period. Shared-IP auth clients can sign in
// together without permitting the entire sustained budget in one CPU spike.
func RateLimitWithBurst(limit int, window time.Duration, burst int) gin.HandlerFunc {
	if burst <= 0 {
		panic("rate limit burst must be positive")
	}
	return newRateLimit(limit, window, burst)
}

func newRateLimit(limit int, window time.Duration, burst int) gin.HandlerFunc {
	if limit <= 0 || window <= 0 {
		panic("rate limit and window must be positive")
	}
	limiter := &rateLimiter{entries: make(map[string]*rateEntry), limit: limit, window: window, burst: burst}
	return func(c *gin.Context) {
		now := time.Now()
		key := c.GetString("user_id")
		if key == "" {
			key = c.ClientIP()
		}
		if allowed, retry := limiter.allow(key, now); !allowed {
			c.Header("Retry-After", strconv.FormatInt(max(1, int64(math.Ceil(retry.Seconds()))), 10))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "Too many requests. Please wait and try again."})
			return
		}
		c.Next()
	}
}

// AccountConcurrencyLimit must follow Auth. It reserves no waiting goroutines or
// persistent account entries; the global request cap also bounds this map's size.
// Sequential sync batches have no additional quota, regardless of library size.
func AccountConcurrencyLimit(limit int) gin.HandlerFunc {
	if limit <= 0 {
		panic("account concurrency limit must be positive")
	}
	var mu sync.Mutex
	active := make(map[string]int)
	return func(c *gin.Context) {
		key := c.GetString("user_id")
		if key == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Please sign in again."})
			return
		}
		mu.Lock()
		if active[key] >= limit {
			mu.Unlock()
			c.Header("Retry-After", "1")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "Your account is busy. Please try again shortly."})
			return
		}
		active[key]++
		mu.Unlock()
		defer func() {
			mu.Lock()
			defer mu.Unlock()
			active[key]--
			if active[key] == 0 {
				delete(active, key)
			}
		}()
		c.Next()
	}
}

// Recovery returns the same JSON error envelope as other failures without logging request secrets.
func Recovery() gin.HandlerFunc {
	return gin.CustomRecoveryWithWriter(io.Discard, func(c *gin.Context, recovered any) {
		c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "The server could not complete this request. Please try again shortly."})
	})
}
