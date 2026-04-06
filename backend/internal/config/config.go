package config

import (
	"log"
	"os"
	"path/filepath"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port            string
	DatabaseURL     string
	DBHost          string
	DBPort          string
	DBUser          string
	DBPassword      string
	DBName          string
	DBSSLMode       string
	JWTSecret       string
	JWTExpiryMinute int
}

func Load() *Config {
	loadEnv()
	cfg := &Config{
		Port:            getEnv("PORT", "8080"),
		DatabaseURL:     getEnv("DATABASE_URL", ""),
		DBHost:          getEnv("DB_HOST", "localhost"),
		DBPort:          getEnv("GO_PORT", "5432"),
		DBUser:          getEnv("DB_USER", "postgres"),
		DBPassword:      getEnv("DB_PASSWORD", "postgres"),
		DBName:          getEnv("DB_NAME", "flashcards"),
		DBSSLMode:       getEnv("DB_SSLMODE", "disable"),
		JWTSecret:       getEnv("JWT_SECRET", "change-this-in-real-use"),
		JWTExpiryMinute: getEnvInt("JWT_EXPIRY_MINUTES", 120),
	}
	log.Printf("DB CONFIG → host=%s port=%s user=%s db=%s",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBName)

	return cfg
}

func loadEnv() {
	paths := []string{
		".env",
		"../../.env",
		"backend/.env",
		"../../deployments/.env",
	}
	for _, path := range paths {
		absPath, _ := filepath.Abs(path)
		err := godotenv.Load(absPath)
		if err == nil {
			// log.Println("Loaded .env from:", absPath)
			return
		}
	}
	log.Println("No .env file found, using system environment variables")
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	n, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("invalid int for %s, using fallback %d", key, fallback)
		return fallback
	}
	return n
}
