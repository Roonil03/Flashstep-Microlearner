package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const bugReportDispatchURL = "https://api.github.com/repos/Roonil03/Flashstep-Microlearner/actions/workflows/bug-report.yml/dispatches"

type BugReportHandler struct {
	db      *sql.DB
	token   string
	client  *http.Client
	reports *bugReportLimiter
	idKey   []byte
}

func NewBugReportHandler(db *sql.DB, jwtSecret string) *BugReportHandler {
	return &BugReportHandler{
		db: db, token: strings.TrimSpace(os.Getenv("BUG_REPORT_GITHUB_TOKEN")),
		client:  &http.Client{Timeout: 15 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }},
		reports: &bugReportLimiter{entries: make(map[string]*bugReportReservation)},
		idKey:   []byte(jwtSecret),
	}
}

type bugReportRequest struct {
	Title           string `json:"title"`
	Description     string `json:"description"`
	Reproduction    string `json:"reproduction"`
	Expected        string `json:"expected"`
	Actual          string `json:"actual"`
	PublicConfirmed bool   `json:"public_confirmed"`
}

func (r *bugReportRequest) normalizeAndValidate() bool {
	fields := []*string{&r.Title, &r.Description, &r.Reproduction, &r.Expected, &r.Actual}
	minimums := []int{5, 20, 0, 5, 5}
	maximums := []int{120, 4000, 3000, 2000, 2000}
	for i, field := range fields {
		*field = strings.TrimSpace(*field)
		length := utf8.RuneCountInString(*field)
		if !utf8.ValidString(*field) || length < minimums[i] || length > maximums[i] {
			return false
		}
		for _, ch := range *field {
			if unicode.IsControl(ch) && ch != '\n' && ch != '\r' && ch != '\t' {
				return false
			}
			if i == 0 && (ch == '\n' || ch == '\r' || ch == '\t') {
				return false
			}
		}
	}
	return r.PublicConfirmed
}

// Create accepts only an authenticated active account. Account identity is used
// solely for private quota/deduplication; only explicitly supplied text is sent.
func (h *BugReportHandler) Create(c *gin.Context) {
	userID := c.GetString("user_id")
	accountID, err := uuid.Parse(userID)
	if err != nil || accountID == uuid.Nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sign in to report a bug."})
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 48*1024)
	body, err := io.ReadAll(c.Request.Body)
	if err != nil || !utf8.Valid(body) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report. Check field lengths and public posting consent."})
		return
	}
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.DisallowUnknownFields()
	var report bugReportRequest
	if err := decoder.Decode(&report); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report. Check field lengths and public posting consent."})
		return
	}
	var extra any
	if decoder.Decode(&extra) != io.EOF || !report.normalizeAndValidate() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report. Check field lengths and public posting consent."})
		return
	}
	if h.token == "" || len(h.idKey) == 0 {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Bug reporting is temporarily unavailable. Your report has not been sent."})
		return
	}
	// GitHub limits the size of workflow inputs. Report text is JSON data,
	// so keep literal angle brackets and ampersands in the inner JSON string.
	var payload bytes.Buffer
	encoder := json.NewEncoder(&payload)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(report); err != nil {
		reportUnavailable(c)
		return
	}
	// Only the baseline users table is consulted; reports never change the DB.
	var active bool
	err = h.db.QueryRowContext(c.Request.Context(), "SELECT EXISTS (SELECT 1 FROM users WHERE id=$1 AND is_deleted=false)", accountID.String()).Scan(&active)
	if err != nil {
		reportUnavailable(c)
		return
	}
	if !active {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sign in to an active account to report a bug."})
		return
	}
	canonical, _ := json.Marshal(report)
	id, accountKey := bugReportIdentity(h.idKey, accountID, canonical)
	reservation, duplicate, permitted := h.reports.reserve(id, accountKey, time.Now())
	if duplicate {
		c.JSON(http.StatusAccepted, gin.H{"report_id": id, "message": "This report has already been queued for public posting."})
		return
	}
	if !permitted {
		reportLimited(c)
		return
	}
	dispatch, _ := json.Marshal(map[string]any{"ref": "main", "inputs": map[string]string{"report_id": id, "report": payload.String()}})
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodPost, bugReportDispatchURL, bytes.NewReader(dispatch))
	if err != nil {
		reportUnavailable(c)
		return
	}
	req.Header.Set("Authorization", "Bearer "+h.token)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	req.Header.Set("Content-Type", "application/json")
	response, dispatchErr := h.client.Do(req)
	accepted := dispatchErr == nil && response != nil && (response.StatusCode == http.StatusNoContent || response.StatusCode == http.StatusOK)
	if response != nil {
		response.Body.Close()
	}
	// The same private ID is regenerated after restarts, so the workflow's
	// bot-owned issue marker also deduplicates uncertain delivery retries.
	h.reports.finish(id, reservation, accepted)
	if !accepted {
		reportUnavailable(c)
		return
	}
	c.JSON(http.StatusAccepted, gin.H{"report_id": id, "message": "Report queued for public posting on GitHub. Posting may take a few minutes."})
}

func reportUnavailable(c *gin.Context) {
	c.Header("Retry-After", "60")
	c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Could not confirm report delivery. Wait one minute and retry the same report safely."})
}

func reportLimited(c *gin.Context) {
	c.Header("Retry-After", "60")
	c.JSON(http.StatusTooManyRequests, gin.H{"error": "Report limit reached. Wait before trying again (up to 24 hours)."})
}
