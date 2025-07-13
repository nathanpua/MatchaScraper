package main

import (
	"log"
	"sync"
	"time"
)

// productStates stores the stock status of each product between checks.
// Key: product name, Value: in-stock status (true/false)
var productStates = make(map[string]bool)

type ScrapeResult struct {
	Products []Product
	SiteName string
	SiteURL  string
	Error    error
}

func main() {
	// Use a channel to signal when monitoring is done.
	done := time.After(RunDuration)

	log.Println("Starting stock monitoring...")

	// Perform an initial check immediately.
	runChecks()

	// Ticker for periodic checks.
	ticker := time.NewTicker(CheckInterval)
	defer ticker.Stop()

	// Main loop for the application.
	for {
		select {
		case <-done:
			log.Printf("Monitoring complete after %v.", RunDuration)
			return
		case <-ticker.C:
			runChecks()
		}
	}
}

// runChecks initiates concurrent scraping tasks and processes the results.
func runChecks() {
	log.Println("Running stock check...")

	var wg sync.WaitGroup
	resultsChan := make(chan ScrapeResult, 2)

	tasks := []struct {
		siteName string
		siteURL  string
		scrapeFn func(string) ([]Product, error)
	}{
		{"Ippodo", IppodoURL, ScrapeIppodo},
		{"Nakamura", NakamuraURL, ScrapeNakamura},
	}

	for _, task := range tasks {
		wg.Add(1)
		go func(siteName, siteURL string, scrapeFn func(string) ([]Product, error)) {
			defer wg.Done()
			products, err := scrapeFn(siteURL)
			resultsChan <- ScrapeResult{Products: products, SiteName: siteName, SiteURL: siteURL, Error: err}
		}(task.siteName, task.siteURL, task.scrapeFn)
	}

	wg.Wait()
	close(resultsChan)

	log.Println("--- Stock Summary ---")
	for result := range resultsChan {
		if result.Error != nil {
			log.Printf("Error scraping %s: %v", result.SiteName, result.Error)
			continue
		}

		processProducts(result)
	}
	log.Println("--------------------")
}

// processProducts checks for restocks, updates the global state, and prints the summary.
func processProducts(result ScrapeResult) {
	log.Printf("--- %s ---", result.SiteName)
	var restockedProducts []string

	for _, p := range result.Products {
		// If the product was previously known to be out of stock and is now in stock, alert it.
		if previousState, exists := productStates[p.Name]; exists && !previousState && p.InStock {
			log.Printf("🚨 RESTOCK ALERT: %s is back in stock!", p.Name)
			SendTelegramRestockAlert(result.SiteName, p.Name)
			restockedProducts = append(restockedProducts, p.Name)
		}

		// Update the current state of the product.
		productStates[p.Name] = p.InStock

		// Print the summary line for the product.
		log.Printf("Product: %s, Price: %s, In Stock: %v", p.Name, p.Price, p.InStock)
	}

	if len(restockedProducts) > 0 {
		SendTelegramSummaryAlert(result.SiteName, result.SiteURL, len(restockedProducts))
	}
}
