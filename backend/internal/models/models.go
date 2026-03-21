package models

type Deck struct {
	ID          string `json:"id"`
	UserID      string `json:"user_id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	IsPublic    bool   `json:"is_public"`
}

type Card struct {
	ID     string `json:"id"`
	DeckID string `json:"deck_id"`
	Front  string `json:"front"`
	Back   string `json:"back"`
	State  string `json:"state"`
}
