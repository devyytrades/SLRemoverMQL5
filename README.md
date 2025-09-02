Timed Stop-Loss Remover EA for MetaTrader 5

A simple yet powerful MetaTrader 5 Expert Advisor that temporarily removes stop-losses (SL) from all open positions at a specified time and restores them at a later specified time. Perfect for traders who want to manage SLs during specific market events or avoid accidental stops during high volatility periods.

Features

✅ Automatically removes SLs from all open positions at a customizable start time.

✅ Restores original SLs at a customizable end time.

✅ Works for both BUY and SELL positions.

✅ Preserves Take-Profit (TP) levels while modifying SLs.

✅ Operates on all symbols in your account, regardless of the chart it’s attached to.

✅ Fully configurable via input parameters.

Input Parameters
Parameter	Description
Start	Time when the EA removes stop-losses (format: HH:MM).
End	Time when the EA restores the original stop-losses (format: HH:MM).

Example:
Start = "15:30" → Remove SLs at 3:30 PM
End = "15:45" → Restore SLs at 3:45 PM

How It Works

The EA scans all open positions in your MT5 account.

At the Start time, it temporarily sets the SL of every position to 0, effectively removing them.

It records the original SL of each position in memory.

At the End time, it restores the original SLs while keeping the TP unchanged.

The EA runs on each tick and will only modify positions once per session.

Installation

Copy the compiled .ex5 file into your MT5 Experts folder:

MetaTrader 5\MQL5\Experts\


Restart MT5 or refresh the Navigator panel.

Attach the EA to any chart. It will work across all symbols in your account.

Set your desired Start and End times in the EA input parameters.

Important Notes

The EA will affect all open positions, regardless of the symbol.

Make sure your Start and End times are set according to the server time (MT5 platform time).

The EA does not delete stop-losses permanently — original SLs are restored at the specified End time.

Always test on a demo account first to ensure it works with your broker and trading setup.

Screenshots

(Optional: add screenshots of input settings and the EA running on a chart)

Support

If you encounter any issues or have feature requests, please create an issue in this repository.

License

This EA is free to use for personal trading purposes. Source code may be kept private in the repository.
