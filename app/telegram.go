package main

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/joho/godotenv"
)

// TelegramService holds the bot instance and chat ID.
type TelegramService struct {
	Bot    *tgbotapi.BotAPI
	ChatID int64
}

// NewTelegramService initializes the Telegram bot and returns a service struct.
func NewTelegramService() (*TelegramService, error) {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on environment variables.")
	}

	token := os.Getenv("TELEGRAM_TOKEN")
	chatIDStr := os.Getenv("TELEGRAM_CHAT_ID")

	if token == "" || chatIDStr == "" {
		return nil, fmt.Errorf("TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set")
	}

	chatID, err := strconv.ParseInt(chatIDStr, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("error parsing TELEGRAM_CHAT_ID: %w", err)
	}

	bot, err := tgbotapi.NewBotAPI(token)
	if err != nil {
		return nil, fmt.Errorf("error creating Telegram bot: %w", err)
	}

	return &TelegramService{Bot: bot, ChatID: chatID}, nil
}

// SendMessage sends a formatted message to the configured Telegram chat.
func (ts *TelegramService) SendMessage(text string, disablePreview bool) {
	msg := tgbotapi.NewMessage(ts.ChatID, text)
	msg.ParseMode = tgbotapi.ModeHTML
	msg.DisableWebPagePreview = disablePreview

	if _, err := ts.Bot.Send(msg); err != nil {
		log.Printf("Error sending Telegram message: %v", err)
	}
}

// SendTelegramRestockAlert sends a formatted restock notification.
func SendTelegramRestockAlert(brandName, productName, link string) {
	service, err := NewTelegramService()
	if err != nil {
		log.Printf("Failed to initialize Telegram service: %v", err)
		return
	}
	message := fmt.Sprintf("🍵 %s IN STOCK:\n📦 <b>%s</b>\n🔗 %s", strings.ToUpper(brandName), productName, link)
	service.SendMessage(message, true)
	log.Printf("Successfully sent restock notification for: %s", productName)
}
