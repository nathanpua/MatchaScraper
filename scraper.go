package main

import (
	"log"
	"strings"

	"github.com/gocolly/colly"
)

type Product struct {
	Name    string
	Price   string
	InStock bool
}

var ippodoBlacklist = []string{
	"Uji-Shimizu",
	"Fumi-no-tomo",
	"Packets",
}

var nakamuraBlacklist = []string{
	"Teaware",
	"Matcha Starter",
	"Matcha Standard",
}

func ScrapeIppodo(url string) []Product {
	c := colly.NewCollector()
	var products []Product

	c.OnHTML("li.m-product-card", func(e *colly.HTMLElement) {
		productName := e.ChildText(".m-product-card__name")

		for _, blacklistedWord := range ippodoBlacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}
		product := Product{
			Name:    productName,
			Price:   e.ChildText(".m-product-card__price"),
			InStock: e.DOM.Find(".product-form__submit.out-of-stock").Length() == 0,
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		log.Println("Request URL:", r.Request.URL, "failed with response:", r, "\nError:", err)
	})

	c.Visit(url)
	return products
}

func ScrapeNakamura(url string) []Product {
	c := colly.NewCollector()
	var products []Product

	c.OnHTML("li.grid__item", func(e *colly.HTMLElement) {
		productName := strings.TrimSpace(e.DOM.Find("h3.card__heading a").First().Text())

		for _, blacklistedWord := range nakamuraBlacklist {
			if strings.Contains(productName, blacklistedWord) {
				return // Skip blacklisted item
			}
		}
		product := Product{
			Name:    productName,
			Price:   e.ChildText(".price__regular .price-item--regular"),
			InStock: e.DOM.Find("span.badge:contains('Out of stock')").Length() == 0,
		}
		products = append(products, product)
	})

	c.OnError(func(r *colly.Response, err error) {
		log.Println("Request URL:", r.Request.URL, "failed with response:", r, "\nError:", err)
	})

	c.Visit(url)
	return products
}
