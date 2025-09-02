# 🛠 Timed Stop-Loss Remover EA for MetaTrader 5

A **MetaTrader 5 Expert Advisor (EA)** that temporarily removes stop-losses (SL) from all open positions at a specified **Start time** and restores them at a specified **End time**. Ideal for traders who want precise control over SLs during high-volatility periods such as the daily spread hour or specific market events.

---

## 🔹 Features

* ✅ Remove SLs from **all open positions** at a custom time
* ✅ Restore original SLs at a later custom time
* ✅ Works for **both BUY and SELL positions**
* ✅ Preserves Take-Profit (TP) levels, leaving them unchanged
* ✅ Runs on **any chart**, affecting all symbols in your account
* ✅ Fully configurable via **input parameters**

---

## ⚙️ Input Parameters

| Parameter | Description                         |
| --------- | ----------------------------------- |
| `Start`   | Time to remove SLs (HH\:MM format)  |
| `End`     | Time to restore SLs (HH\:MM format) |

> **Example:**
> `Start = "15:30"` → Remove SLs at 3:30 PM
> `End = "15:45"` → Restore SLs at 3:45 PM
### Important: The EA uses the brokers time. My prop firm (the5ers) uses UTC+3, so the default specified times are 23:50 (22:50 UTC+2) and 01:15 (00:15 UTC+2).

---

## 📌 How It Works

1. Scans **all open positions** in your account.
2. At `Start` time → sets SL to **0** (temporarily removed)
3. Records the **original SL** for each position
4. At `End` time → restores the original SLs while keeping TP unchanged
5. Operates **once per tick** for accuracy

---

## 📥 Installation

1. Place the compiled `.ex5` EA into your MT5 `Experts` folder:

```
MetaTrader 5\MQL5\Experts\
```

2. Restart MT5 or refresh the Navigator panel
3. Attach the EA to **any chart**
4. Configure your desired **Start** and **End** times

> ⚠️ Make sure times match your **broker server time**

---

## 📝 Important Notes

* The EA **affects all open positions**, not just the chart symbol
* SL removal is **temporary** — original SLs are restored automatically
* Test first on a **demo account** to ensure correct behavior

---

## 🎯 Recommended Use Cases

* During **major news events** to avoid accidental SL hits
* Temporary removal of SLs to **manage positions manually**

---

## 💾 Releases

* Only the **compiled EA (`.ex5`)** is included in releases
* Source code is **not included**

> Users can download the `.ex5` from the [Releases](https://github.com/) section of this repository

---

## 🆘 Support

For issues or feature requests, please create an **issue** in this repository.

---

### ✅ Tips for a Professional Look

* Use **emojis** for visual cues (like ✅, ⚠️, 🛠, 🎯)
* Use **horizontal lines (`---`)** to separate sections
* Use **bold** for important terms
* Tables for parameters make input options clear
