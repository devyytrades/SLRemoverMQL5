//+------------------------------------------------------------------+
//| Timed SL Remover EA                                              |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

//--- Input parameters (numeric spinners with descriptions)
input int StartHour   = 23;  // Hour to remove SLs (0-23)
input int StartMinute = 50;  // Minute to remove SLs (0-59)
input int EndHour     = 1;   // Hour to restore SLs (0-23)
input int EndMinute   = 15;  // Minute to restore SLs (0-59)

//--- Record structure to store original SLs
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
//| Helper: parse hour/minute into today's datetime                 |
//+------------------------------------------------------------------+
datetime ParseTime(int hour, int minute)
{
   datetime now = TimeCurrent();
   MqlDateTime parts;
   TimeToStruct(now, parts);

   // Today's midnight
   datetime todayMidnight = StructToTime(parts) - (parts.hour*3600 + parts.min*60 + parts.sec);
   return todayMidnight + hour*3600 + minute*60;
}

//+------------------------------------------------------------------+
int OnInit()
{
   PrintFormat("EA initialized. Will remove SLs at %02d:%02d and restore at %02d:%02d",
               StartHour, StartMinute, EndHour, EndMinute);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime now = TimeCurrent();

   datetime startTime = ParseTime(StartHour, StartMinute);
   datetime endTime   = ParseTime(EndHour, EndMinute);

   // Handle times crossing midnight
   if(endTime <= startTime) endTime += 24*3600;

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

            // Check if already modified
            bool already = false;
            for(int j=0; j<recordCount; j++)
               if(records[j].ticket == ticket) already = true;
            if(already) continue;

            // Remove SL for both BUY and SELL
            double new_sl = 0;

            if(trade.PositionModify(symbol, new_sl, tp)) // keep TP unchanged
            {
               PrintFormat("SL removed for %s (set to 0)", symbol);
               records[recordCount].symbol     = symbol;
               records[recordCount].ticket     = ticket;
               records[recordCount].originalSL = sl;
               records[recordCount].modified   = true;
               recordCount++;
            }
            else
            {
               PrintFormat("Failed to remove SL for %s - error: %d", symbol, _LastError);
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
               PrintFormat("SL restored for %s to %.5f", symbol, oldSL);
            else
               PrintFormat("Failed to restore SL for %s - error: %d", symbol, _LastError);
         }
      }
      restored = true;
   }
}

//+------------------------------------------------------------------+
