package main

import (
	"fmt"
	"log"
	"strings"

	"github.com/gocolly/colly"
)

// Product holds scraped product data.
type Product struct {
	Name    string
	Price   string
	InStock bool
	URL     string
}

// SiteConfig defines the selectors and rules for scraping a site.
type SiteConfig struct {
	URL              string
	ProductSelector  string
	NameSelector     string
	PriceSelector    string
	InStockSelector  string
	InStockText      string // Text indicating out of stock
	IsOutOfStockFunc func(*colly.HTMLElement) bool
	NameScraperFunc  func(*colly.HTMLElement) string // New field for custom name scraping
	Blacklist        []string
}

// ScrapeIppodo scrapes products from the Ippodo website.
func ScrapeIppodo(url string) ([]Product, error) {
	config := SiteConfig{
		URL:             url,
		ProductSelector: "li.m-product-card",
		NameSelector:    ".m-product-card__name",
		PriceSelector:   ".m-product-card__price",
		IsOutOfStockFunc: func(e *colly.HTMLElement) bool {
			return e.DOM.Find(".product-form__submit.out-of-stock").Length() > 0
		},
		Blacklist: []string{"Uji-Shimizu", "Fumi-no-tomo", "Packets"},
	}
	return scrapeIppodoWithLinks(config)
}

// scrapeIppodoWithLinks is a specialized function for Ippodo to capture product links
func scrapeIppodoWithLinks(config SiteConfig) ([]Product, error) {
	c := colly.NewCollector()
	var products []Product
	var scrapeErr error

	c.OnHTML(config.ProductSelector, func(e *colly.HTMLElement) {
		productName := strings.TrimSpace(e.ChildText(config.NameSelector))

		for _, blacklistedWord := range config.Blacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}

		// Extract the product URL from the link
		productURL := e.ChildAttr(".m-product-card__name a", "href")
		if productURL != "" && !strings.HasPrefix(productURL, "http") {
			productURL = "https://global.ippodo-tea.co.jp" + productURL
		}

		product := Product{
			Name:    productName,
			Price:   e.ChildText(config.PriceSelector),
			InStock: !config.IsOutOfStockFunc(e),
			URL:     productURL,
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		scrapeErr = fmt.Errorf("request to %s failed with status %d: %w", r.Request.URL, r.StatusCode, err)
		log.Println(scrapeErr)
	})

	c.Visit(config.URL)

	return products, scrapeErr
}

// ScrapeNakamura scrapes products from the Nakamura website.
func ScrapeNakamura(url string) ([]Product, error) {
	config := SiteConfig{
		URL:             url,
		ProductSelector: "li.grid__item",
		NameSelector:    "h3.card__heading a",
		NameScraperFunc: func(e *colly.HTMLElement) string {
			return strings.TrimSpace(e.DOM.Find("h3.card__heading a").First().Text())
		},
		PriceSelector: ".price__regular .price-item--regular",
		IsOutOfStockFunc: func(e *colly.HTMLElement) bool {
			return e.DOM.Find("span.badge:contains('Out of stock')").Length() > 0
		},
		Blacklist: []string{"Teaware", "Matcha Starter", "Matcha Standard"},
	}
	return scrapeNakamuraWithLinks(config)
}

// scrapeNakamuraWithLinks is a specialized function for Nakamura to capture product links
func scrapeNakamuraWithLinks(config SiteConfig) ([]Product, error) {
	c := colly.NewCollector()
	var products []Product
	var scrapeErr error

	c.OnHTML(config.ProductSelector, func(e *colly.HTMLElement) {
		var productName string
		if config.NameScraperFunc != nil {
			productName = config.NameScraperFunc(e)
		} else {
			productName = strings.TrimSpace(e.ChildText(config.NameSelector))
		}

		for _, blacklistedWord := range config.Blacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}

		// Extract the product URL from the link
		productURL := e.ChildAttr("h3.card__heading a", "href")
		if productURL != "" && !strings.HasPrefix(productURL, "http") {
			productURL = "https://global.tokichi.jp" + productURL
		}

		product := Product{
			Name:    productName,
			Price:   e.ChildText(config.PriceSelector),
			InStock: !config.IsOutOfStockFunc(e),
			URL:     productURL,
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		scrapeErr = fmt.Errorf("request to %s failed with status %d: %w", r.Request.URL, r.StatusCode, err)
		log.Println(scrapeErr)
	})

	c.Visit(config.URL)

	return products, scrapeErr
}

// ScrapeMarukyu scrapes products from the Marukyu website.
func ScrapeMarukyu(url string) ([]Product, error) {
	config := SiteConfig{
		URL:             url,
		ProductSelector: "li.product",
		NameSelector:    ".product-name h4",
		PriceSelector:   ".product-price .woocs_price_code.woocs_price_USD .woocommerce-Price-amount",
		IsOutOfStockFunc: func(e *colly.HTMLElement) bool {
			classes := e.Attr("class")
			return strings.Contains(classes, "outofstock")
		},
		Blacklist: []string{}, // Add blacklisted terms if needed
	}
	return scrapeMarukyuWithLinks(config)
}

// scrapeMarukyuWithLinks is a specialized function for Marukyu to capture product links
func scrapeMarukyuWithLinks(config SiteConfig) ([]Product, error) {
	c := colly.NewCollector()
	var products []Product
	var scrapeErr error

	c.OnHTML(config.ProductSelector, func(e *colly.HTMLElement) {
		var productName string
		if config.NameScraperFunc != nil {
			productName = config.NameScraperFunc(e)
		} else {
			productName = strings.TrimSpace(e.ChildText(config.NameSelector))
		}

		for _, blacklistedWord := range config.Blacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}

		// Extract the product URL from the link
		productURL := e.ChildAttr("a.woocommerce-loop-product__link", "href")

		product := Product{
			Name:    productName,
			Price:   e.ChildText(config.PriceSelector),
			InStock: !config.IsOutOfStockFunc(e),
			URL:     productURL,
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		scrapeErr = fmt.Errorf("request to %s failed with status %d: %w", r.Request.URL, r.StatusCode, err)
		log.Println(scrapeErr)
	})

	c.Visit(config.URL)

	return products, scrapeErr
}

// scrapeSite is a generic function to scrape a website based on a given configuration.
func scrapeSite(config SiteConfig) ([]Product, error) {
	c := colly.NewCollector()
	var products []Product
	var scrapeErr error

	c.OnHTML(config.ProductSelector, func(e *colly.HTMLElement) {
		var productName string
		if config.NameScraperFunc != nil {
			productName = config.NameScraperFunc(e)
		} else {
			productName = strings.TrimSpace(e.ChildText(config.NameSelector))
		}

		for _, blacklistedWord := range config.Blacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}

		product := Product{
			Name:    productName,
			Price:   e.ChildText(config.PriceSelector),
			InStock: !config.IsOutOfStockFunc(e),
			URL:     "", // Nakamura doesn't have individual product URLs in the listing
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		scrapeErr = fmt.Errorf("request to %s failed with status %d: %w", r.Request.URL, r.StatusCode, err)
		log.Println(scrapeErr)
	})

	c.Visit(config.URL)

	return products, scrapeErr
}
