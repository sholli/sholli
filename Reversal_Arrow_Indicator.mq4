//+------------------------------------------------------------------+
//|                                       Reversal_Arrow_Indicator.mq4 |
//|                                       Copyright 2025, Jules |
//|                                 https://github.com/Jules-the-AI |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules"
#property link      "https://github.com/Jules-the-AI"
#property version   "2.0"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2
//--- plot BuySignal
#property indicator_label1  "Buy Arrow"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime // Will be overridden in OnInit
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2       // Will be overridden in OnInit
//--- plot SellSignal
#property indicator_label2  "Sell Arrow"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed  // Will be overridden in OnInit
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2       // Will be overridden in OnInit

// ---------------- INPUT PARAMETERS ----------------
input group "Core Signal Settings"
input ENUM_TIMEFRAMES     PrimaryTrendTF = PERIOD_H4;     // Primary Trend Timeframe
input int                 HTF_FastMA_Period = 20;         // HTF Fast MA Period
input int                 HTF_SlowMA_Period = 50;         // HTF Slow MA Period

input group "Oscillator Settings"
input int                 Osc_Period = 14;                // Oscillator Period (RSI)
input double              Overbought_Level = 70;          // Overbought Line
input double              Oversold_Level = 30;            // Oversold Line

input group "Support & Resistance"
input int                 SR_Lookback = 100;              // Bars to look for S/R
input int                 SR_ZoneWidth = 50;              // Zone width in points

input group "Candlestick Patterns"
input bool                Enable_Engulfing = true;        // Enable Engulfing Pattern Filter
input bool                Enable_Hammer = true;           // Enable Hammer/Shooting Star Filter

input group "Volume & Quality Filters"
input int                 Vol_Lookback = 20;              // Periods for Avg Volume
input double              Vol_Multiplier = 1.5;           // Min Volume Spike Factor
input int                 ADX_Period = 14;                // ADX Period
input int                 ADX_Threshold = 20;             // Min ADX Value

input group "Appearance & Alerts"
input int                 Arrow_Size = 2;                 // Arrow Size (1-5)
input color               Buy_Arrow_Color = clrLime;      // Buy Color
input color               Sell_Arrow_Color = clrRed;      // Sell Color
input bool                EnableAlerts = true;            // Enable Alerts
input bool                EnablePopUpAlerts = true;       // Enable Pop-up Alerts

//--- Indicator buffers
double BuySignalBuffer[];
double SellSignalBuffer[];
double MomentumBuffer[];
double TrendBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, BuySignalBuffer);
   SetIndexBuffer(1, SellSignalBuffer);
   SetIndexBuffer(2, MomentumBuffer);
   SetIndexBuffer(3, TrendBuffer);

//--- Set plot styles from inputs
   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, Arrow_Size, Buy_Arrow_Color);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, Arrow_Size, Sell_Arrow_Color);

//--- Set arrow codes for buffers (using Wingdings font)
   SetIndexArrow(0, 233); // Up Arrow
   SetIndexArrow(1, 234); // Down Arrow

//--- Set empty value for buffers
   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, 0.0);
   SetIndexEmptyValue(3, 0.0);

//--- Set labels
   IndicatorSetString(INDICATOR_SHORTNAME, "Reversal Arrow");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
//--- Ensure we have enough bars to calculate
   int barsRequired = MathMax(Vol_Lookback, MathMax(ADX_Period, Osc_Period)) + 2;
   if(rates_total < barsRequired)
      return(0);

//--- Correctly determine the starting bar for the calculation loop
   int limit;
   if(prev_calculated == 0)
      limit = rates_total - barsRequired;
   else
      limit = rates_total - prev_calculated;

