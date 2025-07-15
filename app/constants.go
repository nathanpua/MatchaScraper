package main

import (
	"time"
)

const (
	IppodoURL     = "https://global.ippodo-tea.co.jp/collections/matcha"
	NakamuraURL   = "https://global.tokichi.jp/collections/matcha"
	MarukyuURL    = "https://www.marukyu-koyamaen.co.jp/english/shop/products/catalog/matcha/principal"
	RunDuration   = 12 * time.Hour
	CheckInterval = 30 * time.Second
)
