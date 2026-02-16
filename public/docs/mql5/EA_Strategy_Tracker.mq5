//+------------------------------------------------------------------+
//|                                        EA_Strategy_Tracker.mq5   |
//|                              MoneyX Trading - Strategy Lab        |
//|                              Track & Reverse-Engineer EA Orders   |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "1.00"
#property description "Track orders from other EAs and send data to backend for strategy analysis"

#include <Trade\Trade.mqh>

//=== Tracker Settings ===
input group "=== Tracker Settings ==="
input string   InpSessionName     = "EA Test #1";    // Session Name
input int      InpTrackMagicNumber = 0;               // Magic Number to Track (0=All)
input string   InpServerURL       = "https://lkbhomsulgycxawwlnfh.supabase.co/functions/v1/sync-tracked-orders";
input int      InpSendInterval    = 30;               // Send Interval (seconds)
input int      InpOwnMagicNumber  = 999999;           // This Tracker's Magic (exclude self)

//=== History Settings ===
input group "=== History Settings ==="
input bool     InpSendHistory      = true;    // Send Trade History on Start
input int      InpHistoryDays      = 30;      // History Days to Pull
input int      InpHistoryBatchSize = 50;      // Batch Size per Request

//=== Market Data Collection ===
input group "=== Market Data Collection ==="
input bool     InpCollectRSI       = true;   // Collect RSI(14)
input bool     InpCollectEMA       = true;   // Collect EMA(20,50)
input bool     InpCollectATR       = true;   // Collect ATR(14)
input bool     InpCollectMACD      = true;   // Collect MACD(12,26,9)
input bool     InpCollectBollinger = true;   // Collect Bollinger(20,2)

//=== Broker Info ===
input group "=== Broker Info ==="
input string   InpBroker          = "";      // Broker Name (auto if empty)

//--- Structs
struct TrackedPosition
{
   ulong    ticket;
   string   symbol;
   int      type;
   double   volume;
   double   openPrice;
   double   sl;
   double   tp;
   datetime openTime;
   bool     reported;       // already sent open event
   double   lastSL;         // track SL modifications
   double   lastTP;         // track TP modifications
};

//--- Globals
TrackedPosition g_positions[];
int             g_posCount = 0;
datetime        g_lastSendTime = 0;
string          g_brokerName = "";
string          g_accountNumber = "";

//+------------------------------------------------------------------+
int OnInit()
{
   g_brokerName = (InpBroker != "") ? InpBroker : AccountInfoString(ACCOUNT_COMPANY);
   g_accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   
   Print("[Tracker] Started - Session: ", InpSessionName, 
         " | Magic Filter: ", InpTrackMagicNumber == 0 ? "ALL" : IntegerToString(InpTrackMagicNumber),
         " | Broker: ", g_brokerName, " | Account: ", g_accountNumber);
   
   // Initial scan
   ScanPositions();
   
   // Send trade history on startup
   if(InpSendHistory)
   {
      Print("[Tracker] Pulling trade history (", InpHistoryDays, " days)...");
      SendTradeHistory();
   }
   
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("[Tracker] Stopped - Reason: ", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
   CheckForChanges();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(TimeCurrent() - g_lastSendTime >= InpSendInterval)
   {
      SendPendingData();
   }
}

//+------------------------------------------------------------------+
bool ShouldTrack(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   long magic = PositionGetInteger(POSITION_MAGIC);
   
   // Never track our own orders
   if(magic == InpOwnMagicNumber) return false;
   
   // Track all (except self) or specific magic
   if(InpTrackMagicNumber == 0) return true;
   return (magic == InpTrackMagicNumber);
}

//+------------------------------------------------------------------+
void ScanPositions()
{
   ArrayResize(g_positions, 0);
   g_posCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!ShouldTrack(ticket)) continue;
      
      TrackedPosition pos;
      pos.ticket    = ticket;
      pos.symbol    = PositionGetString(POSITION_SYMBOL);
      pos.type      = (int)PositionGetInteger(POSITION_TYPE);
      pos.volume    = PositionGetDouble(POSITION_VOLUME);
      pos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      pos.sl        = PositionGetDouble(POSITION_SL);
      pos.tp        = PositionGetDouble(POSITION_TP);
      pos.openTime  = (datetime)PositionGetInteger(POSITION_TIME);
      pos.reported  = false;
      pos.lastSL    = pos.sl;
      pos.lastTP    = pos.tp;
      
      g_posCount++;
      ArrayResize(g_positions, g_posCount);
      g_positions[g_posCount - 1] = pos;
   }
}

