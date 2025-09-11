//+------------------------------------------------------------------+
//| Timed SL Remover EA - persistent, CSV logging  |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string Start         = "23:50";
input string End           = "01:15";
input string SaveFileName  = "SLRemoverEALogs.csv";   // MQL5\Files\SLRemoverEALogs.csv

struct SLRecord
{
   int       entryId;       // #ENTRY shown in CSV
   ulong     ticket;
   string    symbol;
   double    originalSL;

   bool      removed;
   datetime  removedTime;
   bool      restored;
   datetime  restoredTime;

   int       rowIndex;      // 1-based row index (excluding header) for updating
};

SLRecord records[];
bool restoredForThisWindow = false;
int  entryCounter = 0;   // local counter for in-session records

//------------------------------------------------------------------
// Helpers
//------------------------------------------------------------------
int TimeOfDaySeconds(string t)
{
   return (int)StringToInteger(StringSubstr(t,0,2)) * 3600
        + (int)StringToInteger(StringSubstr(t,3,2)) * 60;
}

int NowOfDaySeconds()
{
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   return dt.hour*3600 + dt.min*60 + dt.sec;
}

bool InWindow(int startSec, int endSec)
{
   int nowSec = NowOfDaySeconds();
   if(startSec <= endSec) return nowSec >= startSec && nowSec < endSec;
   return (nowSec >= startSec || nowSec < endSec);
}

string DtStr(datetime t)
{
   return (t>0) ? TimeToString(t, TIME_MINUTES) + " (BROKER)" : "";
}

//------------------------------------------------------------------
// CSV helpers
//------------------------------------------------------------------

// Count existing data rows (excludes the header line)
int CountExistingRows()
{
   if(!FileIsExist(SaveFileName)) return 0;

   int h = FileOpen(SaveFileName, FILE_READ|FILE_CSV|FILE_ANSI, ';');
   if(h==INVALID_HANDLE) return 0;

   // Detect/skip header if present
   int rows = 0;
   if(!FileIsEnding(h))
   {
      string first = FileReadString(h);
      if(first == "#ENTRY")
      {
         for(int k=0; k<5 && !FileIsEnding(h); k++) FileReadString(h);
      }
      else
      {
         FileSeek(h, 0, SEEK_SET);
      }
   }

   while(!FileIsEnding(h))
   {
      // Read first field of a row
      string c0 = FileReadString(h);
      if(FileIsEnding(h)) break;
      // Read remaining 5 fields of the row
      for(int k=0; k<5 && !FileIsEnding(h); k++) FileReadString(h);
      rows++;
   }

   FileClose(h);
   return rows;
}

// Read the whole CSV into memory as lines of "f1;f2;...;f6"
void ReadWholeCsv(string &content[], int &lines)
{
   ArrayResize(content, 0);
   lines = 0;

   if(!FileIsExist(SaveFileName))
      return;

   int h = FileOpen(SaveFileName, FILE_READ|FILE_CSV|FILE_ANSI, ';');
   if(h==INVALID_HANDLE)
      return;

   while(!FileIsEnding(h))
   {
      string row = "";
      // Try to read up to 6 fields for a row. If file has header, it’s also 6 fields.
      for(int k=0; k<6 && !FileIsEnding(h); k++)
      {
         if(k>0) row += ";";
         row += FileReadString(h);
      }
      if(row != "")
      {
         ArrayResize(content, lines+1);
         content[lines] = row;
         lines++;
      }
   }

   FileClose(h);
}

