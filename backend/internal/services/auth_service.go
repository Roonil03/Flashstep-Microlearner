package services

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"backend/internal/models"
	"backend/internal/repositories"
	"backend/pkg/utils"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrEmailAlreadyExists = errors.New("email already exists")
)

type AuthService struct {
	users     *repositories.UserRepository
	jwtSecret string
	jwtTTL    time.Duration
}

type RegisterInput struct {
	Username string
	Email    string
	Password string
}

type LoginInput struct {
	Email    string
	Password string
}

type AuthResponse struct {
	User  models.UserPublic `json:"user"`
	Token string            `json:"token"`
}

func NewAuthService(users *repositories.UserRepository, jwtSecret string, ttl time.Duration) *AuthService {
	return &AuthService{
		users:     users,
		jwtSecret: jwtSecret,
		jwtTTL:    ttl,
	}
}

func (s *AuthService) Register(ctx context.Context, input RegisterInput) (AuthResponse, error) {
	input.Username = strings.ToLower(strings.TrimSpace(input.Username))
	input.Email = strings.ToLower(strings.TrimSpace(input.Email))
	input.Password = strings.TrimSpace(input.Password)
	if len(input.Password) < 8 {
		return AuthResponse{}, errors.New("password must be at least 8 characters")
	}
	if input.Username == "" || input.Email == "" || input.Password == "" {
		return AuthResponse{}, errors.New("username, email and password are required")
	}
	if _, err := s.users.FindByEmail(ctx, input.Email); err == nil {
		return AuthResponse{}, ErrEmailAlreadyExists
	} else if err != repositories.ErrUserNotFound {
		return AuthResponse{}, err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return AuthResponse{}, err
	}
	now := time.Now().UTC()
	user := models.User{
		ID:           uuid.NewString(),
		Username:     input.Username,
		Email:        input.Email,
		PasswordHash: string(hash),
		CreatedAt:    now,
		UpdatedAt:    now,
		Version:      1,
		IsDeleted:    false,
	}
	if err := s.users.Create(ctx, user); err != nil {
		if strings.Contains(err.Error(), "duplicate") {
			return AuthResponse{}, ErrEmailAlreadyExists
		}
		return AuthResponse{}, err
	}
	token, err := utils.GenerateJWT(s.jwtSecret, user.ID, user.Email, s.jwtTTL)
	if err != nil {
		return AuthResponse{}, err
	}
	return AuthResponse{
		User:  user.Public(),
		Token: token,
	}, nil
}

func (s *AuthService) Login(ctx context.Context, input LoginInput) (AuthResponse, error) {
	input.Email = strings.ToLower(strings.TrimSpace(input.Email))
	input.Password = strings.TrimSpace(input.Password)
	user, err := s.users.FindByEmail(ctx, input.Email)
	if err != nil {
		return AuthResponse{}, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		return AuthResponse{}, ErrInvalidCredentials
	}
	token, err := utils.GenerateJWT(s.jwtSecret, user.ID, user.Email, s.jwtTTL)
	if err != nil {
		return AuthResponse{}, err
	}
	return AuthResponse{
		User:  user.Public(),
		Token: token,
	}, nil
}

func (s *AuthService) Me(ctx context.Context, userID string) (models.UserPublic, error) {
	user, err := s.users.FindByID(ctx, userID)
	if err != nil {
		return models.UserPublic{}, err
	}
	return user.Public(), nil
}
