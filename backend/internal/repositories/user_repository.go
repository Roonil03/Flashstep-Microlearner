package repositories

import (
	"context"
	"database/sql"
	"errors"

	"backend/internal/models"
)

var ErrUserNotFound = errors.New("user not found")

type UserRepository struct {
	DB *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{DB: db}
}

func (r *UserRepository) Create(ctx context.Context, u models.User) error {
	_, err := r.DB.ExecContext(ctx, `
		INSERT INTO users (
			id, username, email, password_hash,
			created_at, updated_at, version, is_deleted
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`,
		u.ID, u.Username, u.Email, u.PasswordHash,
		u.CreatedAt, u.UpdatedAt, u.Version, u.IsDeleted,
	)
	return err
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (models.User, error) {
	row := r.DB.QueryRowContext(ctx, `
		SELECT id, username, email, password_hash, created_at, updated_at, version, is_deleted
		FROM users
		WHERE email = $1 AND is_deleted = false
	`, email)
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