// Write out all lines (already semicolon-joined) to CSV
void WriteWholeCsv(string &content[], int lines)
{
   int h = FileOpen(SaveFileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
   if(h==INVALID_HANDLE)
   {
      Print("File open failed for write, Err=", GetLastError());
      return;
   }

   for(int i=0; i<lines; i++)
   {
      string fields[];
      int cnt = StringSplit(content[i], ';', fields);
      if(cnt>0)
      {
         FileWrite(h,
                   fields[0],
                   (cnt>1?fields[1]:""),
                   (cnt>2?fields[2]:""),
                   (cnt>3?fields[3]:""),
                   (cnt>4?fields[4]:""),
                   (cnt>5?fields[5]:""));
      }
   }
   FileClose(h);
}

// Append a new row for the removal event, safely (no read+write open)
// Sets r.entryId and r.rowIndex so we can update later
int AppendLogRow(SLRecord &r)
{
   string content[];
   int lines = 0;
   ReadWholeCsv(content, lines);

   // If file empty, add header as first line
   if(lines == 0)
   {
      ArrayResize(content, 1);
      content[0] = "#ENTRY;PAIR;SL Removed;SL Removed Time;SL Restored;SL Restored Time";
      lines = 1;
   }

   int entryNo = CountExistingRows() + 1; // visible #ENTRY and row index

   // Build new row with restored likely NO at removal time
   string newRow = StringFormat("#%d;%s;%s;%s;%s;%s",
                                entryNo,
                                r.symbol,
                                (r.removed ? "YES" : "NO"),
                                DtStr(r.removedTime),
                                (r.restored ? "YES" : "NO"),
                                DtStr(r.restoredTime));

   ArrayResize(content, lines+1);
   content[lines] = newRow;  // append as last line
   lines++;

   WriteWholeCsv(content, lines);

   r.entryId  = entryNo;
   r.rowIndex = entryNo;     // first data row is index 1 (content[0] is header)
   return r.rowIndex;
}

// Update an existing row (flip restored to YES & time)
// NOTE: rowIndex is 1-based for data rows; content[0] is the header.
void UpdateLogRow(const SLRecord &r)
{
   if(r.rowIndex <= 0) return; // nothing to update yet

   string content[];
   int lines = 0;
   ReadWholeCsv(content, lines);
   if(lines == 0) return; // nothing exists

   // Safety check: ensure the row we need exists
   if(r.rowIndex >= lines) return; // no such data row

   // Rewrite the specific row
   content[r.rowIndex] = StringFormat("#%d;%s;%s;%s;%s;%s",
                                      r.entryId,
                                      r.symbol,
                                      (r.removed  ? "YES" : "NO"),
                                      DtStr(r.removedTime),
                                      (r.restored ? "YES" : "NO"),
                                      DtStr(r.restoredTime));

   WriteWholeCsv(content, lines);
}

//------------------------------------------------------------------
// Records
//------------------------------------------------------------------
int FindRecordIndexByTicket(ulong ticket)
{
   for(int i=0;i<ArraySize(records);i++)
      if(records[i].ticket==ticket) return i;
   return -1;
}

int EnsureRecord(ulong ticket,string sym,double originalSL)
{
   int idx=FindRecordIndexByTicket(ticket);
   if(idx>=0) return idx;

   SLRecord r;
   r.entryId=0;                 // set when appending row
   r.ticket=ticket;
   r.symbol=sym;
   r.originalSL=originalSL;
   r.removed=false;
   r.removedTime=0;
   r.restored=false;
   r.restoredTime=0;
   r.rowIndex=-1;

   int n=ArraySize(records); ArrayResize(records,n+1); records[n]=r;
   return n;
}

//------------------------------------------------------------------
// Actions
//------------------------------------------------------------------
void EnsureSLRemovedForPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   if(sl==0.0) return;

   int idx=EnsureRecord(ticket,sym,sl);
   if(!records[idx].removed && trade.PositionModify(sym,0.0,tp))
   {
      PrintFormat("Removed SL for %s ticket=%I64u", sym, ticket);
      records[idx].removed=true;
      records[idx].removedTime=TimeCurrent();

      // Append a new CSV row and capture rowIndex + entryId for later update
      records[idx].rowIndex=AppendLogRow(records[idx]);
   }
}

void RestoreSavedSLs()
{
   for(int i=0;i<ArraySize(records);i++)
   {
      if(records[i].restored) continue;

      bool restoredOk=false;
      ulong t=records[i].ticket;

      if(PositionSelectByTicket(t))
      {
         string sym=PositionGetString(POSITION_SYMBOL);
         double tp=PositionGetDouble(POSITION_TP);
         if(records[i].originalSL!=0.0)
            restoredOk = trade.PositionModify(sym, records[i].originalSL, tp);
      }

      if(restoredOk)
      {
         PrintFormat("Restored SL for %s ticket=%I64u", records[i].symbol, records[i].ticket);
         records[i].restored     = true;
         records[i].restoredTime = TimeCurrent();
      }
      // If restore fails, leave restored=false & time empty

      // Update the same row to reflect the restored status (YES/NO)
      UpdateLogRow(records[i]);
   }
}

//------------------------------------------------------------------
// EA lifecycle
//------------------------------------------------------------------
int OnInit()
{
   Print("EA init. Start=",Start," End=",End);
   restoredForThisWindow=false;
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){ EventKillTimer(); }

//------------------------------------------------------------------
// Main loop (unchanged)
//------------------------------------------------------------------
void OnTimer()
{
   const int s=TimeOfDaySeconds(Start), e=TimeOfDaySeconds(End), n=NowOfDaySeconds();
   bool inside=(s<=e)?(n>=s&&n<e):(n>=s||n<e);

   if(inside)
   {
      restoredForThisWindow=false;
      int total=PositionsTotal();
      for(int i=0;i<total;i++)
      {
         ulong t=PositionGetTicket(i);
         if(t==0) continue;
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetDouble(POSITION_SL)!=0.0)
            EnsureSLRemovedForPosition(t);
      }
   }
   else if(!restoredForThisWindow)
   {
      RestoreSavedSLs();
      restoredForThisWindow=true;
   }
}