//+------------------------------------------------------------------+
void CheckForChanges()
{
   // Check for new positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!ShouldTrack(ticket)) continue;
      
      int idx = FindTrackedPosition(ticket);
      if(idx < 0)
      {
         // New position detected
         TrackedPosition pos;
         pos.ticket    = ticket;
         pos.symbol    = PositionGetString(POSITION_SYMBOL);
         pos.type      = (int)PositionGetInteger(POSITION_TYPE);
         pos.volume    = PositionGetDouble(POSITION_VOLUME);
         pos.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         pos.sl        = PositionGetDouble(POSITION_SL);
         pos.tp        = PositionGetDouble(POSITION_TP);
         pos.openTime  = (datetime)PositionGetInteger(POSITION_TIME);
         pos.reported  = false;
         pos.lastSL    = pos.sl;
         pos.lastTP    = pos.tp;
         
         g_posCount++;
         ArrayResize(g_positions, g_posCount);
         g_positions[g_posCount - 1] = pos;
         
         // Send open event immediately
         SendOrderEvent(pos, "open");
         g_positions[g_posCount - 1].reported = true;
         
         PrintFormat("[Tracker] NEW %s %s %.2f @ %.5f SL:%.5f TP:%.5f",
            pos.symbol, pos.type == 0 ? "BUY" : "SELL", pos.volume,
            pos.openPrice, pos.sl, pos.tp);
      }
      else
      {
         // Check for modifications
         if(PositionSelectByTicket(ticket))
         {
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            if(MathAbs(currentSL - g_positions[idx].lastSL) > _Point ||
               MathAbs(currentTP - g_positions[idx].lastTP) > _Point)
            {
               g_positions[idx].sl = currentSL;
               g_positions[idx].tp = currentTP;
               g_positions[idx].lastSL = currentSL;
               g_positions[idx].lastTP = currentTP;
               
               SendOrderEvent(g_positions[idx], "modify");
               
               PrintFormat("[Tracker] MODIFY %s #%d SL:%.5f->%.5f TP:%.5f->%.5f",
                  g_positions[idx].symbol, ticket,
                  g_positions[idx].lastSL, currentSL,
                  g_positions[idx].lastTP, currentTP);
            }
         }
      }
   }
   
   // Check for closed positions
   for(int i = g_posCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_positions[i].ticket))
      {
         // Position closed - get close details from history
         TrackedPosition closedPos = g_positions[i];
         
         // Try to get close details from deal history
         double closePrice = 0;
         double profit = 0;
         datetime closeTime = TimeCurrent();
         double swap = 0;
         double commission = 0;
         string comment = "";
         
         if(HistorySelectByPosition(closedPos.ticket))
         {
            int totalDeals = HistoryDealsTotal();
            for(int d = totalDeals - 1; d >= 0; d--)
            {
               ulong dealTicket = HistoryDealGetTicket(d);
               if(dealTicket == 0) continue;
               if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT ||
                  HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_INOUT)
               {
                  closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                  profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                  commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                  closeTime  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  comment    = HistoryDealGetString(dealTicket, DEAL_COMMENT);
                  break;
               }
            }
         }
         
         // Update and send close event
         closedPos.openPrice = closedPos.openPrice; // keep original
         
         PrintFormat("[Tracker] CLOSE %s #%d Profit:%.2f Hold:%ds",
            closedPos.symbol, closedPos.ticket, profit,
            (int)(closeTime - closedPos.openTime));
         
         SendCloseEvent(closedPos, closePrice, profit, swap, commission, closeTime, comment);
         
         // Remove from tracked array
         for(int j = i; j < g_posCount - 1; j++)
            g_positions[j] = g_positions[j + 1];
         g_posCount--;
         ArrayResize(g_positions, g_posCount);
      }
   }
   
   // Update dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+
int FindTrackedPosition(ulong ticket)
{
   for(int i = 0; i < g_posCount; i++)
      if(g_positions[i].ticket == ticket) return i;
   return -1;
}

