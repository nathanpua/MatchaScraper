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

func init() {
	// Load .env file. If it's not found, we'll rely on the system's environment variables.
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on environment variables.")
	}
}

// SendTelegramRestockAlert sends a formatted restock notification to your Telegram chat.
func SendTelegramRestockAlert(brandName, productName string) {
	token := os.Getenv("TELEGRAM_TOKEN")
	chatIdStr := os.Getenv("TELEGRAM_CHAT_ID")

	if token == "" || chatIdStr == "" {
		log.Println("TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set. Skipping notification.")
		return
	}

	chatId, err := strconv.ParseInt(chatIdStr, 10, 64)
	if err != nil {
		log.Printf("Error parsing TELEGRAM_CHAT_ID: %v", err)
		return
	}

	bot, err := tgbotapi.NewBotAPI(token)
	if err != nil {
		log.Printf("Error creating Telegram bot: %v", err)
		return
	}

	// Escape the product name to ensure it's safe for MarkdownV2 formatting.
	escapedProductName := escapeMarkdownV2(productName)
	message := fmt.Sprintf("🍵 %s IN STOCK: *%s*", brandName, escapedProductName)

	msg := tgbotapi.NewMessage(chatId, message)
	msg.ParseMode = tgbotapi.ModeMarkdownV2 // Use MarkdownV2 for bolding.

	if _, err := bot.Send(msg); err != nil {
		log.Printf("Error sending Telegram message: %v", err)
	} else {
		log.Printf("Successfully sent restock notification for: %s", productName)
	}
}

// SendTelegramSummaryAlert sends a formatted summary notification to your Telegram chat.
func SendTelegramSummaryAlert(brandName, websiteURL string, restockedCount int) {
	token := os.Getenv("TELEGRAM_TOKEN")
	chatIdStr := os.Getenv("TELEGRAM_CHAT_ID")

	if token == "" || chatIdStr == "" {
		log.Println("TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set. Skipping summary notification.")
		return
	}

	chatId, err := strconv.ParseInt(chatIdStr, 10, 64)
	if err != nil {
		log.Printf("Error parsing TELEGRAM_CHAT_ID: %v", err)
		return
	}

	bot, err := tgbotapi.NewBotAPI(token)
	if err != nil {
		log.Printf("Error creating Telegram bot: %v", err)
		return
	}

	message := fmt.Sprintf("🍵 *%s IS IN STOCK*\nTotal Principal Matcha in stock: %d\n🔗 Link:\n%s", brandName, restockedCount, websiteURL)

	msg := tgbotapi.NewMessage(chatId, message)
	msg.ParseMode = tgbotapi.ModeMarkdownV2
	msg.DisableWebPagePreview = false

	if _, err := bot.Send(msg); err != nil {
		log.Printf("Error sending Telegram summary message: %v", err)
	} else {
		log.Printf("Successfully sent restock summary for: %s", brandName)
	}
}

// escapeMarkdownV2 escapes characters that are special in Telegram's MarkdownV2 format.
func escapeMarkdownV2(s string) string {
	charsToEscape := []string{"_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"}
	for _, char := range charsToEscape {
		s = strings.ReplaceAll(s, char, "\\"+char)
	}
	return s
}
