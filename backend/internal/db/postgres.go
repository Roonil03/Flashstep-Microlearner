package db

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"

	"backend/internal/config"
)

var DB *sql.DB

func Connect(cfg *config.Config) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s TimeZone=UTC",
		cfg.DBHost,
		cfg.DBPort,
		cfg.DBUser,
		cfg.DBPassword,
		cfg.DBName,
		cfg.DBSSLMode,
	)
	var err error
	for attempt := 1; attempt <= 10; attempt++ {
		DB, err = sql.Open("postgres", dsn)
		if err == nil {
			if pingErr := DB.Ping(); pingErr == nil {
				DB.SetMaxOpenConns(25)
				DB.SetMaxIdleConns(10)
				DB.SetConnMaxLifetime(5 * time.Minute)
				return DB, nil
			} else {
				err = pingErr
			}
		}
		if DB != nil {
			_ = DB.Close()
		}
		time.Sleep(time.Duration(attempt) * time.Second)
	}
	return nil, fmt.Errorf("failed to connect to postgres after retries: %w", err)
}
