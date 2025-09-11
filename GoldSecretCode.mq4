//+------------------------------------------------------------------+
//|                                               GoldSecretCode.mq4 |
//|                             Copyright 2024, Your Name (Generated)|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name (Generated)"
#property version   "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   2

//---- Plot definitions
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  2
#property indicator_style1  STYLE_SOLID
#property indicator_arrow1  233

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_style2  STYLE_SOLID
#property indicator_arrow2  234

//+------------------------------------------------------------------+
//| Input Parameters (User Configurable)                             |
//+------------------------------------------------------------------+
input group "=== TREND SETTINGS ===";
input int FastEMA_Period = 8;
input int SlowEMA_Period = 21;
input double TrendStrength_Min = 0.5;

input group "=== MOMENTUM SETTINGS ===";
input int RSI_Period = 14;
input int Stoch_K = 5;
input int Stoch_D = 3;
input int Stoch_Slowing = 3;

input group "=== VOLATILITY SETTINGS ===";
input int ATR_Period = 14;
input double ATR_Multiplier = 1.5;

input group "=== PRICE ACTION SETTINGS ===";
input int SwingLookback = 5;

input group "=== SIGNAL CONTINUATION ===";
input bool EnableSignalContinuation = true;
input int Continuation_Min_Bars = 3; // Min bars between continuation signals
input int Continuation_Max_Bars = 5; // Max bars between continuation signals
input double Continuation_ATR_Move = 0.5; // ATR move required to trigger continuation

input group "=== TIME FILTER ===";
input bool EnableTimeFilter = true;
input string StartTime = "08:00"; // London Open
input string EndTime = "22:00"; // New York Close
input bool AvoidAsianSession = false;

input group "=== VISUAL SETTINGS ===";
input color BuyArrowColor = clrLimeGreen;
input color SellArrowColor = clrRed;
input int ArrowSize = 2;
input int ArrowDistance_Pips = 10;

input group "=== ALERT SETTINGS ===";
input bool ShowAlerts = true;
input bool SendNotifications = false;
input bool DebugMode = false;

//+------------------------------------------------------------------+
//| Indicator Buffers & Global Variables                             |
//+------------------------------------------------------------------+
//---- Indicator buffers
double BuyBuffer[];
double SellBuffer[];

//---- Helper buffers (non-plotted)
double FastEMABuffer[];
double SlowEMABuffer[];
double RSIBuffer[];
double ATRBuffer[];
double TrendStrengthBuffer[];
double VolumeBuffer[];

