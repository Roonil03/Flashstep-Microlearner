package db

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"

	"backend/internal/config"
)

var DB *sql.DB

func ConnectDB(cfg *config.Config) *sql.DB {
	var err error

	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DBHost,
		cfg.DBPort,
		cfg.DBUser,
		cfg.DBPassword,
		cfg.DBName,
	)
	maxRetries := 5

	for i := 1; i <= maxRetries; i++ {
		DB, err = sql.Open("postgres", dsn)
		if err != nil {
			log.Printf("Attempt %d: Failed to open DB: %v\n", i, err)
			time.Sleep(2 * time.Second)
			continue
		}

		err = DB.Ping()
		if err == nil {
			log.Println("✅ Connected to PostgreSQL")
			break
		}

		log.Printf("Attempt %d: DB not ready yet...\n", i)
		time.Sleep(2 * time.Second)
	}

	if err != nil {
		log.Fatal("❌ Could not connect to database after retries:", err)
	}
	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(10)
	DB.SetConnMaxLifetime(5 * time.Minute)
	return DB
}
