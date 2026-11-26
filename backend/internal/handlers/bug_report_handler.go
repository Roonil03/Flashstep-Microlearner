package handlers

import (
	"backend/internal/httpinput"
	"bytes"
	"database/sql"
	"encoding/json"
	"io"
	"log"
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
	h := &BugReportHandler{
		db: db, token: strings.TrimSpace(os.Getenv("BUG_REPORT_GITHUB_TOKEN")),
		client:  &http.Client{Timeout: 15 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }},
		reports: &bugReportLimiter{entries: make(map[string]*bugReportReservation)},
		idKey:   []byte(jwtSecret),
	}
	if h.token == "" {
		log.Print("Bug reporting disabled: configure BUG_REPORT_GITHUB_TOKEN on the backend service with access to the target repository and Actions write permission")
	}
	return h
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
	var report bugReportRequest
	if err := httpinput.DecodeObject(body, &report, true); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report. Check field lengths and public posting consent."})
		return
	}
	if !report.normalizeAndValidate() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report. Check field lengths and public posting consent."})
		return
	}
	canonical, _ := json.Marshal(report)
	id, accountKey := bugReportIdentity(h.idKey, accountID, canonical)
	if h.token == "" {
		switch h.reports.outcome(id, time.Now()) {
		case bugReportAccepted:
			reportAlreadyQueued(c, id)
		case bugReportUncertain:
			reportUnavailable(c)
		default:
			reportBotUnavailable(c)
		}
		return
	}
	if len(h.idKey) == 0 {
		reportUnavailable(c)
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
	reservation, duplicate, permitted := h.reports.reserve(id, accountKey, time.Now())
	if duplicate {
		reportAlreadyQueued(c, id)
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
	rejected := dispatchErr == nil && response != nil && bugReportDispatchRejected(response)
	if response != nil {
		response.Body.Close()
	}
	// With the same JWT secret, an unchanged report regenerates the same ID
	// after restart; the workflow checks for that marker on existing bot issues.
	outcome := bugReportUncertain
	if accepted {
		outcome = bugReportAccepted
	} else if rejected {
		outcome = bugReportRejected
	}
	outcome = h.reports.finish(id, reservation, outcome)
	if rejected {
		log.Printf("Bug report dispatch rejected by GitHub (status=%d): check BUG_REPORT_GITHUB_TOKEN validity, repository access, Actions write permission, and the bug-report.yml workflow on main", response.StatusCode)
	}
	switch outcome {
	case bugReportAccepted:
		c.JSON(http.StatusAccepted, gin.H{"report_id": id, "message": "Report queued for public posting on GitHub. Posting may take a few minutes."})
	case bugReportUncertain:
		reportUnavailable(c)
	default:
		reportBotUnavailable(c)
	}
}

// Only definitive bot configuration/access failures allow a manual fallback.
// Rate limits and uncertain delivery must retain the same report ID on retries.
// Error bodies are bounded and inspected only for classification, never logged.
func bugReportDispatchRejected(response *http.Response) bool {
	switch response.StatusCode {
	case http.StatusUnauthorized, http.StatusNotFound:
		return true
	case http.StatusForbidden:
		if response.Header.Get("Retry-After") != "" || response.Header.Get("X-RateLimit-Remaining") == "0" {
			return false
		}
		body, err := io.ReadAll(io.LimitReader(response.Body, 8193))
		if err != nil || len(body) > 8192 {
			return false
		}
		var failure struct {
			Message string `json:"message"`
		}
		if json.Unmarshal(body, &failure) != nil || failure.Message == "" {
			return false
		}
		message := strings.ToLower(failure.Message)
		return !strings.Contains(message, "rate limit") && !strings.Contains(message, "abuse")
	default:
		return false
	}
}

func reportBotUnavailable(c *gin.Context) {
	c.JSON(http.StatusServiceUnavailable, gin.H{"code": "bot_unavailable", "error": "Automatic bug reporting is unavailable for this attempt. Check existing GitHub Issues for earlier attempts before filing manually."})
}

func reportAlreadyQueued(c *gin.Context, id string) {
	c.JSON(http.StatusAccepted, gin.H{"report_id": id, "message": "This report has already been queued for public posting."})
}

func reportUnavailable(c *gin.Context) {
	c.Header("Retry-After", "60")
	c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Could not confirm report delivery. Check existing GitHub Issues, wait one minute, and retry the same report if needed. An earlier attempt may already be queued."})
}

func reportLimited(c *gin.Context) {
	c.Header("Retry-After", "60")
	c.JSON(http.StatusTooManyRequests, gin.H{"error": "Report limit reached. Wait before trying again (up to 24 hours)."})
}