//--- Main calculation loop
   for(int i = limit; i >= 0; i--)
     {
      // We process bar 'i+1' to ensure it's a closed bar and avoid repainting
      int shift = i + 1;

      //--- Reset signals for the current bar
      BuySignalBuffer[shift] = EMPTY_VALUE;
      SellSignalBuffer[shift] = EMPTY_VALUE;

      //--- Calculate Indicator Values ---
      TrendBuffer[shift] = getHTFTrend(shift);
      MomentumBuffer[shift] = getMomentumValue(shift);

      //--- Define Filter Conditions ---
      int htfTrend = (int)TrendBuffer[shift];

      // 1. Momentum Condition (Oversold/Overbought)
      bool isOversold = MomentumBuffer[shift] < Oversold_Level && MomentumBuffer[shift] > MomentumBuffer[shift+1];
      bool isOverbought = MomentumBuffer[shift] > Overbought_Level && MomentumBuffer[shift] < MomentumBuffer[shift+1];

      // 2. Volume Condition
      double avgVolume = iMA(Symbol(), Period(), Vol_Lookback, 0, MODE_SMA, PRICE_CLOSE, shift);
      bool isVolumeSpike = (volume[shift] > (avgVolume * Vol_Multiplier));

      // 3. Support / Resistance Condition
      bool isNearSupport = checkSupportResistance(shift, true, low, high, close);
      bool isNearResistance = checkSupportResistance(shift, false, low, high, close);

      // 4. Candlestick Pattern Condition
      bool isBullishPattern = isBullishCandlePattern(shift, open, high, low, close);
      bool isBearishPattern = isBearishCandlePattern(shift, open, high, low, close);

      // 5. ADX Trend Strength Condition
      double adxValue = iADX(NULL, 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, shift);
      bool isTrending = adxValue > ADX_Threshold;

      //--- FINAL CONFLUENCE CHECK ---
      bool buyConditions = htfTrend == 1 &&
                           isOversold &&
                           isVolumeSpike &&
                           isNearSupport &&
                           isBullishPattern &&
                           isTrending;

      bool sellConditions = htfTrend == -1 &&
                            isOverbought &&
                            isVolumeSpike &&
                            isNearResistance &&
                            isBearishPattern &&
                            isTrending;

      //--- Plot Signals & Send Alerts ---
      if(buyConditions)
        {
         double atr = iATR(Symbol(), Period(), 14, shift);
         BuySignalBuffer[shift] = low[shift] - (atr * 0.5);
         sendAlert(shift, "BUY");
        }
      if(sellConditions)
        {
         double atr = iATR(Symbol(), Period(), 14, shift);
         SellSignalBuffer[shift] = high[shift] + (atr * 0.5);
         sendAlert(shift, "SELL");
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Function to get Momentum Value (RSI)                             |
//+------------------------------------------------------------------+
double getMomentumValue(int shift)
  {
   return(iRSI(Symbol(), Period(), Osc_Period, PRICE_CLOSE, shift));
  }

//+------------------------------------------------------------------+
//| Functions to detect Candlestick Patterns                         |
//+------------------------------------------------------------------+
bool isBullishCandlePattern(int shift, const double& o[], const double& h[], const double& l[], const double& c[])
  {
   bool patternFound = false;

   // Check for Bullish Engulfing
   if(Enable_Engulfing)
     {
      bool isEngulfing = c[shift] > o[shift] &&      // Current is bullish
                         c[shift+1] < o[shift+1] &&  // Previous is bearish
                         c[shift] > o[shift+1] &&    // Current close > prev open
                         o[shift] < c[shift+1];      // Current open < prev close
      if(isEngulfing) patternFound = true;
     }

   // Check for Hammer
   if(!patternFound && Enable_Hammer)
     {
      double body = MathAbs(o[shift] - c[shift]);
      double upperWick = h[shift] - MathMax(o[shift], c[shift]);
      double lowerWick = MathMin(o[shift], c[shift]) - l[shift];

      bool isHammer = lowerWick > (body * 2.0) && upperWick < body;
      if(isHammer) patternFound = true;
     }

   return patternFound;
  }

bool isBearishCandlePattern(int shift, const double& o[], const double& h[], const double& l[], const double& c[])
  {
   bool patternFound = false;

   // Check for Bearish Engulfing
   if(Enable_Engulfing)
     {
      bool isEngulfing = c[shift] < o[shift] &&      // Current is bearish
                         c[shift+1] > o[shift+1] &&  // Previous is bullish
                         o[shift] > c[shift+1] &&    // Current open > prev close
                         c[shift] < o[shift+1];      // Current close < prev open
      if(isEngulfing) patternFound = true;
     }

   // Check for Shooting Star
   if(!patternFound && Enable_Hammer) // Note: Enable_Hammer covers both Hammer and Shooting Star
     {
      double body = MathAbs(o[shift] - c[shift]);
      double upperWick = h[shift] - MathMax(o[shift], c[shift]);
      double lowerWick = MathMin(o[shift], c[shift]) - l[shift];

      bool isShootingStar = upperWick > (body * 2.0) && lowerWick < body;
      if(isShootingStar) patternFound = true;
     }

   return patternFound;
  }

//+------------------------------------------------------------------+
//| Function to check if price is at a Support or Resistance level   |
//+------------------------------------------------------------------+
bool checkSupportResistance(int shift, bool checkForSupport, const double& low[], const double& high[], const double& close[])
  {
   double swingPrice = 0;

   // Search for the most recent relevant swing point within the lookback period
   for(int i = shift + 1; i < shift + SR_Lookback; i++)
     {
      // Using ZigZag buffers: 1 for highs, 2 for lows. Standard params: 12,5,3
      double swingHigh = iCustom(NULL, 0, "ZigZag", 12, 5, 3, 1, i);
      double swingLow = iCustom(NULL, 0, "ZigZag", 12, 5, 3, 2, i);

      if(checkForSupport && swingLow > 0)
        {
         swingPrice = swingLow;
         break; // Found nearest support
        }
      if(!checkForSupport && swingHigh > 0)
        {
         swingPrice = swingHigh;
         break; // Found nearest resistance
        }
     }

   if(swingPrice == 0) return false; // No S/R level found

   // Now check if the current bar interacts with the identified S/R zone
   if(checkForSupport)
     {
      double supportZoneTop = swingPrice + (SR_ZoneWidth * _Point);
      // Condition: The bar's low must have pierced the zone, and the close must be above the swing low itself.
      if(low[shift] <= supportZoneTop && close[shift] > swingPrice) return true;
     }
   else // Checking for resistance
     {
      double resistanceZoneBottom = swingPrice - (SR_ZoneWidth * _Point);
      // Condition: The bar's high must have pierced the zone, and the close must be below the swing high itself.
      if(high[shift] >= resistanceZoneBottom && close[shift] < swingPrice) return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Function to get Higher Timeframe Trend (Robust Version)          |
//+------------------------------------------------------------------+
int getHTFTrend(int shift)
  {
   datetime currentBarTime = iTime(Symbol(), Period(), shift);
   int htfShift = iBarShift(Symbol(), PrimaryTrendTF, currentBarTime);

   double fastSma = iMA(Symbol(), PrimaryTrendTF, HTF_FastMA_Period, 0, MODE_SMA, PRICE_CLOSE, htfShift);
   double slowSma = iMA(Symbol(), PrimaryTrendTF, HTF_SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE, htfShift);

   if(fastSma > slowSma) return(1);
   if(fastSma < slowSma) return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Function to Send Alerts                                          |
//+------------------------------------------------------------------+
void sendAlert(int shift, string direction)
  {
   // Use a static variable to track the time of the last alert
   // This ensures we only send one alert per signal on a given bar.
   static datetime lastAlertTime = 0;

   if(EnableAlerts && lastAlertTime != Time[shift])
     {
      lastAlertTime = Time[shift];
      string message = StringFormat("%s Signal on %s at %s", direction, Symbol(), TimeToString(Time[shift], TIME_SECONDS));

      if(EnablePopUpAlerts)
        {
         Alert(message);
        }

      // Future-proofing for push notifications or email
      // SendNotification(message);
      // SendMail("New Signal", message);
     }
  }
//+------------------------------------------------------------------+