//+------------------------------------------------------------------+
string GetMarketDataJSON(string symbol)
{
   string json = "{";
   
   // Spread
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   json += "\"spread\":" + DoubleToString(spread, 5);
   
   // RSI
   if(InpCollectRSI)
   {
      int handle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
      if(handle != INVALID_HANDLE)
      {
         double val[1];
         if(CopyBuffer(handle, 0, 0, 1, val) > 0)
            json += ",\"rsi\":" + DoubleToString(val[0], 2);
         IndicatorRelease(handle);
      }
   }
   
   // ATR
   if(InpCollectATR)
   {
      int handle = iATR(symbol, PERIOD_CURRENT, 14);
      if(handle != INVALID_HANDLE)
      {
         double val[1];
         if(CopyBuffer(handle, 0, 0, 1, val) > 0)
            json += ",\"atr\":" + DoubleToString(val[0], 5);
         IndicatorRelease(handle);
      }
   }
   
   // EMA 20 & 50
   if(InpCollectEMA)
   {
      int h20 = iMA(symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
      int h50 = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(h20 != INVALID_HANDLE)
      {
         double val[1];
         if(CopyBuffer(h20, 0, 0, 1, val) > 0)
            json += ",\"ema20\":" + DoubleToString(val[0], 5);
         IndicatorRelease(h20);
      }
      if(h50 != INVALID_HANDLE)
      {
         double val[1];
         if(CopyBuffer(h50, 0, 0, 1, val) > 0)
            json += ",\"ema50\":" + DoubleToString(val[0], 5);
         IndicatorRelease(h50);
      }
   }
   
   // MACD
   if(InpCollectMACD)
   {
      int handle = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
      if(handle != INVALID_HANDLE)
      {
         double main[1], signal[1];
         if(CopyBuffer(handle, 0, 0, 1, main) > 0)
            json += ",\"macd_main\":" + DoubleToString(main[0], 6);
         if(CopyBuffer(handle, 1, 0, 1, signal) > 0)
            json += ",\"macd_signal\":" + DoubleToString(signal[0], 6);
         IndicatorRelease(handle);
      }
   }
   
   // Bollinger Bands
   if(InpCollectBollinger)
   {
      int handle = iBands(symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
      if(handle != INVALID_HANDLE)
      {
         double mid[1], upper[1], lower[1];
         if(CopyBuffer(handle, 0, 0, 1, mid) > 0)
            json += ",\"bb_middle\":" + DoubleToString(mid[0], 5);
         if(CopyBuffer(handle, 1, 0, 1, upper) > 0)
            json += ",\"bb_upper\":" + DoubleToString(upper[0], 5);
         if(CopyBuffer(handle, 2, 0, 1, lower) > 0)
            json += ",\"bb_lower\":" + DoubleToString(lower[0], 5);
         IndicatorRelease(handle);
      }
   }
   
   json += "}";
   return json;
}

//+------------------------------------------------------------------+
string OrderTypeToString(int type)
{
   switch(type)
   {
      case POSITION_TYPE_BUY:  return "buy";
      case POSITION_TYPE_SELL: return "sell";
      default: return "unknown";
   }
}

//+------------------------------------------------------------------+
string DateTimeToISO(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
      mdt.year, mdt.mon, mdt.day, mdt.hour, mdt.min, mdt.sec);
}

//+------------------------------------------------------------------+
void SendOrderEvent(TrackedPosition &pos, string eventType)
{
   if(InpServerURL == "") return;
   
   string marketData = GetMarketDataJSON(pos.symbol);
   long magic = 0;
   if(PositionSelectByTicket(pos.ticket))
      magic = PositionGetInteger(POSITION_MAGIC);
   
   string json = "{";
   json += "\"session_name\":\"" + InpSessionName + "\",";
   json += "\"account_number\":\"" + g_accountNumber + "\",";
   json += "\"broker\":\"" + g_brokerName + "\",";
   json += "\"magic_number\":" + IntegerToString(magic) + ",";
   json += "\"orders\":[{";
   json += "\"ticket\":" + IntegerToString(pos.ticket) + ",";
   json += "\"magic_number\":" + IntegerToString(magic) + ",";
   json += "\"symbol\":\"" + pos.symbol + "\",";
   json += "\"order_type\":\"" + OrderTypeToString(pos.type) + "\",";
   json += "\"volume\":" + DoubleToString(pos.volume, 2) + ",";
   json += "\"open_price\":" + DoubleToString(pos.openPrice, 5) + ",";
   json += "\"sl\":" + DoubleToString(pos.sl, 5) + ",";
   json += "\"tp\":" + DoubleToString(pos.tp, 5) + ",";
   json += "\"open_time\":\"" + DateTimeToISO(pos.openTime) + "\",";
   json += "\"event_type\":\"" + eventType + "\",";
   json += "\"market_data\":" + marketData;
   json += "}]}";
   
   SendHTTP(json);
}

//+------------------------------------------------------------------+
void SendCloseEvent(TrackedPosition &pos, double closePrice, double profit,
                    double swap, double commission, datetime closeTime, string comment)
{
   if(InpServerURL == "") return;
   
   string marketData = GetMarketDataJSON(pos.symbol);
   int holdSeconds = (int)(closeTime - pos.openTime);
   
   string json = "{";
   json += "\"session_name\":\"" + InpSessionName + "\",";
   json += "\"account_number\":\"" + g_accountNumber + "\",";
   json += "\"broker\":\"" + g_brokerName + "\",";
   json += "\"magic_number\":" + IntegerToString(InpTrackMagicNumber) + ",";
   json += "\"orders\":[{";
   json += "\"ticket\":" + IntegerToString(pos.ticket) + ",";
   json += "\"magic_number\":" + IntegerToString(InpTrackMagicNumber) + ",";
   json += "\"symbol\":\"" + pos.symbol + "\",";
   json += "\"order_type\":\"" + OrderTypeToString(pos.type) + "\",";
   json += "\"volume\":" + DoubleToString(pos.volume, 2) + ",";
   json += "\"open_price\":" + DoubleToString(pos.openPrice, 5) + ",";
   json += "\"close_price\":" + DoubleToString(closePrice, 5) + ",";
   json += "\"sl\":" + DoubleToString(pos.sl, 5) + ",";
   json += "\"tp\":" + DoubleToString(pos.tp, 5) + ",";
   json += "\"profit\":" + DoubleToString(profit, 2) + ",";
   json += "\"swap\":" + DoubleToString(swap, 2) + ",";
   json += "\"commission\":" + DoubleToString(commission, 2) + ",";
   json += "\"open_time\":\"" + DateTimeToISO(pos.openTime) + "\",";
   json += "\"close_time\":\"" + DateTimeToISO(closeTime) + "\",";
   json += "\"holding_time_seconds\":" + IntegerToString(holdSeconds) + ",";
   json += "\"comment\":\"" + comment + "\",";
   json += "\"event_type\":\"close\",";
   json += "\"market_data\":" + marketData;
   json += "}]}";
   
   SendHTTP(json);
}

//+------------------------------------------------------------------+
void SendHTTP(string json)
{
   char data[];
   char result[];
   string resultHeaders;
   
   StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   // Remove null terminator
   ArrayResize(data, ArraySize(data) - 1);
   
   string headers = "Content-Type: application/json\r\n";
   
   int timeout = 5000;
   int res = WebRequest("POST", InpServerURL, headers, timeout, data, result, resultHeaders);
   
   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4014)
         Print("[Tracker] ERROR: Add URL to MT5 Tools->Options->Expert Advisors: ", InpServerURL);
      else
         PrintFormat("[Tracker] HTTP Error: %d (code: %d)", err, res);
   }
   else if(res != 200)
   {
      string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      PrintFormat("[Tracker] HTTP %d: %s", res, response);
   }
   else
   {
      g_lastSendTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void SendPendingData()
{
   // Send any unreported open positions
   for(int i = 0; i < g_posCount; i++)
   {
      if(!g_positions[i].reported)
      {
         SendOrderEvent(g_positions[i], "open");
         g_positions[i].reported = true;
      }
   }
}

//+------------------------------------------------------------------+
void SendTradeHistory()
{
   if(InpServerURL == "") return;
   
   datetime startDate = TimeCurrent() - InpHistoryDays * 86400;
   datetime endDate = TimeCurrent();
   
   if(!HistorySelect(startDate, endDate))
   {
      Print("[Tracker] Failed to load deal history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals == 0)
   {
      Print("[Tracker] No history deals found");
      return;
   }
   
   // First pass: collect all DEAL_ENTRY_IN open prices by position ID
   // so we can match them with close deals
   struct DealEntry
   {
      ulong    positionId;
      double   openPrice;
      datetime openTime;
   };
   DealEntry openDeals[];
   int openCount = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN) continue;
      
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(magic == InpOwnMagicNumber) continue;
      if(InpTrackMagicNumber != 0 && magic != InpTrackMagicNumber) continue;
      
      openCount++;
      ArrayResize(openDeals, openCount);
      openDeals[openCount - 1].positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      openDeals[openCount - 1].openPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      openDeals[openCount - 1].openTime   = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   }
   
   // Second pass: collect close deals and match with open deals
   string batchJSON = "";
   int batchCount = 0;
   int totalSent = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(magic == InpOwnMagicNumber) continue;
      if(InpTrackMagicNumber != 0 && magic != InpTrackMagicNumber) continue;
      
      // Get deal details
      string symbol    = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      long   dealType  = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      double volume    = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      double profit    = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double swap      = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      string comment   = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      ulong  posId     = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      
      // Find matching open deal
      double openPrice = 0;
      datetime openTime = 0;
      for(int j = 0; j < openCount; j++)
      {
         if(openDeals[j].positionId == posId)
         {
            openPrice = openDeals[j].openPrice;
            openTime  = openDeals[j].openTime;
            break;
         }
      }
      
      int holdSeconds = (openTime > 0) ? (int)(closeTime - openTime) : 0;
      // Original order type: if close deal is SELL, original was BUY and vice versa
      string orderType = (dealType == DEAL_TYPE_SELL) ? "buy" : "sell";
      
      // Build order JSON
      if(batchCount > 0) batchJSON += ",";
      batchJSON += "{";
      batchJSON += "\"ticket\":" + IntegerToString(posId) + ",";
      batchJSON += "\"magic_number\":" + IntegerToString(magic) + ",";
      batchJSON += "\"symbol\":\"" + symbol + "\",";
      batchJSON += "\"order_type\":\"" + orderType + "\",";
      batchJSON += "\"volume\":" + DoubleToString(volume, 2) + ",";
      batchJSON += "\"open_price\":" + DoubleToString(openPrice, 5) + ",";
      batchJSON += "\"close_price\":" + DoubleToString(closePrice, 5) + ",";
      batchJSON += "\"sl\":0,\"tp\":0,";
      batchJSON += "\"profit\":" + DoubleToString(profit, 2) + ",";
      batchJSON += "\"swap\":" + DoubleToString(swap, 2) + ",";
      batchJSON += "\"commission\":" + DoubleToString(commission, 2) + ",";
      batchJSON += "\"open_time\":\"" + (openTime > 0 ? DateTimeToISO(openTime) : "") + "\",";
      batchJSON += "\"close_time\":\"" + DateTimeToISO(closeTime) + "\",";
      batchJSON += "\"holding_time_seconds\":" + IntegerToString(holdSeconds) + ",";
      batchJSON += "\"comment\":\"" + comment + "\",";
      batchJSON += "\"event_type\":\"history\",";
      batchJSON += "\"market_data\":{}";
      batchJSON += "}";
      batchCount++;
      
      // Send batch when full
      if(batchCount >= InpHistoryBatchSize)
      {
         SendHistoryBatch(batchJSON, batchCount);
         totalSent += batchCount;
         batchJSON = "";
         batchCount = 0;
         Sleep(500); // Avoid overwhelming server
      }
   }
   
   // Send remaining
   if(batchCount > 0)
   {
      SendHistoryBatch(batchJSON, batchCount);
      totalSent += batchCount;
   }
   
   PrintFormat("[Tracker] History sent: %d closed trades from %d days", totalSent, InpHistoryDays);
}

