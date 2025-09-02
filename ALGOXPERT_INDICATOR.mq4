//+------------------------------------------------------------------+
//|                                       ALGOXPERT_INDICATOR.mq4 |
//|                      Copyright 2024, MetaQuotes Software Corp. |
//|                                  Converted by Jules from PineScript |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Jules"
#property link      "https://www.mql5.com"
#property version   "1.03"
#property strict

//--- Indicator Properties
#property indicator_chart_window
#property indicator_buffers 9 // Reduced buffers after removing arrow plots
#property indicator_plots   1 // Only one plot: the filter line

//--- Plot 1: Main Filter Line (Color Changing)
#property indicator_label1  "Range Filter"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
#property indicator_color1  clrMediumSeaGreen,clrPaleVioletRed,clrOrange

//--- Input Parameters
input group "Filter Settings"
input bool   useHACandles = false;   // Use HA Candles instead of regular close
input double mult         = 10.0;   // Range Multiplier

input group "Alert Settings"
input bool   EnableAlerts = true;    // Enable Alerts
input bool   EnablePopUps = true;    // Enable Pop-up message alerts

//--- Hardcoded Parameters from PineScript
static const int per = 50;
static const int wper = per * 2 - 1;

//--- Indicator Buffers
double FilterBuffer[];     // 0
double ColorBuffer[];      // 1
//--- Calculation Buffers (not plotted)
double haCloseBuffer[];    // 2
double haOpenBuffer[];     // 3
double smrngBuffer[];      // 4
double upwardBuffer[];     // 5
double downwardBuffer[];   // 6
double condIniBuffer[];    // 7
double avrngBuffer[];      // 8

//--- Color Indices
const int COLOR_UP = 0, COLOR_DOWN = 1, COLOR_NEUTRAL = 2;

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, FilterBuffer);
   SetIndexBuffer(1, ColorBuffer);
   SetIndexBuffer(2, haCloseBuffer);
   SetIndexBuffer(3, haOpenBuffer);
   SetIndexBuffer(4, smrngBuffer);
   SetIndexBuffer(5, upwardBuffer);
   SetIndexBuffer(6, downwardBuffer);
   SetIndexBuffer(7, condIniBuffer);
   SetIndexBuffer(8, avrngBuffer);

   SetIndexLabel(0, "Filter");
   SetIndexLabel(1, NULL); SetIndexLabel(2, NULL); SetIndexLabel(3, NULL);
   SetIndexLabel(4, NULL); SetIndexLabel(5, NULL); SetIndexLabel(6, NULL);
   SetIndexLabel(7, NULL); SetIndexLabel(8, NULL);

   IndicatorSetString(INDICATOR_SHORTNAME, "ALGOXPERT (MQL4)");
   return(INIT_SUCCEEDED);
  }

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
   if(rates_total < wper + 2) return(0);

   int limit = rates_total - prev_calculated;
   if(prev_calculated == 0)
     {
      limit = rates_total - (wper + 3);
      FilterBuffer[rates_total-1] = close[rates_total-1];
      condIniBuffer[rates_total-1] = 0;
     }

   double k1 = 2.0 / (per + 1.0);
   double k2 = 2.0 / (wper + 1.0);

   for(int i = limit; i >= 0; i--)
     {
      haCloseBuffer[i] = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      if(i == rates_total - 1) haOpenBuffer[i] = (open[i] + close[i]) / 2.0;
      else haOpenBuffer[i] = (haOpenBuffer[i+1] + haCloseBuffer[i+1]) / 2.0;

      double actualSrc = useHACandles ? haCloseBuffer[i] : close[i];
      double prevSrc = useHACandles ? haCloseBuffer[i+1] : close[i+1];

      avrngBuffer[i] = MathAbs(actualSrc - prevSrc) * k1 + avrngBuffer[i+1] * (1.0 - k1);
      smrngBuffer[i] = avrngBuffer[i] * k2 + smrngBuffer[i+1] * (1.0 - k2);

      double finalSmrng = smrngBuffer[i] * mult;

      double prevFilt = FilterBuffer[i+1];
      if(actualSrc > prevFilt) FilterBuffer[i] = MathMax(prevFilt, actualSrc - finalSmrng);
      else FilterBuffer[i] = MathMin(prevFilt, actualSrc + finalSmrng);

      if(FilterBuffer[i] > FilterBuffer[i+1]) {
         upwardBuffer[i] = upwardBuffer[i+1] + 1; downwardBuffer[i] = 0;
      } else if(FilterBuffer[i] < FilterBuffer[i+1]) {
         downwardBuffer[i] = downwardBuffer[i+1] + 1; upwardBuffer[i] = 0;
      } else {
         upwardBuffer[i] = upwardBuffer[i+1]; downwardBuffer[i] = downwardBuffer[i+1];
      }

      if(upwardBuffer[i] > 0) ColorBuffer[i] = COLOR_UP;
      else if(downwardBuffer[i] > 0) ColorBuffer[i] = COLOR_DOWN;
      else ColorBuffer[i] = COLOR_NEUTRAL;

      if(upwardBuffer[i] > 0) condIniBuffer[i] = 1;
      else if(downwardBuffer[i] > 0) condIniBuffer[i] = -1;
      else condIniBuffer[i] = condIniBuffer[i+1];

      bool longCondition = condIniBuffer[i] == 1 && condIniBuffer[i+1] == -1;
      bool shortCondition = condIniBuffer[i] == -1 && condIniBuffer[i+1] == 1;

      if(longCondition) {
         createSignalLabel("BuySignal_"+(string)time[i], time[i], low[i], "BUY", clrMediumSeaGreen);
         sendAlert(time[i], "BUY");
      }
      if(shortCondition) {
         createSignalLabel("SellSignal_"+(string)time[i], time[i], high[i], "SELL", clrPaleVioletRed);
         sendAlert(time[i], "SELL");
      }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Helper function to create signal labels                          |
//+------------------------------------------------------------------+
void createSignalLabel(string name, datetime barTime, double price, string text, color clr)
  {
   double y_offset = SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 200; // 20 pips offset
   if(StringContains(name, "Buy"))
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price - y_offset);
      ObjectSetText(name, text, 12, "Arial", clr);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
     }
   else
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price + y_offset);
      ObjectSetText(name, text, 12, "Arial", clr);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
  }

//+------------------------------------------------------------------+
//| Function to Send Alerts                                          |
//+------------------------------------------------------------------+
void sendAlert(datetime barTime, string direction)
  {
   static datetime lastAlertTime = 0;
   if(EnableAlerts && lastAlertTime != barTime)
     {
      lastAlertTime = barTime;
      if(EnablePopUps)
        {
         Alert(Symbol(), " ", Period(), ": New ", direction, " Signal at ", TimeToString(barTime, TIME_SECONDS));
        }
     }
  }
//+------------------------------------------------------------------+
