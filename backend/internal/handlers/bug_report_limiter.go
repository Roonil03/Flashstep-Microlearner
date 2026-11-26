package handlers

import (
	"crypto/hmac"
	"crypto/sha256"
	"sync"
	"time"

	"github.com/google/uuid"
)

const (
	bugReportMetadataTTL = 30 * 24 * time.Hour
	bugReportMaxEntries  = 24000
	bugReportMaxAttempts = 720
)

// Only opaque identifiers and timestamps are retained, never public report text.
// These bounded quotas are per server process and reset when it restarts.
type bugReportLimiter struct {
	mu       sync.Mutex
	entries  map[string]*bugReportReservation
	attempts []bugReportAttempt
}

type bugReportReservation struct {
	lastAttempt time.Time
	outcome     bugReportOutcome
}

// Once an attempt may have reached GitHub, a later rejection cannot establish
// that this report was never queued. Keep the strongest evidence for its ID.
type bugReportOutcome uint8

const (
	bugReportRejected bugReportOutcome = iota
	bugReportUncertain
	bugReportAccepted
)

type bugReportAttempt struct {
	account [sha256.Size]byte
	at      time.Time
}

// Domain-separated HMACs keep account identity private in both process metadata
// and the public report UUID. Reusing the configured JWT secret requires no new
// secret; rotating it changes IDs, so older issue markers no longer match.
func bugReportIdentity(key []byte, account uuid.UUID, canonical []byte) (string, [sha256.Size]byte) {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("flashstep/bug-report/account/v1\x00"))
	mac.Write(account[:])
	var accountKey [sha256.Size]byte
	copy(accountKey[:], mac.Sum(nil))
	mac.Reset()
	mac.Write([]byte("flashstep/bug-report/submission/v1\x00"))
	mac.Write(account[:])
	mac.Write(canonical)
	var id uuid.UUID
	copy(id[:], mac.Sum(nil))
	id[6] = (id[6] & 0x0f) | 0x80 // UUID version 8: application-defined hash.
	id[8] = (id[8] & 0x3f) | 0x80
	return id.String(), accountKey
}

func (l *bugReportLimiter) reserve(id string, account [sha256.Size]byte, now time.Time) (*bugReportReservation, bool, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for key, entry := range l.entries {
		if !entry.lastAttempt.After(now.Add(-bugReportMetadataTTL)) {
			delete(l.entries, key)
		}
	}
	entry := l.entries[id]
	if entry != nil && entry.outcome == bugReportAccepted {
		return nil, true, true
	}
	if entry != nil && entry.lastAttempt.After(now.Add(-time.Minute)) {
		return nil, false, false
	}
	retained := l.attempts[:0]
	accountAttempts, globalAttempts := 0, 0
	recentAccount := false
	for _, attempt := range l.attempts {
		if !attempt.at.After(now.Add(-24 * time.Hour)) {
			continue
		}
		retained = append(retained, attempt)
		if attempt.at.After(now.Add(-time.Hour)) {
			globalAttempts++
		}
		if attempt.account == account {
			accountAttempts++
			recentAccount = recentAccount || attempt.at.After(now.Add(-5*time.Minute))
		}
	}
	l.attempts = retained
	if accountAttempts >= 3 || globalAttempts >= 30 || (entry == nil && recentAccount) || len(l.attempts) >= bugReportMaxAttempts {
		return nil, false, false
	}
	if entry == nil {
		if len(l.entries) >= bugReportMaxEntries {
			return nil, false, false
		}
		entry = &bugReportReservation{}
		l.entries[id] = entry
	}
	entry.lastAttempt = now
	l.attempts = append(l.attempts, bugReportAttempt{account: account, at: now})
	return entry, false, true
}

func (l *bugReportLimiter) outcome(id string, now time.Time) bugReportOutcome {
	l.mu.Lock()
	defer l.mu.Unlock()
	if entry := l.entries[id]; entry != nil {
		if entry.lastAttempt.After(now.Add(-bugReportMetadataTTL)) {
			return entry.outcome
		}
		delete(l.entries, id)
	}
	return bugReportRejected
}

func (l *bugReportLimiter) finish(id string, reservation *bugReportReservation, outcome bugReportOutcome) bugReportOutcome {
	l.mu.Lock()
	defer l.mu.Unlock()
	if current := l.entries[id]; current == reservation {
		if outcome > current.outcome {
			current.outcome = outcome
		}
		return current.outcome
	}
	return outcome
}