//+------------------------------------------------------------------+
void SendHistoryBatch(string ordersJSON, int count)
{
   string json = "{";
   json += "\"session_name\":\"" + InpSessionName + "\",";
   json += "\"account_number\":\"" + g_accountNumber + "\",";
   json += "\"broker\":\"" + g_brokerName + "\",";
   json += "\"magic_number\":" + IntegerToString(InpTrackMagicNumber) + ",";
   json += "\"event\":\"history\",";
   json += "\"orders\":[" + ordersJSON + "]}";
   
   SendHTTP(json);
   PrintFormat("[Tracker] Sent history batch: %d orders", count);
}

//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string info = "═══ EA Strategy Tracker v1.0 ═══\n";
   info += "Session: " + InpSessionName + "\n";
   info += "Tracking Magic: " + (InpTrackMagicNumber == 0 ? "ALL" : IntegerToString(InpTrackMagicNumber)) + "\n";
   info += "Account: " + g_accountNumber + " | " + g_brokerName + "\n";
   info += "─────────────────────────\n";
   info += "Active Positions: " + IntegerToString(g_posCount) + "\n";
   
   if(g_posCount > 0)
   {
      info += "\n--- Tracked Positions ---\n";
      for(int i = 0; i < g_posCount; i++)
      {
         info += StringFormat("#%d %s %s %.2f @ %.5f\n",
            g_positions[i].ticket, g_positions[i].symbol,
            g_positions[i].type == 0 ? "BUY" : "SELL",
            g_positions[i].volume, g_positions[i].openPrice);
      }
   }
   
   info += "\nLast Send: " + (g_lastSendTime > 0 ? TimeToString(g_lastSendTime) : "Never") + "\n";
   info += "Server: " + (InpServerURL != "" ? "Connected" : "NOT SET!");
   
   Comment(info);
}
//+------------------------------------------------------------------+
