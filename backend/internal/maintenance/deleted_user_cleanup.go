package maintenance

import (
	"database/sql"
	"log"
	"time"
)

func StartDeletedUserCleanup(db *sql.DB) {
	go func() {
		for {
			now := time.Now().UTC()
			nextRun := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
			timer := time.NewTimer(time.Until(nextRun))
			<-timer.C
			timer.Stop()

			if err := purgeDeletedUsers(db); err != nil {
				log.Printf("deleted user cleanup failed: %v", err)
				continue
			}
		}
	}()
}

func purgeDeletedUsers(db *sql.DB) error {
	result, err := db.Exec(`DELETE FROM users WHERE is_deleted=true`)
	if err != nil {
		return err
	}

	if rows, err := result.RowsAffected(); err == nil && rows > 0 {
		log.Printf("deleted user cleanup removed %d user(s)", rows)
	}

	return nil
}
