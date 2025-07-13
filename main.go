package main

import (
	"fmt"
	"log"
	"time"
)

// productStates stores the stock status of each product between checks.
// Key: product name, Value: in-stock status (true/false)
var productStates = make(map[string]bool)

func main() {
	ticker := time.NewTicker(CheckInterval)
	defer ticker.Stop()

	timeout := time.After(RunDuration)

	log.Println("Starting stock monitoring...")

	// Perform an initial check immediately
	log.Println("Running initial stock check...")
	runChecks()

	for {
		select {
		case <-timeout:
			log.Println("Monitoring complete after 1 hour.")
			return
		case <-ticker.C:
			log.Println("Running stock check...")
			runChecks()
		}
	}
}

func runChecks() {
	ippodoProducts := ScrapeIppodo(IppodoURL)
	nakamuraProducts := ScrapeNakamura(NakamuraURL)

	// processProducts checks for restocks, updates the global state, and prints the summary.
	processProducts := func(products []Product, siteName, siteURL string) {
		fmt.Printf("\n--- %s ---\n", siteName)
		var restockedProducts []string

		for _, p := range products {
			// If the product was previously known to be out of stock and is now in stock, alert it.
			if previousState, exists := productStates[p.Name]; exists && !previousState && p.InStock {
				fmt.Printf("🚨 RESTOCK ALERT: %s is back in stock!\n", p.Name)
				SendTelegramRestockAlert(siteName, p.Name)
				restockedProducts = append(restockedProducts, p.Name)
			}

			// Update the current state of the product.
			productStates[p.Name] = p.InStock

			// Print the summary line for the product.
			fmt.Printf("Product: %s, Price: %s, In Stock: %v\n", p.Name, p.Price, p.InStock)
		}

		if len(restockedProducts) > 0 {
			SendTelegramSummaryAlert(siteName, siteURL, len(restockedProducts))
		}
	}

	fmt.Println("--- Stock Summary ---")
	processProducts(ippodoProducts, "Ippodo", IppodoURL)
	processProducts(nakamuraProducts, "Nakamura", NakamuraURL)
	fmt.Println("--------------------")
}
