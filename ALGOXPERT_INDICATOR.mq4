//+------------------------------------------------------------------+
//|                                       ALGOXPERT_INDICATOR.mq4 |
//|                      Copyright 2024, MetaQuotes Software Corp. |
//|                                  Converted by Jules from PineScript |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Jules"
#property link      "https://www.mql5.com"
#property version   "1.05 (Final MQL4 Version)"
#property strict

//--- Indicator Properties
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots   3

//--- Plot 1: Up-Trend Filter Line (Green)
#property indicator_label1  "Up Filter"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumSeaGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Down-Trend Filter Line (Red)
#property indicator_label2  "Down Filter"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrPaleVioletRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Neutral-Trend Filter Line (Orange)
#property indicator_label3  "Neutral Filter"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

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
double UpFilterBuffer[];   // 0
double DownFilterBuffer[]; // 1
double NeutralFilterBuffer[];// 2
double FilterBuffer[];     // 3
double haCloseBuffer[];    // 4
double haOpenBuffer[];     // 5
double smrngBuffer[];      // 6
double upwardBuffer[];     // 7
double downwardBuffer[];   // 8
double condIniBuffer[];    // 9
double avrngBuffer[];      // 10

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, UpFilterBuffer);
   SetIndexBuffer(1, DownFilterBuffer);
   SetIndexBuffer(2, NeutralFilterBuffer);
   SetIndexBuffer(3, FilterBuffer);
   SetIndexBuffer(4, haCloseBuffer);
   SetIndexBuffer(5, haOpenBuffer);
   SetIndexBuffer(6, smrngBuffer);
   SetIndexBuffer(7, upwardBuffer);
   SetIndexBuffer(8, downwardBuffer);
   SetIndexBuffer(9, condIniBuffer);
   SetIndexBuffer(10, avrngBuffer);

   SetIndexEmptyValue(0, EMPTY_VALUE);
   SetIndexEmptyValue(1, EMPTY_VALUE);
   SetIndexEmptyValue(2, EMPTY_VALUE);

   SetIndexLabel(0, "Up Filter");
   SetIndexLabel(1, "Down Filter");
   SetIndexLabel(2, "Neutral Filter");
   SetIndexLabel(3, NULL); SetIndexLabel(4, NULL); SetIndexLabel(5, NULL);
   SetIndexLabel(6, NULL); SetIndexLabel(7, NULL); SetIndexLabel(8, NULL);
   SetIndexLabel(9, NULL); SetIndexLabel(10, NULL);

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

      UpFilterBuffer[i] = EMPTY_VALUE;
      DownFilterBuffer[i] = EMPTY_VALUE;
      NeutralFilterBuffer[i] = EMPTY_VALUE;

      if(upwardBuffer[i] > 0) UpFilterBuffer[i] = FilterBuffer[i];
      else if(downwardBuffer[i] > 0) DownFilterBuffer[i] = FilterBuffer[i];
      else NeutralFilterBuffer[i] = FilterBuffer[i];

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
void createSignalLabel(string name, datetime barTime, double price, string text, color clr)
  {
   // Use MQL4-native _Point to calculate offset
   double y_offset = _Point * 20; // 20 points offset

   // Use MQL4-native StringFind() instead of StringContains()
   if(StringFind(name, "Buy") != -1)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price - y_offset);
      ObjectSetText(name, text, 10, "Arial Bold", clr);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
     }
   else
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, barTime, price + y_offset);
      ObjectSetText(name, text, 10, "Arial Bold", clr);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
  }

//+------------------------------------------------------------------+
void sendAlert(datetime barTime, string direction)
  {
   static datetime lastAlertTime = 0;
   if(EnableAlerts && lastAlertTime != barTime)
     {
      lastAlertTime = barTime;
      if(EnablePopUps)
        {
         Alert(Symbol(), " ", EnumToString(Period()), ": New ", direction, " Signal at ", TimeToString(barTime, TIME_SECONDS));
        }
     }
  }
//+------------------------------------------------------------------+
