# 🚀 NeVark – AI-Powered Stock Intelligence Platform

NeVark is a Flutter-based stock intelligence platform designed to help retail investors make informed decisions through real-time market data, AI-driven predictions, sector analysis, sentiment analysis, and an intelligent stock research assistant.

---

# 📌 Features

## 📈 Real-Time Market Data

* Live NSE stock prices
* NIFTY 50 tracking
* BANKNIFTY tracking
* FINNIFTY tracking
* Market status monitoring
* Automatic data refresh

---

## 🤖 AI Stock Intelligence

For every stock:

* Current Price
* Day Change
* Trend Analysis
* BUY / SELL / HOLD Signal
* Confidence Score
* Risk Assessment
* Reasoning Engine

---

## 📊 Technical Analysis

Supported indicators:

* RSI (Relative Strength Index)
* EMA (Exponential Moving Average)
* SMA (Simple Moving Average)
* MACD
* Bollinger Bands
* ATR (Average True Range)
* Volume Trend Analysis
* Volatility Analysis

Technical indicators are translated into beginner-friendly explanations.

---

## 🏢 Sector Intelligence

Supported sectors:

* Information Technology
* Banking
* Pharma
* Energy
* FMCG
* Auto
* Telecom
* Real Estate
* Metals
* Agriculture

Each sector provides:

* Bullish / Bearish / Neutral Outlook
* Confidence Score
* Sector Strength
* Top Performing Stocks
* Weak Stocks
* Sector Reasoning

---

## 🧠 Prediction Engine

Prediction system combines:

* Historical Price Data
* Volume Analysis
* Technical Indicators
* Sector Performance
* Market Trend
* News Sentiment

Outputs:

* BUY
* SELL
* HOLD

with confidence, risk level, and reasoning.

---

## 💬 AI Stock Research Assistant

NeVark includes a domain-restricted stock market chatbot.

Supported queries:

* Stock Analysis
* Sector Analysis
* Market Outlook
* Technical Analysis
* Stock Comparison
* Prediction Explanation
* News Analysis

Example:

```text
Analyze TCS

Should I buy Infosys?

Compare HDFC Bank and ICICI Bank

How is the IT sector?

What is the NIFTY outlook?
```

---

## 📰 Smart News Engine

News system provides:

* Market News
* Stock-Specific News
* Sector News
* Trending News

Features:

* Sentiment Analysis
* Positive / Negative / Neutral Classification
* Sector Mapping
* Stock Mapping
* Impact Scoring

---

## ⭐ Watchlist

Users can:

* Add stocks
* Remove stocks
* Track live prices
* Monitor predictions
* View stock signals

---

## 🔐 Authentication

Powered by Firebase Authentication.

Features:

* Sign Up
* Sign In
* Forgot Password
* Logout
* Session Persistence

---

## 👤 User Profile

Profile includes:

* User Information
* Watchlist Statistics
* Prediction Statistics
* Notification Preferences
* Security Settings
* About NeVark

---

# 🏗️ Tech Stack

## Frontend

* Flutter
* Dart
* Riverpod

## Backend

* Firebase Authentication
* Cloud Firestore

## APIs

* Angel One Smart API
* Market Data APIs
* News APIs

## State Management

* Riverpod

## Local Storage

* Shared Preferences

---

# 📂 Project Structure

```text
lib/

├── core/
│   ├── services/
│   ├── models/
│   ├── providers/
│   └── utils/
│
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── watchlist/
│   ├── chatbot/
│   ├── news/
│   ├── profile/
│   ├── prediction/
│   ├── sectors/
│   └── stocks/
│
├── firebase_options.dart
└── main.dart
```

---

# ⚙️ Installation

## Clone Repository

```bash
git clone <repository-url>
cd nevark_app
```

## Install Dependencies

```bash
flutter pub get
```

## Run Application

```bash
flutter run
```

---

# 🔥 Firebase Setup

1. Create a Firebase Project.
2. Enable Authentication.
3. Enable Firestore Database.
4. Configure Android/iOS apps.
5. Generate FlutterFire configuration.

```bash
flutterfire configure
```

---

# 📊 Future Enhancements

* Advanced ML Forecasting
* Portfolio Analytics
* Smart Alerts
* Notification Engine
* FII/DII Tracking
* Global Market Analytics
* Enhanced News Intelligence
* AI Portfolio Advisor

---

# ⚠ Disclaimer

NeVark provides educational and informational insights only.

All predictions, signals, forecasts, and analyses are generated using technical indicators, statistical models, and market data.

This application does NOT provide financial advice.

Users should perform their own research before making investment decisions.

Invest at your own risk.

---

# 👨‍💻 Developed By

NeVark Technologies LLP

AI-Powered Stock Intelligence Platform
