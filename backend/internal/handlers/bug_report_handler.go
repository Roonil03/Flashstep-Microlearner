package handlers

import (
	"backend/internal/repositories"
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
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
	db     *sql.DB
	token  string
	client *http.Client
}

func NewBugReportHandler(db *sql.DB) *BugReportHandler {
	return &BugReportHandler{db: db, token: strings.TrimSpace(os.Getenv("BUG_REPORT_GITHUB_TOKEN")), client: &http.Client{Timeout: 15 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}}
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
	if _, err := uuid.Parse(userID); err != nil {
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
	if h.token == "" {
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
	digest := sha256.Sum256(payload.Bytes())
	tx, err := h.db.BeginTx(c.Request.Context(), nil)
	if err != nil {
		reportUnavailable(c)
		return
	}
	defer tx.Rollback()
	// Serialize reservations across all server replicas, including per-account and
	// global quotas. Lock the account so deletion cannot race with reservation.
	if _, err = tx.ExecContext(c.Request.Context(), "SELECT pg_advisory_xact_lock($1)", repositories.BugReportQuotaLock); err != nil {
		reportUnavailable(c)
		return
	}
	var active bool
	err = tx.QueryRowContext(c.Request.Context(), "SELECT NOT is_deleted FROM users WHERE id=$1 FOR UPDATE", userID).Scan(&active)
	if err == sql.ErrNoRows || (err == nil && !active) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Sign in to an active account to report a bug."})
		return
	}
	if err != nil {
		reportUnavailable(c)
		return
	}
	if err = repositories.CleanupBugReportMetadata(c.Request.Context(), tx); err != nil {
		reportUnavailable(c)
		return
	}
	var id, status string
	var recentlyAttempted bool
	err = tx.QueryRowContext(c.Request.Context(), `SELECT id,status,last_attempt_at > NOW() - INTERVAL '1 minute' FROM bug_report_submissions WHERE user_id=$1 AND content_hash=$2`, userID, hex.EncodeToString(digest[:])).Scan(&id, &status, &recentlyAttempted)
	if err != nil && err != sql.ErrNoRows {
		reportUnavailable(c)
		return
	}
	exists := err == nil
	if exists && status == "accepted" {
		c.JSON(http.StatusAccepted, gin.H{"report_id": id, "message": "This report has already been queued for public posting."})
		return
	}
	if exists && recentlyAttempted {
		reportLimited(c)
		return
	}
	var accountAttempts, globalAttempts int
	if err = tx.QueryRowContext(c.Request.Context(), `SELECT COUNT(*) FILTER (WHERE s.user_id=$1 AND a.attempted_at > NOW() - INTERVAL '24 hours'), COUNT(*) FILTER (WHERE a.attempted_at > NOW() - INTERVAL '1 hour') FROM bug_report_attempts a JOIN bug_report_submissions s ON s.id=a.submission_id`, userID).Scan(&accountAttempts, &globalAttempts); err != nil {
		reportUnavailable(c)
		return
	}
	var recentAccount bool
	if err = tx.QueryRowContext(c.Request.Context(), `SELECT EXISTS(SELECT 1 FROM bug_report_submissions WHERE user_id=$1 AND last_attempt_at > NOW() - INTERVAL '5 minutes')`, userID).Scan(&recentAccount); err != nil {
		reportUnavailable(c)
		return
	}
	if accountAttempts >= 3 || globalAttempts >= 30 || (!exists && recentAccount) {
		reportLimited(c)
		return
	}
	if exists {
		_, err = tx.ExecContext(c.Request.Context(), "UPDATE bug_report_submissions SET status='pending',attempts=attempts+1,last_attempt_at=NOW() WHERE id=$1", id)
	} else {
		id = uuid.NewString()
		_, err = tx.ExecContext(c.Request.Context(), "INSERT INTO bug_report_submissions(id,user_id,content_hash,status) VALUES($1,$2,$3,'pending')", id, userID, hex.EncodeToString(digest[:]))
	}
	if err != nil {
		reportUnavailable(c)
		return
	}
	if _, err = tx.ExecContext(c.Request.Context(), "INSERT INTO bug_report_attempts(submission_id,attempted_at) SELECT id,last_attempt_at FROM bug_report_submissions WHERE id=$1", id); err != nil {
		reportUnavailable(c)
		return
	}
	if err = tx.Commit(); err != nil {
		reportUnavailable(c)
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
	status = "retry"
	if accepted {
		status = "accepted"
	}
	// A failed status update leaves a retryable reservation with the same report
	// ID; the workflow also deduplicates by ID before creating an issue.
	statusCtx, cancelStatus := context.WithTimeout(context.WithoutCancel(c.Request.Context()), 2*time.Second)
	defer cancelStatus()
	_, _ = h.db.ExecContext(statusCtx, "UPDATE bug_report_submissions SET status=$1 WHERE id=$2", status, id)
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