//---- Global variables
datetime LastSignalTime = 0;
int LastSignalType = 0; // 1=BUY, -1=SELL, 0=NONE
double LastSignalPrice = 0;
int BarsSinceLastSignal = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization Function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //---- Indicator buffers mapping
    SetIndexBuffer(0, BuyBuffer);
    SetIndexBuffer(1, SellBuffer);
    SetIndexBuffer(2, FastEMABuffer);
    SetIndexBuffer(3, SlowEMABuffer);
    SetIndexBuffer(4, RSIBuffer);
    SetIndexBuffer(5, ATRBuffer);
    SetIndexBuffer(6, TrendStrengthBuffer);
    SetIndexBuffer(7, VolumeBuffer);

    //---- Set plot styles
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, ArrowSize);
    SetIndexArrow(0, 233);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, ArrowSize);
    SetIndexArrow(1, 234);

    //---- Set plot colors from inputs
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, BuyArrowColor);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, SellArrowColor);

    //---- Set plot labels
    PlotIndexSetString(0, PLOT_LABEL, "Buy");
    PlotIndexSetString(1, PLOT_LABEL, "Sell");

    //---- Set draw begin
    int drawBegin = MathMax(FastEMA_Period, SlowEMA_Period);
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, drawBegin);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, drawBegin);

    //---- Set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

    //---- Set array as series for correct indexing
    ArraySetAsSeries(BuyBuffer, true);
    ArraySetAsSeries(SellBuffer, true);
    ArraySetAsSeries(FastEMABuffer, true);
    ArraySetAsSeries(SlowEMABuffer, true);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(ATRBuffer, true);
    ArraySetAsSeries(TrendStrengthBuffer, true);
    ArraySetAsSeries(VolumeBuffer, true);
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    //---- Validate inputs
    if (FastEMA_Period >= SlowEMA_Period)
    {
        Alert("Initialization Error: FastEMA_Period must be less than SlowEMA_Period.");
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
// Converts pips to a price offset, handling different digit counts
double PipsToPrice(int pips)
{
    // For XAUUSD, 1 pip is typically 0.01, but we use Point for precision
    if(StringFind(Symbol(), "XAU") != -1 || StringFind(Symbol(), "GOLD") != -1)
    {
        return(pips * 10 * _Point); // Assuming 2 or 3 digits, this is more robust
    }
    // Standard forex
    if(_Digits == 5 || _Digits == 3)
    {
        return(pips * 10 * _Point);
    }
    return(pips * _Point);
}

// Sends alerts and/or mobile notifications
void SendAlert(string message, int signalType)
{
    if(Time[0] == LastSignalTime) return; // Prevent duplicate alerts on same bar
    LastSignalTime = Time[0];

    if(ShowAlerts)
    {
        Alert(Symbol() + ", " + EnumToString((ENUM_TIMEFRAMES)Period()) + ": " + message);
    }
    if(SendNotifications)
    {
        SendNotification(message);
    }
}

//+------------------------------------------------------------------+
//| Filter & Condition Functions                                     |
//+------------------------------------------------------------------+
// Checks if the current server time is within the allowed trading session
bool IsTimeFilterActive()
{
    if(!EnableTimeFilter) return(true);

    int currentDayOfWeek = TimeDayOfWeek(TimeCurrent());
    string currentTimeStr = TimeToString(TimeCurrent(), TIME_MINUTES);

    // Handle Asian session avoidance (approx 23:00 - 08:00 server time)
    if(AvoidAsianSession)
    {
        if(StringSubstr(currentTimeStr, 0, 2) >= "23" || StringSubstr(currentTimeStr, 0, 2) < "08")
        {
            return(false);
        }
    }

    // Handle Custom Time Range
    if(StartTime < EndTime) // Normal same-day session
    {
        if(currentTimeStr < StartTime || currentTimeStr >= EndTime)
        {
            return(false);
        }
    }
    else // Overnight session (e.g., 23:00 - 08:00)
    {
        if(currentTimeStr < StartTime && currentTimeStr >= EndTime)
        {
            return(false);
        }
    }

    return(true);
}

// Gets the highest high value in a lookback period
double GetSwingHigh(int lookback, int shift)
{
    double result = 0;
    for(int i = shift + 1; i < shift + 1 + lookback; i++)
    {
        if(high[i] > result) result = high[i];
    }
    return(result);
}

// Gets the lowest low value in a lookback period
double GetSwingLow(int lookback, int shift)
{
    double result = 999999;
    for(int i = shift + 1; i < shift + 1 + lookback; i++)
    {
        if(low[i] < result) result = low[i];
    }
    return(result);
}


//+------------------------------------------------------------------+
//| Main OnCalculate Function                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    //---- Basic error handling
    if (rates_total < SlowEMA_Period + 50)
    {
        Comment("Insufficient data to calculate indicator.");
        return(0);
    }

    //---- Calculate how many bars to process
    int limit;
    if(prev_calculated > rates_total || prev_calculated <= 0)
    {
        limit = rates_total - 1;
    }
    else
    {
        limit = rates_total - prev_calculated;
    }

    //---- Calculate helper indicators
    for(int i = limit; i >= 0; i--)
    {
        FastEMABuffer[i] = iMA(Symbol(), Period(), FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i);
        SlowEMABuffer[i] = iMA(Symbol(), Period(), SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE, i);
        RSIBuffer[i] = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, i);
        ATRBuffer[i] = iATR(Symbol(), Period(), ATR_Period, i);
        VolumeBuffer[i] = volume[i];

        // Calculate Trend Strength
        if(ATRBuffer[i] > 0)
        {
            TrendStrengthBuffer[i] = MathAbs(FastEMABuffer[i] - SlowEMABuffer[i]) / ATRBuffer[i];
        } else {
            TrendStrengthBuffer[i] = 0;
        }
    }

    //---- Main signal detection loop starts from a bar where all data is available
    int start_bar = rates_total - limit - 1;
    if (start_bar < SlowEMA_Period + 2) start_bar = SlowEMA_Period + 2;

    for(int i = start_bar; i >= 0; i--)
    {
        //---- Initialize buffers for the current bar
        BuyBuffer[i] = 0;
        SellBuffer[i] = 0;

        //---- LAYER 1: Trend Detection
        bool isTrendBullish = FastEMABuffer[i] > SlowEMABuffer[i];
        bool isTrendBearish = FastEMABuffer[i] < SlowEMABuffer[i];

        //---- LAYER 2: Momentum Confirmation
        double stoch_main = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_MAIN, i);
        double stoch_signal = iStochastic(Symbol(), Period(), Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, 0, MODE_SIGNAL, i);
        bool isMomentumBullish = RSIBuffer[i] > 50 && stoch_main > stoch_signal && close[i] > FastEMABuffer[i];
        bool isMomentumBearish = RSIBuffer[i] < 50 && stoch_main < stoch_signal && close[i] < FastEMABuffer[i];

        //---- LAYER 3: Volatility Breakout
        double candleRange = high[i] - low[i];
        double avgVolume = iMAOnArray(VolumeBuffer, 0, 20, 0, MODE_SMA, i+1);
        bool isVolatilityExpansion = candleRange > (ATRBuffer[i] * ATR_Multiplier);

        //---- LAYER 4: Price Action Confirmation
        double swingHigh = GetSwingHigh(SwingLookback, i);
        double swingLow = GetSwingLow(SwingLookback, i);
        bool isPriceActionBuy = close[i] > swingHigh && close[i] > open[i] && close[i+1] < open[i+1] && (close[i] - open[i]) > (ATRBuffer[i] * 0.3);
        bool isPriceActionSell = close[i] < swingLow && close[i] < open[i] && close[i+1] > open[i+1] && (open[i] - close[i]) > (ATRBuffer[i] * 0.3);

        //---- SIGNAL GENERATION LOGIC

        // Reset if signal was on previous bar
        if (BuyBuffer[i+1]>0 || SellBuffer[i+1]>0) BarsSinceLastSignal = 0;
        else BarsSinceLastSignal++;

        // BUY SIGNAL CONDITIONS
        bool isValidBuy = isTrendBullish &&
                          isMomentumBullish &&
                          (isVolatilityExpansion || isPriceActionBuy) &&
                          close[i] > high[i+1] &&
                          RSIBuffer[i] > 45 &&
                          TrendStrengthBuffer[i] > TrendStrength_Min &&
                          IsTimeFilterActive();

        if(isValidBuy && BuyBuffer[i+1]==0 && SellBuffer[i+1]==0)
        {
            BuyBuffer[i] = low[i] - PipsToPrice(ArrowDistance_Pips);
            LastSignalType = 1;
            LastSignalPrice = close[i];
            SendAlert("Gold Secret Code: BUY Signal", 1);
            continue; // Skip to next bar after placing a signal
        }

        // SELL SIGNAL CONDITIONS
        bool isValidSell = isTrendBearish &&
                           isMomentumBearish &&
                           (isVolatilityExpansion || isPriceActionSell) &&
                           close[i] < low[i+1] &&
                           RSIBuffer[i] < 55 &&
                           TrendStrengthBuffer[i] > TrendStrength_Min &&
                           IsTimeFilterActive();

        if(isValidSell && BuyBuffer[i+1]==0 && SellBuffer[i+1]==0)
        {
            SellBuffer[i] = high[i] + PipsToPrice(ArrowDistance_Pips);
            LastSignalType = -1;
            LastSignalPrice = close[i];
            SendAlert("Gold Secret Code: SELL Signal", -1);
            continue;
        }

        //---- SIGNAL CONTINUATION SYSTEM
        if(EnableSignalContinuation && BarsSinceLastSignal >= Continuation_Min_Bars)
        {
            // Continuation BUY
            if(LastSignalType == 1 && isTrendBullish && close[i] > LastSignalPrice + (ATRBuffer[i] * Continuation_ATR_Move))
            {
                if(RSIBuffer[i] > 40 && close[i] > FastEMABuffer[i] && BarsSinceLastSignal <= Continuation_Max_Bars)
                {
                    BuyBuffer[i] = low[i] - PipsToPrice(ArrowDistance_Pips);
                    LastSignalPrice = close[i]; // Update price
                    BarsSinceLastSignal = 0; // Reset bar count
                    SendAlert("Gold Secret Code: Continuation BUY", 1);
                }
                else // Stop condition met
                {
                    LastSignalType = 0;
                }
            }

            // Continuation SELL
            else if(LastSignalType == -1 && isTrendBearish && close[i] < LastSignalPrice - (ATRBuffer[i] * Continuation_ATR_Move))
            {
                if(RSIBuffer[i] < 60 && close[i] < FastEMABuffer[i] && BarsSinceLastSignal <= Continuation_Max_Bars)
                {
                    SellBuffer[i] = high[i] + PipsToPrice(ArrowDistance_Pips);
                    LastSignalPrice = close[i];
                    BarsSinceLastSignal = 0;
                    SendAlert("Gold Secret Code: Continuation SELL", -1);
                }
                else // Stop condition met
                {
                    LastSignalType = 0;
                }
            }
        } else if (BarsSinceLastSignal > Continuation_Max_Bars) {
            LastSignalType = 0;
        }

        //---- Debug Output
        if (DebugMode && i == 0)
        {
            string debug = StringFormat("Bar %d | TrendStr: %.2f | RSI: %.2f | ATR: %.5f | LastSignal: %d",
                                       i, TrendStrengthBuffer[i], RSIBuffer[i], ATRBuffer[i], LastSignalType);
            Comment(debug);
        }
    }
    //----
    return(rates_total);
}
//+------------------------------------------------------------------+
