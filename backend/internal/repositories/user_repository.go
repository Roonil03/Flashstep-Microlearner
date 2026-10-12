package repositories

import (
	"context"
	"database/sql"
	"errors"
	"github.com/lib/pq"
	"strings"

	"backend/internal/models"
)

var ErrUserNotFound = errors.New("user not found")
var ErrEmailAlreadyExists = errors.New("email already exists")

type UserRepository struct {
	DB *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{DB: db}
}

func (r *UserRepository) Create(ctx context.Context, u models.User) error {
	u.Email = strings.ToLower(strings.TrimSpace(u.Email))
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	// Serialize normalized-email registrations without changing the schema.
	if _, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "registration-email:"+u.Email); err != nil {
		return err
	}
	var exists bool
	if err := tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE lower(btrim(email))=$1)`, u.Email).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return ErrEmailAlreadyExists
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO users (
			id, username, email, password_hash,
			created_at, updated_at, version, is_deleted
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`,
		u.ID, u.Username, u.Email, u.PasswordHash,
		u.CreatedAt, u.UpdatedAt, u.Version, u.IsDeleted,
	)
	if err != nil {
		var conflict *pq.Error
		if errors.As(err, &conflict) && conflict.Code == "23505" && conflict.Constraint == "users_email_key" {
			return ErrEmailAlreadyExists
		}
		return err
	}
	return tx.Commit()
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (models.User, error) {
	row := r.DB.QueryRowContext(ctx, `
		SELECT id, username, email, password_hash, created_at, updated_at, version, is_deleted
		FROM users
		WHERE lower(btrim(email)) = $1 AND is_deleted = false
	`, strings.ToLower(strings.TrimSpace(email)))
	var u models.User
	err := row.Scan(
		&u.ID,
		&u.Username,
		&u.Email,
		&u.PasswordHash,
		&u.CreatedAt,
		&u.UpdatedAt,
		&u.Version,
		&u.IsDeleted,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return models.User{}, ErrUserNotFound
	}
	return u, err
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (models.User, error) {
	row := r.DB.QueryRowContext(ctx, `
		SELECT id, username, email, password_hash, created_at, updated_at, version, is_deleted
		FROM users
		WHERE id = $1 AND is_deleted = false
	`, id)
	var u models.User
	err := row.Scan(
		&u.ID,
		&u.Username,
		&u.Email,
		&u.PasswordHash,
		&u.CreatedAt,
		&u.UpdatedAt,
		&u.Version,
		&u.IsDeleted,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return models.User{}, ErrUserNotFound
	}
	return u, err
}

func (r *UserRepository) GetByID(id string) (*models.User, error) {
	var user models.User
	err := r.DB.QueryRow(`
		SELECT id, username, email, password_hash, is_deleted
		FROM users
		WHERE id = $1
	`, id).Scan(&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.IsDeleted)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) UpdatePassword(userID, newHash string) error {
	_, err := r.DB.Exec(`
		UPDATE users
		SET password_hash = $1,
		    updated_at = NOW(),
		    version = version + 1
		WHERE id = $2 AND is_deleted = FALSE
	`, newHash, userID)
	return err
}

func (r *UserRepository) SoftDeleteUser(userID string) error {
	_, err := r.DB.Exec(`
		UPDATE users
		SET is_deleted = TRUE,
		    updated_at = NOW(),
		    version = version + 1
		WHERE id = $1
	`, userID)
	return err
}

func (r *UserRepository) UpdateUsername(userID, username string) error {
	_, err := r.DB.Exec(`
		UPDATE users
		SET username = $1,
		    updated_at = NOW(),
		    version = version + 1
		WHERE id = $2 AND is_deleted = FALSE
	`, username, userID)
	return err
}
