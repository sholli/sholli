//+------------------------------------------------------------------+
//|                                           LightWb_NonRepaint_BO.mq4 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                     https://www.mql5.com/en/users/jules |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, kingtcno@gmail.com"
#property link      "https://www.mql5.com"
#property version   "1.05 (Fixed by Jules)"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2
//--- plot BuySignal
#property indicator_label1  "BuySignal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot SellSignal
#property indicator_label2  "SellSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Input parameters
input group             "Multi-Timeframe Settings"
input ENUM_TIMEFRAMES   HigherTimeframe = PERIOD_M5;     // Higher TF for Confirmation
input int               HTF_FastMA_Period = 5;           // HTF Fast MA Period
input int               HTF_SlowMA_Period = 20;          // HTF Slow MA Period

input group             "Filter Settings"
input int               ATR_Period = 14;                 // ATR Period for Volatility Filter
input double            ATR_Multiplier = 0.7;            // ATR Multiplier (e.g. 0.7 -> bar range > 70% of ATR)
input int               Volume_SMA_Period = 20;          // Volume SMA Period
input double            Volume_Factor = 1.2;             // Volume Factor (e.g., 1.2 = 20% above avg)
input int               Momentum_Period = 14;            // Momentum Period (e.g., RSI)
input int               Momentum_Smoothing_Period = 5;   // Smoothing for Momentum

input group             "Alert Settings"
input bool              EnableAlerts = true;             // Enable Alerts
input bool              EnablePopUpAlerts = true;        // Enable Pop-up Alerts

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

//--- Set arrow codes for buffers (using Wingdings font)
   SetIndexArrow(0, 233); // Up Arrow
   SetIndexArrow(1, 234); // Down Arrow

//--- Set empty value for buffers
   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, 0.0);
   SetIndexEmptyValue(3, 0.0);

//--- Set labels
   IndicatorSetString(INDICATOR_SHORTNAME, "LightWb BO Fixed (HTF: " + EnumToString(HigherTimeframe) + ")");

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
   int barsRequired = MathMax(Volume_SMA_Period, MathMax(ATR_Period, Momentum_Period + Momentum_Smoothing_Period)) + 2;
   if(rates_total < barsRequired)
      return(0);

//--- Correctly determine the starting bar for the calculation loop
   int limit;
   if(prev_calculated == 0)
      limit = rates_total - barsRequired;
   else
      limit = rates_total - prev_calculated;

//--- Main calculation loop (Corrected to be a countdown loop)
   for(int i = limit; i >= 0; i--)
     {
      // We process bar 'i+1' to ensure it's a closed bar and avoid repainting
      int shift = i + 1;

      //--- Reset signals for the current bar
      BuySignalBuffer[shift] = EMPTY_VALUE;
      SellSignalBuffer[shift] = EMPTY_VALUE;

      //--- Calculate Indicator Values ---
      double avgVolume = iMA(Symbol(), Period(), Volume_SMA_Period, 0, MODE_SMA, PRICE_CLOSE, shift);
      double atrValue = iATR(Symbol(), Period(), ATR_Period, shift);
      MomentumBuffer[shift] = getSmoothedMomentum(shift);
      TrendBuffer[shift] = getHTFTrend(shift); // Store trend in buffer
      int htfTrend = (int)TrendBuffer[shift];

      //--- Define Filter Conditions ---
      bool isVolatile = (high[shift] - low[shift]) > (atrValue * ATR_Multiplier);
      bool isVolumeSpike = (volume[shift] > (avgVolume * Volume_Factor));
      bool isMomemtumBuy = MomentumBuffer[shift] > 50 && MomentumBuffer[shift+1] <= 50; // Crossover 50 line
      bool isMomemtumSell = MomentumBuffer[shift] < 50 && MomentumBuffer[shift+1] >= 50; // Crossunder 50 line

      //--- CONFLUENCE CHECK ---
      bool buyConditions = htfTrend == 1 && isVolatile && isVolumeSpike && isMomemtumBuy;
      bool sellConditions = htfTrend == -1 && isVolatile && isVolumeSpike && isMomemtumSell;

      //--- Plot Signals & Send Alerts ---
      if(buyConditions)
        {
         BuySignalBuffer[shift] = low[shift] - (atrValue * 0.5);
         sendAlert(shift, "BUY");
        }
      if(sellConditions)
        {
         SellSignalBuffer[shift] = high[shift] + (atrValue * 0.5);
         sendAlert(shift, "SELL");
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Function to get Smoothed Momentum                                |
//+------------------------------------------------------------------+
double getSmoothedMomentum(int shift)
  {
   double rsiArray[];
   int rsiDataSize = Momentum_Smoothing_Period + 5;
   ArrayResize(rsiArray, rsiDataSize);

   for(int i = 0; i < rsiDataSize; i++)
     {
      rsiArray[i] = iRSI(Symbol(), Period(), Momentum_Period, PRICE_CLOSE, shift + i);
     }

   return(iMAOnArray(rsiArray, 0, Momentum_Smoothing_Period, 0, MODE_SMA, 0));
  }

//+------------------------------------------------------------------+
//| Function to get Higher Timeframe Trend (Robust Version)          |
//+------------------------------------------------------------------+
int getHTFTrend(int shift)
  {
   datetime currentBarTime = iTime(Symbol(), Period(), shift);
   int htfShift = iBarShift(Symbol(), HigherTimeframe, currentBarTime);

   double fastSma = iMA(Symbol(), HigherTimeframe, HTF_FastMA_Period, 0, MODE_SMA, PRICE_CLOSE, htfShift);
   double slowSma = iMA(Symbol(), HigherTimeframe, HTF_SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE, htfShift);

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
