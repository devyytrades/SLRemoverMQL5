//+-----------------------+
//| Timed SL Remover EA   |                                            |
//+-----------------------+
#include <Trade/Trade.mqh>
CTrade trade;

input string Start   = "23:50";       // time to remove SLs
input string End     = "01:15";       // time to restore SLs

struct SLRecord
{
   string symbol;
   ulong  ticket;
   double originalSL;
   bool   modified;
};
SLRecord records[100];
int recordCount = 0;

bool restored = false;

//+------------------------------------------------------------------+
//| Helper: parse "HH:MM" into today's datetime                      |
//+------------------------------------------------------------------+
datetime ParseTime(string t)
{
   int h = StringToInteger(StringSubstr(t,0,2));
   int m = StringToInteger(StringSubstr(t,3,2));

   datetime now = TimeCurrent();
   MqlDateTime parts;
   TimeToStruct(now, parts);

   datetime todayMidnight = StructToTime(parts) - (parts.hour*3600 + parts.min*60 + parts.sec);
   return todayMidnight + h*3600 + m*60;
}

//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA initialized. Will remove SLs at ", Start, " and restore at ", End);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime now = TimeCurrent();
   datetime startTime = ParseTime(Start);
   datetime endTime   = ParseTime(End);

   //--- Step 1: Remove SLs at StartTime
   if(now >= startTime && now < endTime && !restored)
   {
      int total = PositionsTotal();
      for(int i=0; i<total; i++)
      {
         string symbol = PositionGetSymbol(i);
         if(PositionSelect(symbol))
         {
            ulong  ticket      = PositionGetInteger(POSITION_TICKET);
            double sl          = PositionGetDouble(POSITION_SL);
            double tp          = PositionGetDouble(POSITION_TP); // preserve TP

            // check if already modified
            bool already = false;
            for(int j=0; j<recordCount; j++)
               if(records[j].ticket == ticket) already = true;
            if(already) continue;

            // Set SL to 0 for both BUY and SELL
            double new_sl = 0;

            if(trade.PositionModify(symbol, new_sl, tp)) // keep TP unchanged
            {
               int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               Print("SL removed for ", symbol, " (set to 0)");
               records[recordCount].symbol     = symbol;
               records[recordCount].ticket     = ticket;
               records[recordCount].originalSL = sl;
               records[recordCount].modified   = true;
               recordCount++;
            }
            else
            {
               Print("Failed to remove SL for ", symbol, " - error: ", _LastError);
            }
         }
      }
   }

   //--- Step 2: Restore SLs at EndTime
   if(now >= endTime && !restored)
   {
      for(int j=0; j<recordCount; j++)
      {
         if(PositionSelectByTicket(records[j].ticket))
         {
            string symbol  = PositionGetString(POSITION_SYMBOL);
            double oldSL   = records[j].originalSL;
            double tp      = PositionGetDouble(POSITION_TP); // preserve TP

            if(trade.PositionModify(symbol, oldSL, tp))
               Print("SL restored for ", symbol, " to ", DoubleToString(oldSL, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            else
               Print("Failed to restore SL for ", symbol, " - error: ", _LastError);
         }
      }
      restored = true;
   }
}

//+------------------------------------------------------------------+


