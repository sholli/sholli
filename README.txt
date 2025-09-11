================================
Gold Secret Code - README
================================

Thank you for using the Gold Secret Code indicator. This guide will help you with installation and configuration.

---
## Installation
---
1. Open your MetaTrader 4 terminal.
2. Go to `File` -> `Open Data Folder`.
3. Navigate to the `MQL4` -> `Indicators` folder.
4. Copy the `GoldSecretCode.mq4` file into this folder.
5. Restart MetaTrader 4 or right-click on the "Indicators" folder in the Navigator panel and select "Refresh".
6. The indicator will appear under "Custom Indicators" in the Navigator panel. Drag it onto your XAUUSD M1 chart.

---
## Parameter Explanations
---

### Trend Settings
- **FastEMA_Period**: The period for the fast-moving average used for trend detection.
- **SlowEMA_Period**: The period for the slow-moving average. Trend is bullish when Fast > Slow.
- **TrendStrength_Min**: The minimum required trend strength (calculated via ATR) for a signal to be valid.

### Momentum Settings
- **RSI_Period**: The lookback period for the Relative Strength Index.
- **Stoch_K, Stoch_D, Stoch_Slowing**: Standard parameters for the Stochastic Oscillator.

### Volatility Settings
- **ATR_Period**: The lookback period for the Average True Range, used for volatility and strength calculations.
- **ATR_Multiplier**: A multiplier for the ATR to detect volatility expansion breakouts.

### Price Action Settings
- **SwingLookback**: The number of bars to look back to identify swing highs and lows for price action confirmation signals.

### Signal Continuation
- **EnableSignalContinuation**: If true, allows the indicator to generate additional signals in the direction of a strong trend.
- **Continuation_Min_Bars**: The minimum number of bars that must pass before a continuation signal can appear.
- **Continuation_Max_Bars**: The maximum number of bars after which the continuation opportunity expires.
- **Continuation_ATR_Move**: The required price movement (in multiples of ATR) in the trend's direction to trigger a continuation signal.

### Time Filter
- **EnableTimeFilter**: Turns the time filter on or off.
- **StartTime / EndTime**: Defines the active trading session (uses your broker's server time).
- **AvoidAsianSession**: A quick toggle to disable trading during the typically lower-volatility Asian session (approx. 23:00-08:00 server time).

### Visual & Alert Settings
- **Buy/SellArrowColor**: Sets the color for the signal arrows.
- **ArrowSize**: Sets the size of the arrows on the chart.
- **ArrowDistance_Pips**: How far (in pips) below/above the candle the arrow should be drawn.
- **ShowAlerts**: Enables MT4's pop-up alerts.
- **SendNotifications**: Enables push notifications to your mobile device (requires configuration in MT4).
- **DebugMode**: Displays a comment on the chart with live indicator values for troubleshooting.

---
## Trading Recommendations
---
- **Asset**: This indicator is optimized for XAUUSD (Gold).
- **Timeframe**: Best results are typically on M1, but it can be tested on M5 and M15.
- **Confirmation**: As with any indicator, it is recommended to use it as part of a complete trading plan, including your own risk management and confirmation strategies.
- **Backtesting**: Always backtest your settings thoroughly in the Strategy Tester before using on a live account.

---
## Troubleshooting
---
- **No arrows appear**:
  - Check the "Experts" and "Journal" tabs in the Terminal window for any error messages.
  - Ensure you have enough historical data on your chart.
  - The filtering conditions may be too strict for the current market; try adjusting them.
- **Alerts not working**:
  - Ensure `ShowAlerts` is set to `true`.
  - Check your MT4 options (`Tools -> Options -> Events`) to make sure alerts are enabled globally.
- **Compiler Errors**: If you face issues compiling, ensure your MetaEditor is updated to the latest build. The code is written to be compatible with modern MT4 builds (1090+).
