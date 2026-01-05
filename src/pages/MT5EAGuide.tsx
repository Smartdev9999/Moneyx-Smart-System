import { Link } from 'react-router-dom';
import { ArrowLeft, Settings, TrendingUp, TrendingDown, Shield, AlertTriangle, Download, FileCode, Info, Filter } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const MT5EAGuide = () => {
  const fullEACode = `//+------------------------------------------------------------------+
//|                   Moneyx Smart Gold System v5.1                    |
//|           Smart Money Trading System with CDC Action Zone          |
//|           + Grid Trading + Auto Scaling + Dashboard Panel          |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "5.10"
#property strict

// *** Logo File ***
// ใส่ไฟล์โลโก้ไว้ใน MQL5\\Images\\mpmLogo_500.bmp
// หมายเหตุ: ใช้วิธีโหลดจากไฟล์ตรง (ไม่ใช้ #resource) เพื่อให้คอมไพล์/Tester เสถียร

// *** Include CTrade ***
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ======================= ENUMERATIONS =========================== |
//+------------------------------------------------------------------+

// Signal Strategy Selection
enum ENUM_SIGNAL_STRATEGY
{
   STRATEGY_ZIGZAG = 0,      // ZigZag++ Structure
   STRATEGY_EMA_CHANNEL = 1, // EMA Channel (High/Low)
   STRATEGY_BOLLINGER = 2,   // Bollinger Bands
   STRATEGY_SMC = 3          // Smart Money Concepts (Order Block)
};

// Bollinger Bands MA Type
enum ENUM_BB_MA_TYPE
{
   BB_MA_SMA = 0,    // SMA
   BB_MA_EMA = 1,    // EMA
   BB_MA_SMMA = 2,   // SMMA (RMA)
   BB_MA_WMA = 3     // WMA
};

// ZigZag Signal Mode
enum ENUM_ZIGZAG_SIGNAL_MODE
{
   ZIGZAG_BOTH = 0,     // Both Signals (LL,HL=BUY | HH,LH=SELL)
   ZIGZAG_SINGLE = 1    // Single Signal (LL=BUY | HH=SELL)
};

// EMA Signal Bar Index
enum ENUM_EMA_SIGNAL_BAR
{
   EMA_CURRENT_BAR = 0,    // Current Bar (Real-time)
   EMA_LAST_BAR_CLOSED = 1 // Last Bar Closed (Confirmed)
};

// Trade Mode
enum ENUM_TRADE_MODE
{
   TRADE_BUY_SELL = 0,  // Buy and Sell
   TRADE_BUY_ONLY = 1,  // Buy Only
   TRADE_SELL_ONLY = 2  // Sell Only
};

// Lot Calculation Mode
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,       // Fixed Lot
   LOT_RISK_PERCENT = 1,  // Risk % of Balance
   LOT_RISK_DOLLAR = 2    // Fixed Dollar Risk
};

// Grid Lot Mode
enum ENUM_GRID_LOT_MODE
{
   GRID_LOT_CUSTOM = 0,    // Custom Lot (use string)
   GRID_LOT_ADD = 1        // Add Lot (InitialLot + AddLot*Level)
};

// Grid Gap Type
enum ENUM_GRID_GAP_TYPE
{
   GAP_FIXED_POINTS = 0,    // Fixed Points
   GAP_CUSTOM_DISTANCE = 1, // Custom Distance
   GAP_ATR_BASED = 2        // ATR-Based Dynamic
};

// Stop Loss Action Mode
enum ENUM_SL_ACTION_MODE
{
   SL_ACTION_CLOSE = 0,     // Close Positions (Stop Loss)
   SL_ACTION_HEDGE = 1      // Hedge Positions (Lock Loss)
};

// License Status Enumeration
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License Valid
   LICENSE_EXPIRING_SOON,   // License Expiring Soon (within 7 days)
   LICENSE_EXPIRED,         // License Expired
   LICENSE_NOT_FOUND,       // Account Not Registered
   LICENSE_SUSPENDED,       // License Suspended
   LICENSE_ERROR            // Connection Error
};

// Sync Event Type (for real-time data sync)
enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,          // Scheduled sync (daily)
   SYNC_ORDER_OPEN,         // Order opened
   SYNC_ORDER_CLOSE         // Order closed
};

// Global variables for trade tracking
int g_lastOrderCount = 0;    // Track open orders for sync events

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//+------------------------------------------------------------------+

//--- [ SIGNAL STRATEGY SETTINGS ] ----------------------------------
input string   InpSignalHeader = "=== SIGNAL STRATEGY SETTINGS ===";  // ___
input ENUM_SIGNAL_STRATEGY InpSignalStrategy = STRATEGY_ZIGZAG;  // Signal Strategy

//--- [ ZIGZAG++ SETTINGS ] -----------------------------------------
input string   InpZigZagHeader = "=== ZIGZAG++ SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpZigZagTimeframe = PERIOD_CURRENT;  // ZigZag Timeframe
input int      InpDepth        = 12;          // ZigZag Depth
input int      InpDeviation    = 5;           // ZigZag Deviation (pips)
input int      InpBackstep     = 2;           // ZigZag Backstep
input color    InpBullColor    = clrLime;     // Bull Color (HL labels)
input color    InpBearColor    = clrRed;      // Bear Color (HH, LH labels)
input bool     InpShowLabels   = true;        // Show HH/HL/LH/LL Labels
input bool     InpShowLines    = true;        // Show ZigZag Lines
input ENUM_ZIGZAG_SIGNAL_MODE InpZigZagSignalMode = ZIGZAG_BOTH;  // ZigZag Signal Mode

//--- [ EMA CHANNEL SETTINGS ] --------------------------------------
input string   InpEMAHeader = "=== EMA CHANNEL SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpEMATimeframe = PERIOD_CURRENT;  // EMA Channel Timeframe
input int      InpEMAHighPeriod = 20;         // EMA High Period
input int      InpEMALowPeriod = 20;          // EMA Low Period
input color    InpEMAHighColor = clrDodgerBlue;  // EMA High Line Color
input color    InpEMALowColor = clrOrangeRed;    // EMA Low Line Color
input bool     InpShowEMALines = true;        // Show EMA Lines on Chart
input ENUM_EMA_SIGNAL_BAR InpEMASignalBar = EMA_LAST_BAR_CLOSED;  // Signal Bar Index

//--- [ BOLLINGER BANDS SETTINGS ] ----------------------------------
input string   InpBBHeader = "=== BOLLINGER BANDS SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpBBTimeframe = PERIOD_CURRENT;  // Bollinger Bands Timeframe
input int      InpBBPeriod = 20;              // BB Period (Length)
input double   InpBBDeviation = 2.0;          // BB Deviation (StdDev Multiplier)
input ENUM_BB_MA_TYPE InpBBMAType = BB_MA_SMA;  // BB MA Type
input color    InpBBUpperColor = clrRed;      // BB Upper Band Color
input color    InpBBLowerColor = clrGreen;    // BB Lower Band Color
input color    InpBBBasisColor = clrBlue;     // BB Basis (Middle) Color
input bool     InpShowBBLines = true;         // Show BB Lines on Chart
input ENUM_EMA_SIGNAL_BAR InpBBSignalBar = EMA_LAST_BAR_CLOSED;  // BB Signal Bar Index

//--- [ SMART MONEY CONCEPTS SETTINGS ] -----------------------------
input string   InpSMCHeader = "=== SMART MONEY CONCEPTS (ORDER BLOCK) ===";  // ___
input ENUM_TIMEFRAMES InpSMCTimeframe = PERIOD_CURRENT;  // SMC Timeframe

// Internal Structure Settings (Short-term OBs)
input int      InpSMCInternalLength = 5;      // Internal Structure Length
input bool     InpSMCShowInternalOB = true;   // Show Internal Order Blocks
input int      InpSMCMaxInternalOB = 5;       // Max Internal Order Blocks
input color    InpSMCInternalBullColor = C'91,156,246';   // Internal Bullish OB Color
input color    InpSMCInternalBearColor = C'247,124,128';  // Internal Bearish OB Color

// Swing Structure Settings (Major OBs)
input int      InpSMCSwingLength = 50;        // Swing Detection Length (bars)
input bool     InpSMCShowSwingOB = true;      // Show Swing Order Blocks
input int      InpSMCMaxSwingOB = 5;          // Max Swing Order Blocks
input color    InpSMCSwingBullColor = C'24,72,204';       // Swing Bullish OB Color (darker)
input color    InpSMCSwingBearColor = C'178,40,51';       // Swing Bearish OB Color (darker)

// Historical Scan
input int      InpSMCHistoryBars = 500;       // Historical Bars to Scan (0=Disable)

// Legacy compatibility (mapped to internal + swing)
input bool     InpSMCShowBullishOB = true;    // Show Bullish Order Blocks
input bool     InpSMCShowBearishOB = true;    // Show Bearish Order Blocks
input color    InpSMCBullOBColor = clrDodgerBlue;   // Default Bullish OB Color
input color    InpSMCBearOBColor = clrCrimson;      // Default Bearish OB Color
input bool     InpSMCRequireTouch = true;     // Require Price Touch OB (for signal)
input ENUM_EMA_SIGNAL_BAR InpSMCSignalBar = EMA_LAST_BAR_CLOSED;  // SMC Signal Bar Index
input bool     InpSMCConfluenceFilter = true;  // Confluence Filter (merge overlapping OBs)
input double   InpSMCConfluencePercent = 50.0; // Confluence Overlap % (0-100)

input string   InpCDCHeader    = "=== CDC ACTION ZONE SETTINGS ===";  // ___
input bool     InpUseCDCFilter = true;        // Use CDC Action Zone Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;  // CDC Filter Timeframe
input int      InpCDCFastPeriod = 12;         // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;         // CDC Slow EMA Period
input bool     InpShowCDCLines = true;        // Show CDC Lines on Chart

//--- [ TRADE MODE SETTINGS ] ---------------------------------------
input string   InpTradeModeHeader = "=== TRADE MODE SETTINGS ===";  // ___
input ENUM_TRADE_MODE InpTradeMode = TRADE_BUY_SELL;  // Trade Mode

//--- [ AUTO BALANCE SCALING ] --------------------------------------
input string   InpAutoScaleHeader = "=== AUTO BALANCE SCALING ===";  // ___
input bool     InpUseAutoScale = false;      // Enable Auto Balance Scaling
input double   InpBaseAccount = 1000.0;      // Base Account Size ($) - multiplier base
input bool     InpUseFixedScale = false;     // Enable Fixed Scale Account (lock scale size)
input double   InpFixedScaleAccount = 500.0; // Fixed Scale Account ($) - lock at this size
// Auto Scale จะปรับขนาดอัตโนมัติสำหรับ:
// - Trade Settings: Initial Lot, Grid Loss Lot, Grid Profit Lot
// - Take Profit: TP Dollar, Group TP ($ only)
// - Stop Loss: SL Dollar ($ only)
// หมายเหตุ: TP/SL Points ไม่ปรับตาม Scale เพราะเป็นระยะทางคงที่
// ตัวอย่าง: Base=1000$, Account=2000$ → ค่าที่เป็น $ และ Lot จะ x2
// Fixed Scale: เปิดใช้งานเพื่อล็อคขนาดไว้ที่ค่าที่กำหนด ไม่ว่า Balance จะเป็นเท่าไหร่

//--- [ TRADING SETTINGS ] ------------------------------------------
input string   InpTradingHeader = "=== TRADING SETTINGS ===";  // ___
input ENUM_LOT_MODE InpLotMode = LOT_FIXED;  // Lot Mode
input double   InpInitialLot   = 0.01;       // Initial Lot Size (Base)
input double   InpRiskPercent  = 1.0;        // Risk % of Balance (for Risk Mode)
input double   InpRiskDollar   = 50.0;       // Fixed Dollar Risk (for Risk Mode)
input int      InpMagicNumber  = 123456;     // Magic Number

//--- [ GRID LOSS SIDE SETTINGS ] -----------------------------------
input string   InpGridLossHeader = "----- Grid Loss Side -----";  // ___
input int      InpGridLossMaxTrades = 5;     // Max Grid Trades (0 - Disable Grid Trade)
input ENUM_GRID_LOT_MODE InpGridLossLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridLossCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridLossAddLot = 0.4;      // Add Lot per Level (0 = Same as Initial)
input ENUM_GRID_GAP_TYPE InpGridLossGapType = GAP_FIXED_POINTS;  // Grid Gap Type
input int      InpGridLossPoints = 50;       // Grid Points (points)
input string   InpGridLossCustomDist = "100;200;300;400;500";  // Custom Grid Distance (separate by semicolon ;)
// ATR-Based Grid Loss Settings
input ENUM_TIMEFRAMES InpGridLossATRTimeframe = PERIOD_H1;  // ATR Timeframe (for ATR-Based)
input int      InpGridLossATRPeriod = 14;    // ATR Period (for ATR-Based)
input double   InpGridLossATRMultiplier = 1.5;  // ATR Multiplier (for ATR-Based)
input bool     InpGridLossOnlySignal = false;  // Grid Trade Only in Signal
input bool     InpGridLossNewCandle = true;    // Grid Trade Only New Candle
input bool     InpGridLossDontOpenSameCandle = true;  // Don't Open in Same Initial Candle

//--- [ GRID PROFIT SIDE SETTINGS ] ---------------------------------
input string   InpGridProfitHeader = "----- Grid Profit Side -----";  // ___
input bool     InpUseGridProfit = true;      // Use Profit Grid
input int      InpGridProfitMaxTrades = 3;   // Max Grid Trades (0 - Disable Grid Trade)
input ENUM_GRID_LOT_MODE InpGridProfitLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridProfitCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridProfitAddLot = 0.4;    // Add Lot per Level (0 = Same as Initial)
input ENUM_GRID_GAP_TYPE InpGridProfitGapType = GAP_CUSTOM_DISTANCE;  // Grid Gap Type
input int      InpGridProfitPoints = 100;    // Grid Points (points)
input string   InpGridProfitCustomDist = "100;200;500";  // Custom Grid Distance (separate by semicolon ;)
// ATR-Based Grid Profit Settings
input ENUM_TIMEFRAMES InpGridProfitATRTimeframe = PERIOD_H1;  // ATR Timeframe (for ATR-Based)
input int      InpGridProfitATRPeriod = 14;   // ATR Period (for ATR-Based)
input double   InpGridProfitATRMultiplier = 1.0;  // ATR Multiplier (for ATR-Based)
input bool     InpGridProfitOnlySignal = false;  // Grid Trade Only in Signal
input bool     InpGridProfitNewCandle = true;    // Grid Trade Only New Candle
input bool     InpGridProfitDontOpenSameCandle = true;  // Don't Open in Same Initial Candle
//--- [ TAKE PROFIT SETTINGS ] --------------------------------------
input string   InpTPHeader = "=== TAKE PROFIT SETTINGS ===";  // ___

// TP Fixed Dollar
input bool     InpUseTPDollar = true;        // Use TP Fixed Dollar
input double   InpTPDollarAmount = 100.0;    // TP Dollar Amount ($)

// TP in Points
input bool     InpUseTPPoints = false;       // Use TP in Points (from Average Price)
input int      InpTPPoints = 2000;           // TP Points (points)

// TP Percent of Balance
input bool     InpUseTPPercent = false;      // Use TP % of Balance
input double   InpTPPercent = 5.0;           // TP Percent of Balance (%)

// Accumulate Close (สะสมกำไรเพื่อปิดรวบ)
input bool     InpUseAccumulateClose = true;      // Use Accumulate Close
input double   InpAccumulateTarget = 20000.0;     // Accumulate Close Target ($)

// Visual Lines
input bool     InpShowAverageLine = true;    // Show Average Price Line
input bool     InpShowTPLine = true;         // Show TP Line
input color    InpAverageLineColor = clrYellow;  // Average Line Color
input color    InpTPLineColor = clrLime;     // TP Line Color

//--- [ STOP LOSS SETTINGS ] ----------------------------------------
input string   InpSLHeader = "=== STOP LOSS SETTINGS ===";  // ___
input bool     InpUseSLSettings = true;      // Enable Stop Loss Settings
input ENUM_SL_ACTION_MODE InpSLActionMode = SL_ACTION_CLOSE;  // SL Action Mode

// SL Fixed Dollar
input bool     InpUseSLDollar = true;        // Use SL Fixed Dollar
input double   InpSLDollarAmount = 50.0;     // SL Dollar Amount ($)

// SL in Points
input bool     InpUseSLPoints = false;       // Use SL in Points (from Average Price)
input int      InpSLPoints = 1000;           // SL Points (points)

// SL Percent of Balance
input bool     InpUseSLPercent = false;      // Use SL % of Balance
input double   InpSLPercent = 3.0;           // SL Percent of Balance (%)

// Visual Lines
input bool     InpShowSLLine = true;         // Show SL Line
input color    InpSLLineColor = clrRed;      // SL Line Color

//--- [ PRICE ACTION CONFIRMATION SETTINGS ] ------------------------
input string   InpPAHeader = "=== PRICE ACTION CONFIRMATION ===";  // ___
input bool     InpUsePAConfirm = false;       // Use Price Action Confirmation
input int      InpPALookback = 3;             // Max Candles to Wait for PA (1-10)

// Bullish PA Patterns
input string   InpPABullHeader = "----- Bullish Patterns -----";  // ___
input bool     InpPAHammer = true;            // Hammer / Pin Bar (Bullish)
input bool     InpPABullEngulfing = true;     // Bullish Engulfing
input bool     InpPATweezerBottom = true;     // Tweezer Bottom
input bool     InpPAMorningStar = true;       // Morning Star (3-Candle)
input bool     InpPAOutsideCandleBull = true; // Outside Candle Reversal (Bullish)
input bool     InpPAPullbackBuy = true;       // Pullback Buy Pattern
input bool     InpPAInsideCandleBull = true;  // Inside Candle Reversal (Bullish)
input bool     InpPABullHotdog = true;        // Bullish Hotdog Pattern

// Bearish PA Patterns
input string   InpPABearHeader = "----- Bearish Patterns -----";  // ___
input bool     InpPAShootingStar = true;      // Shooting Star / Pin Bar (Bearish)
input bool     InpPABearEngulfing = true;     // Bearish Engulfing
input bool     InpPATweezerTop = true;        // Tweezer Top
input bool     InpPAEveningStar = true;       // Evening Star (3-Candle)
input bool     InpPAOutsideCandleBear = true; // Outside Candle Reversal (Bearish)
input bool     InpPAPullbackSell = true;      // Pullback Sell Pattern
input bool     InpPAInsideCandleBear = true;  // Inside Candle Reversal (Bearish)
input bool     InpPABearHotdog = true;        // Bearish Hotdog Pattern

// PA Detection Settings
input string   InpPASettingsHeader = "----- PA Detection Settings -----";  // ___
input double   InpPAPinRatio = 2.0;           // Pin Bar Tail/Body Ratio (min)
input double   InpPABodyMinRatio = 0.3;       // Engulfing Body Min Ratio (of range)
input double   InpPADojiMaxRatio = 0.2;       // Doji Max Body Ratio (for indecision)
input double   InpPASpinningTopRatio = 0.3;   // Spinning Top Max Body Ratio

//--- [ TIME FILTER ] -----------------------------------------------
input string   InpTimeHeader   = "=== TIME FILTER ===";  // ___
input bool     InpUseTimeFilter = false;      // Use Time Filter

// Tradable Time Sessions [Server Time] (format: hh:mm-hh:mm)
input string   InpSession1 = "03:10-12:40";   // Tradable Session #1 [hh:mm-hh:mm]
input string   InpSession2 = "15:10-22:00";   // Tradable Session #2 [hh:mm-hh:mm]
input string   InpSession3 = "";              // Tradable Session #3 [hh:mm-hh:mm]

// Friday Special Sessions (if empty, use normal sessions)
input string   InpFridayHeader = "----- Friday Sessions -----";  // ___
input string   InpFridaySession1 = "03:10-12:40";  // Friday Session #1 [hh:mm-hh:mm]
input string   InpFridaySession2 = "";             // Friday Session #2 [hh:mm-hh:mm]
input string   InpFridaySession3 = "";             // Friday Session #3 [hh:mm-hh:mm]

// Tradable Day Settings
input string   InpDayHeader = "----- Tradable Days -----";  // ___
input bool     InpTradeMonday = true;         // Monday
input bool     InpTradeTuesday = true;        // Tuesday
input bool     InpTradeWednesday = true;      // Wednesday
input bool     InpTradeThursday = true;       // Thursday
input bool     InpTradeFriday = true;         // Friday
input bool     InpTradeSaturday = false;      // Saturday
input bool     InpTradeSunday = false;        // Sunday

//--- [ NEWS STOP FILTER ] ------------------------------------------
input string   InpNewsHeader = "=== NEWS STOP FILTER ===";  // ___
input bool     InpEnableNewsFilter = false;   // Enable News Filter
input bool     InpNewsUseChartCurrency = false;  // Current Chart Currencies to Filter News
input string   InpNewsCurrencies = "USD";     // Select Currency to Filter News (e.g. USD;EUR;GBP)

// Low Impact News Settings
input string   InpNewsLowHeader = "----- Low Impact News -----";  // ___
input bool     InpFilterLowNews = false;      // Filter Low Impact News
input int      InpPauseBeforeLow = 60;        // Pause Before a Low News (Min.)
input int      InpPauseAfterLow = 30;         // Pause After a Low News (Min.)

// Medium Impact News Settings
input string   InpNewsMedHeader = "----- Medium Impact News -----";  // ___
input bool     InpFilterMedNews = false;      // Filter Medium Impact News
input int      InpPauseBeforeMed = 60;        // Pause Before a Medium News (Min.)
input int      InpPauseAfterMed = 30;         // Pause After a Medium News (Min.)

// High Impact News Settings
input string   InpNewsHighHeader = "----- High Impact News -----";  // ___
input bool     InpFilterHighNews = true;      // Filter High Impact News
input int      InpPauseBeforeHigh = 240;      // Pause Before a High News (Min.)
input int      InpPauseAfterHigh = 240;       // Pause After a High News (Min.)

// Custom News Settings (by keyword)
input string   InpNewsCustomHeader = "----- Custom News -----";  // ___
input bool     InpFilterCustomNews = true;    // Filter Custom News
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;President;Funds Rate;FOMC;Fed Chair Powell";  // Put News Title - Separate by semicolon(;)
input int      InpPauseBeforeCustom = 300;    // Pause Before a Custom News (Min.)
input int      InpPauseAfterCustom = 300;     // Pause After a Custom News (Min.)

//--- [ DASHBOARD SETTINGS ] ----------------------------------------
input string   InpDashboardHeader = "=== DASHBOARD SETTINGS ===";  // ___
input bool     InpShowDashboard = true;        // Show Dashboard Panel
input bool     InpOpenZigZagTFChart = false;   // (Optional) Open ZigZag TF chart for object visibility (may cause issues on some terminals)
input int      InpDashboardX = 10;             // Dashboard X Position (pixels from left)
input int      InpDashboardY = 30;             // Dashboard Y Position (pixels from top)
input int      InpDashboardWidth = 280;        // Dashboard Width (pixels)
input color    InpDashHeaderColor = clrForestGreen;  // Header Background Color
input color    InpDashDetailColor = clrDarkSlateGray; // Detail Section Color
input color    InpDashHistoryColor = clrDarkGreen;   // History Section Color
input int      InpLogoWidth = 150;             // Logo Width (pixels)
input int      InpLogoHeight = 60;             // Logo Height (pixels)

//--- [ LICENSE SETTINGS ] ------------------------------------------
input string   InpLicenseHeader = "=== LICENSE SETTINGS ===";  // ___
input string   InpLicenseServer = "https://lkbhomsulgycxawwlnfh.supabase.co";  // License Server URL
input int      InpLicenseCheckMinutes = 60;    // License Check Interval (minutes)
input int      InpDataSyncMinutes = 5;         // Account Data Sync Interval (minutes)

// ====== HARDCODED API SECRET - DO NOT MODIFY ======
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

//+------------------------------------------------------------------+
//| ===================== GLOBAL VARIABLES ========================= |
//+------------------------------------------------------------------+

// License Verification Variables
bool              g_isLicenseValid = false;
bool              g_isTesterMode = false;
ENUM_LICENSE_STATUS g_licenseStatus = LICENSE_ERROR;
string            g_customerName = "";
string            g_packageType = "";
string            g_tradingSystem = "";
datetime          g_expiryDate = 0;
int               g_daysRemaining = 0;
bool              g_isLifetime = false;
string            g_lastLicenseError = "";
datetime          g_lastLicenseCheck = 0;
datetime          g_lastDataSync = 0;
datetime          g_lastExpiryPopup = 0;
string            g_licenseServerUrl = "";
int               g_licenseCheckInterval = 60;
int               g_dataSyncInterval = 5;

// Dashboard Control Variables
bool g_eaIsPaused = false;           // EA Pause State (true = paused, false = running)
bool g_showConfirmDialog = false;    // Confirmation dialog visible
string g_confirmAction = "";         // Pending action: "CLOSE_BUY", "CLOSE_SELL", "CLOSE_ALL"
string DashPrefix = "DASH_";         // Dashboard object prefix

// Dashboard History Variables
double g_profitDaily = 0.0;
double g_profitWeekly = 0.0;
double g_profitMonthly = 0.0;
double g_profitAllTime = 0.0;
double g_maxDrawdownPercent = 0.0;
double g_peakBalance = 0.0;
datetime g_lastDayCheck = 0;
datetime g_lastWeekCheck = 0;
datetime g_lastMonthCheck = 0;

// ZigZag++ Structure (based on DevLucem ZigZag++)
struct ZigZagPoint
{
   double    price;
   datetime  time;
   int       barIndex;
   int       direction;  // 1 = High, -1 = Low
   string    label;      // "HH", "HL", "LH", "LL"
};

ZigZagPoint ZZPoints[];
int ZZPointCount = 0;
string LastZZLabel = "";       // Latest closed ZigZag label
int CurrentDirection = 0;       // Current ZigZag direction

// Trade Objects
CTrade trade;

// CDC Action Zone Variables
string CDCTrend = "NEUTRAL";
double CDCFast = 0;
double CDCSlow = 0;
double CDCAP = 0;
color CDCZoneColor = clrWhite;

// Chart Objects Prefix
string ZZPrefix = "ZZ_";
string CDCPrefix = "CDC_";
string TPPrefix = "TP_";
string EMAPrefix = "EMA_";
string PAPrefix = "PA_";  // Price Action arrows and labels

// Track which candle (shift) produced the most recent PA confirmation
int g_lastPABuyShift = 1;
int g_lastPASellShift = 1;

// EMA Channel Variables
double EMAHigh = 0;
double EMALow = 0;
string EMASignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastEMASignalTime = 0;

// Bollinger Bands Variables
double BBUpper = 0;
double BBLower = 0;
double BBBasis = 0;
string BBSignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastBBSignalTime = 0;
string BBPrefix = "BB_";
int BBHandle = INVALID_HANDLE;  // Bollinger Bands indicator handle

// ATR-Based Grid Variables
int g_atrGridLossHandle = INVALID_HANDLE;    // ATR handle for Grid Loss
int g_atrGridProfitHandle = INVALID_HANDLE;  // ATR handle for Grid Profit
double g_lastATRGridLossValue = 0;           // Last ATR value for Grid Loss
double g_lastATRGridProfitValue = 0;         // Last ATR value for Grid Profit

// Bollinger Bands Signal Reset
bool g_bbBuyResetPhaseBelowBand = false;   // Price has touched/closed above upper band
bool g_bbSellResetPhaseAboveBand = false;  // Price has touched/closed below lower band

// Smart Money Concepts (Order Block) Variables
string SMCPrefix = "SMC_";
string SMCSignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastSMCSignalTime = 0;
bool g_smcBuyResetRequired = false;
bool g_smcSellResetRequired = false;
bool g_smcBuyResetPhaseComplete = false;
bool g_smcSellResetPhaseComplete = false;
bool g_smcBuyTouchedOB = false;   // Price touched Bullish OB (support)
bool g_smcSellTouchedOB = false;  // Price touched Bearish OB (resistance)

// *** EA-INDICATOR COMMUNICATION VIA GLOBAL VARIABLES ***
// These Global Variables are used to send trade signals to the indicator
// so it can display PA labels only when EA actually opens an order
string GV_EA_BUY_SIGNAL = "MONEYX_EA_BUY_SIGNAL";     // 1.0 = BUY triggered
string GV_EA_SELL_SIGNAL = "MONEYX_EA_SELL_SIGNAL";   // 1.0 = SELL triggered
string GV_EA_BUY_PA = "MONEYX_EA_BUY_PA";             // PA Pattern code (1=Hammer, 2=Engulf, etc.)
string GV_EA_SELL_PA = "MONEYX_EA_SELL_PA";           // PA Pattern code
string GV_EA_BUY_TIME = "MONEYX_EA_BUY_TIME";         // Signal bar time (datetime as double)
string GV_EA_SELL_TIME = "MONEYX_EA_SELL_TIME";       // Signal bar time

// SMC Settings Sync (EA writes, Indicator reads to match display)
string GV_SMC_SWING_LENGTH = "MONEYX_SMC_SWING_LENGTH";
string GV_SMC_INTERNAL_LENGTH = "MONEYX_SMC_INTERNAL_LENGTH";
string GV_SMC_MAX_OB = "MONEYX_SMC_MAX_OB";
string GV_SMC_BULL_OB_COLOR = "MONEYX_SMC_BULL_OB_COLOR";
string GV_SMC_BEAR_OB_COLOR = "MONEYX_SMC_BEAR_OB_COLOR";
string GV_SMC_ENABLED = "MONEYX_SMC_ENABLED";  // 1.0 = SMC strategy active

// PA Pattern Encoding (for GV_EA_BUY_PA / GV_EA_SELL_PA)
// 1=Hammer, 2=Engulf, 3=Tweezer, 4=MorningStar/EveningStar, 5=InsideCandle, 6=Hotdog
// 7=ShootingStar, 8=OutsideCandle, 9=Pullback, 10=Unknown

// Track if price is CURRENTLY touching an OB zone (this tick)
// (Needed for reset logic: "move away" should mean "not touching now")
bool g_smcBuyTouchingNow = false;
bool g_smcSellTouchingNow = false;

// Order Block Structure
struct OrderBlockData
{
   double   high;           // OB High price
   double   low;            // OB Low price
   datetime time;           // OB formation time
   int      barIndex;       // Bar index when OB formed
   int      bias;           // +1 = Bullish, -1 = Bearish
   bool     mitigated;      // True if price has broken through OB
   string   objName;        // Chart object name
   int      obType;         // 0 = Internal, 1 = Swing (for separate coloring)
};

// Order Block Arrays - Unified (used for current detection)
OrderBlockData BullishOBs[];
OrderBlockData BearishOBs[];
int BullishOBCount = 0;
int BearishOBCount = 0;

// Separate arrays for Internal vs Swing Order Blocks (LuxAlgo style)
OrderBlockData InternalBullOBs[];
OrderBlockData InternalBearOBs[];
OrderBlockData SwingBullOBs[];
OrderBlockData SwingBearOBs[];
int InternalBullOBCount = 0;
int InternalBearOBCount = 0;
int SwingBullOBCount = 0;
int SwingBearOBCount = 0;

// Prevent already-consumed / already-mitigated OBs from being re-created
// We store OB formation times that have been removed, and skip re-adding them.
datetime g_smcRemovedBullTimes[];
datetime g_smcRemovedBearTimes[];
datetime g_lastSMCClosedBarTime = 0; // last processed CLOSED candle time on InpSMCTimeframe
bool g_historicalScanDone = false;  // Flag to ensure historical scan runs once per init

bool IsSMCRemovedTime(datetime t, bool isBullish)
{
   if(t <= 0) return false;

   if(isBullish)
   {
      for(int i = 0; i < ArraySize(g_smcRemovedBullTimes); i++)
         if(g_smcRemovedBullTimes[i] == t) return true;
   }
   else
   {
      for(int i = 0; i < ArraySize(g_smcRemovedBearTimes); i++)
         if(g_smcRemovedBearTimes[i] == t) return true;
   }

   return false;
}

void RememberSMCRemovedTime(datetime t, bool isBullish)
{
   if(t <= 0) return;
   if(IsSMCRemovedTime(t, isBullish)) return;

   // Keep list bounded to avoid unbounded growth
   int maxKeep = 500;

   if(isBullish)
   {
      int n = ArraySize(g_smcRemovedBullTimes);
      if(n >= maxKeep)
      {
         // drop oldest
         for(int k = 0; k < n - 1; k++) g_smcRemovedBullTimes[k] = g_smcRemovedBullTimes[k + 1];
         ArrayResize(g_smcRemovedBullTimes, n - 1);
         n = ArraySize(g_smcRemovedBullTimes);
      }
      ArrayResize(g_smcRemovedBullTimes, n + 1);
      g_smcRemovedBullTimes[n] = t;
   }
   else
   {
      int n = ArraySize(g_smcRemovedBearTimes);
      if(n >= maxKeep)
      {
         for(int k = 0; k < n - 1; k++) g_smcRemovedBearTimes[k] = g_smcRemovedBearTimes[k + 1];
         ArrayResize(g_smcRemovedBearTimes, n - 1);
         n = ArraySize(g_smcRemovedBearTimes);
      }
      ArrayResize(g_smcRemovedBearTimes, n + 1);
      g_smcRemovedBearTimes[n] = t;
   }
}

// SMC Touch State - Persist across ticks for PA confirmation
bool g_smcBuyTouchedOBPersist = false;   // Persists until used or reset
bool g_smcSellTouchedOBPersist = false;  // Persists until used or reset
string g_smcBuyTouchedOBName = "";       // Which Bullish OB is currently active for PA
string g_smcSellTouchedOBName = "";      // Which Bearish OB is currently active for PA
datetime g_smcBuyTouchTime = 0;          // Time when buy touch detected (TimeCurrent)
datetime g_smcSellTouchTime = 0;         // Time when sell touch detected (TimeCurrent)

// Track which OB was USED to open the last initial order (for reset comparisons)
string g_smcLastBuyOBUsed = "";
string g_smcLastSellOBUsed = "";

// ========================================================================
// SMC LUXALGO-STYLE SWING STRUCTURE TRACKING
// ========================================================================
// Internal Swing Tracking (short-term structure)
double g_InternalSwingHigh = 0;
double g_InternalSwingLow = 0;
int g_InternalSwingHighBar = 0;
int g_InternalSwingLowBar = 0;
bool g_InternalSwingHighCrossed = false;
bool g_InternalSwingLowCrossed = false;
int g_InternalTrendBias = 0;  // 1 = Bullish, -1 = Bearish

// Swing Structure Tracking (major swing - for swing OBs)
double g_SwingHigh = 0;
double g_SwingLow = 0;
int g_SwingHighBar = 0;
int g_SwingLowBar = 0;
bool g_SwingHighCrossed = false;
bool g_SwingLowCrossed = false;
int g_SwingTrendBias = 0;  // 1 = Bullish, -1 = Bearish

// Legacy SMC Swing Points (kept for compatibility)
double SMCSwingHigh = 0;
double SMCSwingLow = 0;
datetime SMCSwingHighTime = 0;
datetime SMCSwingLowTime = 0;
int SMCTrend = 0;  // +1 = Bullish, -1 = Bearish, 0 = Neutral

long ZZTFChartId = 0;

// ZigZag tracking for confirmed points
datetime LastConfirmedZZTime = 0;

// Grid Tracking
datetime InitialBuyBarTime = 0;
datetime InitialSellBarTime = 0;
int GridBuyCount = 0;
int GridSellCount = 0;

// Hedge Lock Flags (prevent multiple hedge orders and stop all trading)
bool g_isHedgedBuy = false;   // True when BUY side is already hedged
bool g_isHedgedSell = false;  // True when SELL side is already hedged
bool g_isHedgeLocked = false; // True when ANY hedge is active - stops ALL new orders
datetime LastGridBuyTime = 0;
datetime LastGridSellTime = 0;

// Accumulate Close Tracking (สะสมกำไรจาก order ที่ปิดไป)
double g_accumulateClosedProfit = 0.0;    // กำไรสะสมจาก order ที่ปิดไปแล้ว
int g_lastKnownPositionCount = 0;          // จำนวน position ล่าสุดเพื่อ detect การปิด
double g_lastKnownFloatingPL = 0.0;        // Floating P/L ล่าสุด
double g_lockedAccumulateTarget = 0.0;     // Locked Scaled Target (ล็อคไว้ตอนเริ่มมี order)

// Price Action Confirmation Tracking
string g_pendingSignal = "NONE";       // "BUY", "SELL", or "NONE"
datetime g_signalBarTime = 0;          // Time when signal was detected
datetime g_signalTouchTime = 0;        // Time when OB/signal touch occurred (PA must come AFTER this)
int g_paWaitCount = 0;                 // Number of candles waited for PA

// *** SIGNAL RESET TRACKING ***
// After closing positions, require signal to reset before allowing new entries
// BUY Reset: Price must close BELOW EMA first, then close ABOVE EMA again
// SELL Reset: Price must close ABOVE EMA first, then close BELOW EMA again
bool g_waitBuySignalReset = false;     // True when waiting for BUY signal to reset
bool g_waitSellSignalReset = false;    // True when waiting for SELL signal to reset
bool g_buyResetPhaseBelowEMA = false;  // True when price has closed below EMA (step 1 of BUY reset)
bool g_sellResetPhaseAboveEMA = false; // True when price has closed above EMA (step 1 of SELL reset)

// For ZigZag Strategy Reset
bool g_buyResetWaitOppositeSignal = false;  // Wait for HH/LH before allowing BUY again
bool g_sellResetWaitOppositeSignal = false; // Wait for LL/HL before allowing SELL again

// *** NEWS FILTER VARIABLES ***
// News Event Structure
struct NewsEvent
{
   string   title;       // News title
   string   country;     // Currency (e.g., USD, EUR)
   datetime time;        // Event time
   string   impact;      // "Low", "Medium", "High"
   bool     isRelevant;  // Matches our filter criteria
};

NewsEvent g_newsEvents[];           // Array of loaded news events
int g_newsEventCount = 0;           // Number of loaded events
datetime g_lastNewsRefresh = 0;     // Last time we SUCCESSFULLY refreshed news data
bool g_isNewsPaused = false;        // True when trading is paused due to news
string g_nextNewsTitle = "";        // Title of upcoming/current news affecting us
datetime g_nextNewsTime = 0;        // Time of upcoming/current news
string g_newsStatus = "OK";         // Current news filter status for dashboard

// *** LAST-KNOWN-GOOD CACHE SYSTEM ***
// Keeps last successful data even if new refresh fails
datetime g_lastGoodNewsTime = 0;    // Time of last successful news load
bool g_usingCachedNews = false;     // True if current data is from cache (refresh failed)

// *** PERSISTENT FILE CACHE ***
string g_newsCacheFile = "MoneyxNewsCache.txt";  // Cache file in MQL5/Files/
datetime g_lastFileCacheSave = 0;   // Last time we saved to file

// *** WEBREQUEST CONFIGURATION CHECK ***
bool g_webRequestConfigured = true;       // Assume configured until proven otherwise (only 4060/4024 errors change this)
datetime g_lastWebRequestCheck = 0;       // Last check time
datetime g_lastWebRequestAlert = 0;       // Last alert time (prevent spam)
int g_webRequestCheckInterval = 3600;     // Check interval (1 hour = 3600 seconds)
bool g_forceNewsRefresh = false;          // Force refresh flag - bypasses hourly check on first call

// *** LOG SPAM PREVENTION ***
bool g_lastPausedState = false;           // Track last pause state to print only on change
string g_lastPauseKey = "";               // Track which news caused pause

// *** NEWS PAUSE COUNTDOWN ***
datetime g_newsPauseEndTime = 0;          // Time when current news pause will end (for countdown display)

//+------------------------------------------------------------------+
//| Check if running in tester mode                                    |
//+------------------------------------------------------------------+
bool IsTesterMode()
{
   return (MQLInfoInteger(MQL_TESTER) || 
           MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE) ||
           MQLInfoInteger(MQL_FRAME_MODE));
}

//+------------------------------------------------------------------+
//| Initialize License System                                          |
//+------------------------------------------------------------------+
bool InitLicense(string baseUrl, int checkIntervalMinutes = 60, int syncIntervalMinutes = 5)
{
   g_licenseServerUrl = baseUrl;
   g_licenseCheckInterval = checkIntervalMinutes;
   g_dataSyncInterval = syncIntervalMinutes;
   g_lastLicenseCheck = 0;
   g_lastDataSync = 0;
   g_lastExpiryPopup = 0;
   
   if(StringLen(g_licenseServerUrl) == 0)
   {
      g_lastLicenseError = "License server URL is empty";
      g_licenseStatus = LICENSE_ERROR;
      return false;
   }
   
   g_licenseStatus = VerifyLicense();
   g_lastLicenseCheck = TimeCurrent();
   
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
   
   if(g_isLicenseValid)
   {
      SyncAccountData();
      g_lastDataSync = TimeCurrent();
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Verify License with Server                                         |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS VerifyLicense()
{
   string url = g_licenseServerUrl + "/functions/v1/verify-license";
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string jsonRequest = "{\\"account_number\\":\\"" + IntegerToString(accountNumber) + "\\"}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "HTTP Error: " + IntegerToString(httpCode);
      return LICENSE_ERROR;
   }
   
   return ParseVerifyResponse(response);
}

//+------------------------------------------------------------------+
//| Parse Verify License Response                                      |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   bool valid = JsonGetBool(response, "valid");
   
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastLicenseError = message;
      
      if(StringFind(message, "not found") >= 0 || StringFind(message, "Not found") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0 || StringFind(message, "inactive") >= 0)
         return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0 || StringFind(message, "Expired") >= 0)
         return LICENSE_EXPIRED;
      
      return LICENSE_ERROR;
   }
   
   g_customerName = JsonGetString(response, "customer_name");
   g_packageType = JsonGetString(response, "package_type");
   g_tradingSystem = JsonGetString(response, "trading_system");
   g_daysRemaining = JsonGetInt(response, "days_remaining");
   g_isLifetime = JsonGetBool(response, "is_lifetime");
   
   string expiryStr = JsonGetString(response, "expiry_date");
   if(StringLen(expiryStr) > 0 && expiryStr != "null")
   {
      g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));
   }
   
   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0)
   {
      return LICENSE_EXPIRING_SOON;
   }
   
   return LICENSE_VALID;
}

//+------------------------------------------------------------------+
//| Sync Account Data to Server (Legacy - calls new function)          |
//+------------------------------------------------------------------+
bool SyncAccountData()
{
   return SyncAccountDataWithEvent(SYNC_SCHEDULED);
}

//+------------------------------------------------------------------+
//| Sync Account Data with Event Type                                  |
//+------------------------------------------------------------------+
bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Calculate Drawdown
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   // Count open orders
   int openOrders = PositionsTotal();
   
   // Calculate portfolio statistics
   double totalProfit = 0;
   double totalDeposit = 0;
   double totalWithdrawal = 0;
   double initialBalance = 0;
   double maxDrawdown = 0;
   int winTrades = 0;
   int lossTrades = 0;
   int totalTrades = 0;
   
   CalculatePortfolioStats(totalProfit, totalDeposit, totalWithdrawal, initialBalance, 
                           maxDrawdown, winTrades, lossTrades, totalTrades);
   
   // Event type string
   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";
   
   // Determine EA status based on current state
   string eaStatus = "working";
   if(g_licenseStatus == LICENSE_SUSPENDED) eaStatus = "suspended";
   else if(g_licenseStatus == LICENSE_EXPIRED) eaStatus = "expired";
   else if(g_licenseStatus == LICENSE_NOT_FOUND || g_licenseStatus == LICENSE_ERROR) eaStatus = "invalid";
   else if(!g_isLicenseValid) eaStatus = "paused";
   
   string json = "{";
   json += "\\"account_number\\":\\"" + IntegerToString(accountNumber) + "\\",";
   json += "\\"balance\\":" + DoubleToString(balance, 2) + ",";
   json += "\\"equity\\":" + DoubleToString(equity, 2) + ",";
   json += "\\"margin_level\\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\\"drawdown\\":" + DoubleToString(drawdown, 2) + ",";
   json += "\\"profit_loss\\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\\"open_orders\\":" + IntegerToString(openOrders) + ",";
   json += "\\"floating_pl\\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\\"total_profit\\":" + DoubleToString(totalProfit, 2) + ",";
   // Portfolio stats
   json += "\\"initial_balance\\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\\"total_deposit\\":" + DoubleToString(totalDeposit, 2) + ",";
   json += "\\"total_withdrawal\\":" + DoubleToString(totalWithdrawal, 2) + ",";
   json += "\\"max_drawdown\\":" + DoubleToString(maxDrawdown, 2) + ",";
   json += "\\"win_trades\\":" + IntegerToString(winTrades) + ",";
   json += "\\"loss_trades\\":" + IntegerToString(lossTrades) + ",";
   json += "\\"total_trades\\":" + IntegerToString(totalTrades) + ",";
   json += "\\"event_type\\":\\"" + eventTypeStr + "\\",";
   json += "\\"ea_status\\":\\"" + eaStatus + "\\"";
   
   // Include trade history on all sync events (scheduled + order close)
   // This ensures historical data is synced on EA startup and periodically
   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2)  // Not empty array "[]"
   {
      json += ",\\"trade_history\\":" + tradeHistoryJson;
   }
   
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "Sync HTTP Error: " + IntegerToString(httpCode);
      Print("[Sync] HTTP Error: ", httpCode);
      return false;
   }
   
   bool success = JsonGetBool(response, "success");
   if(success)
   {
      Print("[Sync] Data synced successfully (event: ", eventTypeStr, ")");
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Calculate Portfolio Statistics from Trade History                  |
//+------------------------------------------------------------------+
void CalculatePortfolioStats(double &totalProfit, double &totalDeposit, double &totalWithdrawal,
                             double &initialBalance, double &maxDrawdown, 
                             int &winTrades, int &lossTrades, int &totalTrades)
{
   totalProfit = 0;
   totalDeposit = 0;
   totalWithdrawal = 0;
   initialBalance = 0;
   maxDrawdown = 0;
   winTrades = 0;
   lossTrades = 0;
   totalTrades = 0;
   
   // Select history for all time
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Portfolio Stats] Failed to select history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   double peakBalance = 0;
   double runningBalance = 0;
   bool firstDeposit = true;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         // Track deposits and withdrawals
         if(dealType == DEAL_TYPE_BALANCE)
         {
            if(dealProfit > 0)
            {
               totalDeposit += dealProfit;
               if(firstDeposit)
               {
                  initialBalance = dealProfit;
                  firstDeposit = false;
               }
            }
            else
            {
               totalWithdrawal += MathAbs(dealProfit);
            }
            runningBalance += dealProfit;
         }
         // Count closed trades (exit or in-out)
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double netProfit = dealProfit + dealSwap + dealCommission;
            totalProfit += netProfit;
            runningBalance += netProfit;
            totalTrades++;
            
            if(netProfit >= 0)
               winTrades++;
            else
               lossTrades++;
         }
         
         // Track max drawdown
         if(runningBalance > peakBalance)
            peakBalance = runningBalance;
         
         if(peakBalance > 0)
         {
            double currentDD = ((peakBalance - runningBalance) / peakBalance) * 100;
            if(currentDD > maxDrawdown)
               maxDrawdown = currentDD;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Build Trade History JSON Array                                     |
//+------------------------------------------------------------------+
string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   
   // Select history for all time
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Trade History] Failed to select history");
      return "[]";
   }
   
   int totalDeals = HistoryDealsTotal();
   
   // Only send last 100 deals to avoid huge payloads
   int startIdx = MathMax(0, totalDeals - 100);
   
   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
         // Skip if not a trade or balance operation
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL && dealType != DEAL_TYPE_BALANCE)
            continue;
         
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double sl = HistoryDealGetDouble(dealTicket, DEAL_SL);
         double tp = HistoryDealGetDouble(dealTicket, DEAL_TP);
         string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         
         // Determine deal type string
         string dealTypeStr = "unknown";
         if(dealType == DEAL_TYPE_BUY) dealTypeStr = "buy";
         else if(dealType == DEAL_TYPE_SELL) dealTypeStr = "sell";
         else if(dealType == DEAL_TYPE_BALANCE) dealTypeStr = "balance";
         
         // Determine entry type string
         string entryTypeStr = "unknown";
         if(dealEntry == DEAL_ENTRY_IN) entryTypeStr = "in";
         else if(dealEntry == DEAL_ENTRY_OUT) entryTypeStr = "out";
         else if(dealEntry == DEAL_ENTRY_INOUT) entryTypeStr = "inout";
         
         // Build JSON object
         if(!first) json += ",";
         first = false;
         
         json += "{";
         json += "\\"deal_ticket\\":" + IntegerToString(dealTicket) + ",";
         json += "\\"order_ticket\\":" + IntegerToString(orderTicket) + ",";
         json += "\\"symbol\\":\\"" + symbol + "\\",";
         json += "\\"deal_type\\":\\"" + dealTypeStr + "\\",";
         json += "\\"entry_type\\":\\"" + entryTypeStr + "\\",";
         json += "\\"volume\\":" + DoubleToString(volume, 2) + ",";
         json += "\\"open_price\\":" + DoubleToString(price, 5) + ",";
         json += "\\"profit\\":" + DoubleToString(profit, 2) + ",";
         json += "\\"swap\\":" + DoubleToString(swap, 2) + ",";
         json += "\\"commission\\":" + DoubleToString(commission, 2) + ",";
         json += "\\"sl\\":" + DoubleToString(sl, 5) + ",";
         json += "\\"tp\\":" + DoubleToString(tp, 5) + ",";
         json += "\\"comment\\":\\"" + comment + "\\",";
         json += "\\"magic_number\\":" + IntegerToString(magic) + ",";
         json += "\\"close_time\\":\\"" + TimeToString(dealTime, TIME_DATE|TIME_SECONDS) + "\\"";
         json += "}";
      }
   }
   
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Real-time sync on order events                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Skip if license is not valid
   if(!g_isLicenseValid) return;
   
   // Skip if in tester mode
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   
   // Check for deal added (order executed)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Get deal info
      if(HistoryDealSelect(trans.deal))
      {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         
         // Only sync for our EA's orders
         if(dealMagic == InpMagicNumber || dealMagic == 0)
         {
            // Order opened
            if(dealEntry == DEAL_ENTRY_IN)
            {
               Print("[Sync] Order opened - syncing data...");
               SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
            }
            // Order closed
            else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               Print("[Sync] Order closed - syncing data with trade history...");
               SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick License Handler                                             |
//+------------------------------------------------------------------+
bool OnTickLicense()
{
   datetime currentTime = TimeCurrent();
   
   if(currentTime - g_lastLicenseCheck >= g_licenseCheckInterval * 60)
   {
      ENUM_LICENSE_STATUS newStatus = VerifyLicense();
      g_lastLicenseCheck = currentTime;
      
      if(newStatus != g_licenseStatus)
      {
         g_licenseStatus = newStatus;
         g_isLicenseValid = (newStatus == LICENSE_VALID || newStatus == LICENSE_EXPIRING_SOON);
         
         if(!g_isLicenseValid)
         {
            ShowLicensePopup(g_licenseStatus);
         }
      }
      
      if(g_licenseStatus == LICENSE_EXPIRING_SOON)
      {
         datetime today = currentTime - (currentTime % 86400);
         if(g_lastExpiryPopup < today)
         {
            ShowLicensePopup(g_licenseStatus);
            g_lastExpiryPopup = currentTime;
         }
      }
   }
   
   if(g_isLicenseValid && (currentTime - g_lastDataSync >= g_dataSyncInterval * 60))
   {
      SyncAccountData();
      g_lastDataSync = currentTime;
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                          |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Moneyx Smart Gold EA - License";
   string message = "";
   uint flags = MB_OK;
   
   switch(status)
   {
      case LICENSE_VALID:
         message = "License Verified Successfully!\\n\\n";
         message += "Customer: " + g_customerName + "\\n";
         message += "Package: " + g_packageType + "\\n";
         message += "System: " + g_tradingSystem + "\\n\\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\\n";
         else
            message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\\n";
         message += "\\nHappy Trading!";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "License Expiring Soon!\\n\\n";
         message += "Customer: " + g_customerName + "\\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + " days\\n";
         message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\\n\\n";
         message += "Please renew your license to continue using.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         message = "License Expired!\\n\\n";
         message += "Your license has expired.\\n";
         message += "Trading is disabled.\\n\\n";
         message += "Please renew your license to continue.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         message = "Account Not Registered!\\n\\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\\n\\n";
         message += "This account is not registered in our system.\\n";
         message += "Please purchase a license to use this EA.\\n\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         message = "License Suspended!\\n\\n";
         message += "Your license has been suspended.\\n";
         message += "Trading is disabled.\\n\\n";
         message += "Please contact support for assistance.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         message = "License Verification Error!\\n\\n";
         message += "Could not verify license.\\n";
         message += "Error: " + g_lastLicenseError + "\\n\\n";
         message += "Please check:\\n";
         message += "1. Internet connection\\n";
         message += "2. WebRequest allowed for:\\n";
         message += "   " + g_licenseServerUrl + "\\n\\n";
         message += "EA will retry on next check.";
         flags = MB_OK | MB_ICONWARNING;
         break;
   }
   
   MessageBox(message, title, flags);
}

//+------------------------------------------------------------------+
//| Send HTTP POST Request                                             |
//+------------------------------------------------------------------+
int SendLicenseRequest(string url, string jsonData, string &response)
{
   char postData[];
   char result[];
   // เพิ่ม x-api-key header สำหรับ authentication
   string headers = "Content-Type: application/json\\r\\nx-api-key: " + EA_API_SECRET + "\\r\\n";
   string resultHeaders;
   
   StringToCharArray(jsonData, postData, 0, StringLen(jsonData));
   ArrayResize(postData, StringLen(jsonData));
   
   int timeout = 10000;
   int httpCode = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
   
   if(httpCode == -1)
   {
      int errorCode = GetLastError();
      g_lastLicenseError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastLicenseError = "WebRequest not allowed. Add URL to allowed list:\\n" + 
                       "Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL\\n" +
                       "Add: " + g_licenseServerUrl;
      }
      
      return -1;
   }
   
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   return httpCode;
}

//+------------------------------------------------------------------+
//| JSON Helper - Get String Value                                     |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\\"" + key + "\\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos < 0)
      return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || 
                                           StringGetCharacter(json, valueStart) == '\\t'))
   {
      valueStart++;
   }
   
   if(StringSubstr(json, valueStart, 4) == "null")
      return "";
   
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\\"", valueStart);
      if(valueEnd < 0)
         return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   
   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == ',' || ch == '}' || ch == ']')
         break;
      valueEnd++;
   }
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Integer Value                                    |
//+------------------------------------------------------------------+
int JsonGetInt(string json, string key)
{
   string value = JsonGetString(json, key);
   if(StringLen(value) == 0)
      return 0;
   return (int)StringToInteger(value);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Boolean Value                                    |
//+------------------------------------------------------------------+
bool JsonGetBool(string json, string key)
{
   string value = JsonGetString(json, key);
   return (value == "true" || value == "1");
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // *** CHECK TESTER MODE - BYPASS LICENSE FOR BACKTEST ***
   g_isTesterMode = IsTesterMode();
   
   if(g_isTesterMode)
   {
      Print("╔══════════════════════════════════════════════════════════════╗");
      Print("║         MONEYX SMART GOLD EA - TESTER MODE                   ║");
      Print("║         License check skipped for backtesting                ║");
      Print("╚══════════════════════════════════════════════════════════════╝");
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
   }
   else
   {
      // *** LIVE TRADING MODE - VERIFY LICENSE ***
      Print("╔══════════════════════════════════════════════════════════════╗");
      Print("║         MONEYX SMART GOLD EA - LIVE TRADING MODE             ║");
      Print("║         Verifying license...                                  ║");
      Print("╚══════════════════════════════════════════════════════════════╝");
      
      if(!InitLicense(InpLicenseServer, InpLicenseCheckMinutes, InpDataSyncMinutes))
      {
         Print("License initialization failed: ", g_lastLicenseError);
      }
      
      ShowLicensePopup(g_licenseStatus);
      
      if(g_isLicenseValid)
      {
         Print("License Valid - Customer: ", g_customerName);
         Print("Package: ", g_packageType, " | System: ", g_tradingSystem);
         if(g_isLifetime)
            Print("License Type: LIFETIME");
         else
            Print("Expiry: ", TimeToString(g_expiryDate, TIME_DATE), " (", g_daysRemaining, " days remaining)");
      }
   }
   
   Print("===========================================");
   Print("Moneyx Smart Gold System v5.1");
   Print("Symbol: ", _Symbol);
   Print("Entry TF: ", EnumToString(Period()));
   Print("ZigZag TF: ", EnumToString(InpZigZagTimeframe));
   Print("CDC Filter TF: ", EnumToString(InpCDCTimeframe));
   Print("Trade Mode: ", EnumToString(InpTradeMode));
   Print("Lot Mode: ", EnumToString(InpLotMode));
   Print("Grid Loss Max: ", InpGridLossMaxTrades);
   Print("Grid Profit Max: ", InpGridProfitMaxTrades);
   Print("===========================================");
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Open a chart for the selected ZigZag timeframe (optional)
   // NOTE: บางเครื่อง/บางโบรกเกอร์มีปัญหากับการ ChartOpen/ChartClose ระหว่าง Re-init (โหลด .set)
   // ทำให้ EA ถูกถอดออกจากชาร์ตได้ จึงปิดค่าเริ่มต้นไว้
   ZZTFChartId = 0;
   if(InpOpenZigZagTFChart && InpZigZagTimeframe != PERIOD_CURRENT && InpZigZagTimeframe != Period())
   {
      ZZTFChartId = ChartOpen(_Symbol, InpZigZagTimeframe);
      if(ZZTFChartId > 0)
         Print("ZigZag TF chart opened: ", ZZTFChartId, " (", EnumToString(InpZigZagTimeframe), ")");
      else
         Print("WARNING: Could not open ZigZag TF chart for ", EnumToString(InpZigZagTimeframe));
   }
   
   // Reset counters
   LastConfirmedZZTime = 0;
   LastEMASignalTime = 0;
   LastBBSignalTime = 0;
   LastSMCSignalTime = 0;
   GridBuyCount = 0;
   GridSellCount = 0;
   InitialBuyBarTime = 0;
   InitialSellBarTime = 0;
   
   // Initialize SMC Order Block arrays
   if(InpSignalStrategy == STRATEGY_SMC)
   {
      // Calculate total max OBs for unified arrays
      int totalMaxOBs = InpSMCMaxInternalOB + InpSMCMaxSwingOB;
      ArrayResize(BullishOBs, totalMaxOBs);
      ArrayResize(BearishOBs, totalMaxOBs);
      BullishOBCount = 0;
      BearishOBCount = 0;
      
      // Initialize separate Internal/Swing arrays
      ArrayResize(InternalBullOBs, InpSMCMaxInternalOB);
      ArrayResize(InternalBearOBs, InpSMCMaxInternalOB);
      ArrayResize(SwingBullOBs, InpSMCMaxSwingOB);
      ArrayResize(SwingBearOBs, InpSMCMaxSwingOB);
      InternalBullOBCount = 0;
      InternalBearOBCount = 0;
      SwingBullOBCount = 0;
      SwingBearOBCount = 0;
      
      // Reset LuxAlgo swing structure tracking
      g_InternalSwingHigh = 0;
      g_InternalSwingLow = 0;
      g_InternalSwingHighBar = 0;
      g_InternalSwingLowBar = 0;
      g_InternalSwingHighCrossed = false;
      g_InternalSwingLowCrossed = false;
      g_InternalTrendBias = 0;
      g_SwingHigh = 0;
      g_SwingLow = 0;
      g_SwingHighBar = 0;
      g_SwingLowBar = 0;
      g_SwingHighCrossed = false;
      g_SwingLowCrossed = false;
      g_SwingTrendBias = 0;
      g_lastSMCClosedBarTime = 0;
      g_historicalScanDone = false;  // Reset for historical scan
      
      Print("=== SMC LuxAlgo Style Initialized ===");
      Print("Internal Length: ", InpSMCInternalLength, " | Max Internal OBs: ", InpSMCMaxInternalOB);
      Print("Swing Length: ", InpSMCSwingLength, " | Max Swing OBs: ", InpSMCMaxSwingOB);
      Print("Historical Bars to Scan: ", InpSMCHistoryBars);
      Print("ATR Filter: Enabled (200-period, threshold 2x)");
      Print("OB Detection: Structure Break (BOS/CHoCH) only");
      
      // *** HISTORICAL SCAN - Load existing non-mitigated OBs ***
      if(InpSMCHistoryBars > 0)
      {
         Print(">>> Starting Historical Order Block Scan...");
         ScanHistoricalOrderBlocks();
         g_historicalScanDone = true;
      }
      
      // *** SYNC SMC SETTINGS TO INDICATOR VIA GLOBAL VARIABLES ***
      GlobalVariableSet(GV_SMC_ENABLED, 1.0);
      GlobalVariableSet(GV_SMC_SWING_LENGTH, (double)InpSMCSwingLength);
      GlobalVariableSet(GV_SMC_INTERNAL_LENGTH, (double)InpSMCInternalLength);
      GlobalVariableSet(GV_SMC_MAX_OB, (double)(InpSMCMaxInternalOB + InpSMCMaxSwingOB));
      GlobalVariableSet(GV_SMC_BULL_OB_COLOR, (double)InpSMCBullOBColor);
      GlobalVariableSet(GV_SMC_BEAR_OB_COLOR, (double)InpSMCBearOBColor);
      Print(">>> SMC Settings synced to Indicator via Global Variables");
   }
   else
   {
      // SMC not active - tell indicator to use its own settings
      GlobalVariableSet(GV_SMC_ENABLED, 0.0);
   }
   
   // Initialize Bollinger Bands indicator handle
   if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      // Get MA method for iBands
      ENUM_MA_METHOD maMethod = MODE_SMA;
      if(InpBBMAType == BB_MA_EMA) maMethod = MODE_EMA;
      else if(InpBBMAType == BB_MA_SMMA) maMethod = MODE_SMMA;
      else if(InpBBMAType == BB_MA_WMA) maMethod = MODE_LWMA;
      
      BBHandle = iBands(_Symbol, InpBBTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      
      if(BBHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create Bollinger Bands indicator handle!");
      }
      else
      {
         Print("Bollinger Bands indicator initialized - Period: ", InpBBPeriod, " | Deviation: ", InpBBDeviation);
         
         // Add BB indicator to chart for visual display
         if(InpShowBBLines)
         {
            ChartIndicatorAdd(0, 0, BBHandle);
            Print("Bollinger Bands indicator added to chart");
         }
      }
   }
   
   // Initialize ATR-Based Grid handles
   if(InpGridLossGapType == GAP_ATR_BASED)
   {
      g_atrGridLossHandle = iATR(_Symbol, InpGridLossATRTimeframe, InpGridLossATRPeriod);
      if(g_atrGridLossHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator handle for Grid Loss!");
         Print("       Grid Loss will use Fixed Points as fallback.");
      }
      else
      {
         Print("ATR Grid Loss initialized - TF: ", EnumToString(InpGridLossATRTimeframe), 
               " | Period: ", InpGridLossATRPeriod, 
               " | Multiplier: ", InpGridLossATRMultiplier);
      }
   }
   
   if(InpGridProfitGapType == GAP_ATR_BASED)
   {
      g_atrGridProfitHandle = iATR(_Symbol, InpGridProfitATRTimeframe, InpGridProfitATRPeriod);
      if(g_atrGridProfitHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator handle for Grid Profit!");
         Print("       Grid Profit will use Fixed Points as fallback.");
      }
      else
      {
         Print("ATR Grid Profit initialized - TF: ", EnumToString(InpGridProfitATRTimeframe), 
               " | Period: ", InpGridProfitATRPeriod, 
               " | Multiplier: ", InpGridProfitATRMultiplier);
      }
   }
   
   Print("Signal Strategy: ", EnumToString(InpSignalStrategy));
   
   // Auto Balance Scaling Status
   if(InpUseAutoScale)
   {
      double scaleFactor = GetScaleFactor();
      double realBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("=== AUTO BALANCE SCALING ENABLED ===");
      Print("Base Account: $", InpBaseAccount);
      Print("Current Balance: $", realBalance);
      
      // Fixed Scale Mode Status
      if(InpUseFixedScale)
      {
         Print(">>> FIXED SCALE MODE: ON <<<");
         Print("Fixed Scale Account: $", InpFixedScaleAccount);
         Print("(Order size locked at $", InpFixedScaleAccount, " regardless of balance)");
      }
      else
      {
         Print("Fixed Scale Mode: OFF (dynamic scaling based on balance)");
      }
      
      Print("Scale Factor: ", DoubleToString(scaleFactor, 2), "x");
      Print("Scaled Initial Lot: ", DoubleToString(ApplyScaleLot(InpInitialLot), 2));
      Print("Scaled TP Dollar: $", DoubleToString(ApplyScaleDollar(InpTPDollarAmount), 2));
      Print("Scaled SL Dollar: $", DoubleToString(ApplyScaleDollar(InpSLDollarAmount), 2));
      Print("Scaled Grid Loss Lot: ", DoubleToString(ApplyScaleLot(InpGridLossAddLot), 2));
      Print("Scaled Grid Profit Lot: ", DoubleToString(ApplyScaleLot(InpGridProfitAddLot), 2));
   }
   else
   {
      Print("Auto Balance Scaling: DISABLED (using fixed values)");
   }
   
   // Create Dashboard Panel
   CreateDashboard();
   g_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // *** TIMER สำหรับอัพเดท Dashboard อัตโนมัติ ***
   // แม้ไม่มี tick (ตลาดไม่เคลื่อนไหว) Dashboard ก็จะอัพเดททุก 1 วินาที
   // หมายเหตุ: ปิด Timer ใน Strategy Tester เพราะทำให้ Backtest ช้ามาก
   if(!MQLInfoInteger(MQL_TESTER))
   {
      EventSetTimer(1);  // เรียก OnTimer ทุก 1 วินาที (เฉพาะ Live Trading)
      Print("Timer enabled: Dashboard auto-refresh every 1 second");
   }
   else
   {
      Print("Strategy Tester detected: Timer disabled for faster backtest");
   }
   
   // Enable Chart Events (optional, helps Visual Tester responsiveness)
   // หมายเหตุ: ไม่ใช้ CHART_EVENT_OBJECT_CREATE/DELETE เพราะอาจทำให้ EA crash
   // เมื่อมี objects จำนวนมากหรือเมื่อบันทึก settings
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   ChartRedraw(0);
   
   Print("EA Started Successfully!");
   Print("Dashboard and buttons are ready (Visual Backtest supported)");
   
   // *** NEWS FILTER - Initialize and load news at startup ***
    if(InpEnableNewsFilter)
    {
       // *** IMPORTANT: Do NOT clear g_newsEvents here ***
       // Keep any existing cache so we have fallback if refresh fails
       
       // Reset only status variables, not data
       g_isNewsPaused = false;       // Reset pause state
       g_nextNewsTitle = "";
       g_nextNewsTime = 0;
       g_newsStatus = "";
       g_usingCachedNews = false;
       g_lastPausedState = false;    // Reset log spam prevention
       g_lastPauseKey = "";
       
       // Assume configured initially - only 4060/4024 errors will change this
       g_webRequestConfigured = true;
       g_lastWebRequestCheck = TimeCurrent();
       
       // *** SET FORCE REFRESH FLAG ***
       // This bypasses the hourly check for the first call
       g_forceNewsRefresh = true;
       
       // Log OnInit state for debugging
       Print("========== NEWS FILTER INITIALIZATION ==========");
       Print("InpEnableNewsFilter = ", InpEnableNewsFilter);
       Print("Existing g_newsEventCount = ", g_newsEventCount, " (preserved from cache)");
       Print("g_forceNewsRefresh = ", g_forceNewsRefresh);
       
       // *** LOAD FILE CACHE FIRST (if any) ***
       // This provides immediate data even before WebRequest
       LoadNewsCacheFromFile();
       Print("After file cache load: g_newsEventCount = ", g_newsEventCount);
       
       // Check configuration (this will set g_webRequestConfigured = false only for real config errors)
       bool configCheckResult = CheckWebRequestConfiguration();
       Print("CheckWebRequestConfiguration result = ", configCheckResult);
       Print("g_webRequestConfigured = ", g_webRequestConfigured);
       
       // *** Try to refresh news data (will use cache as fallback if fails) ***
       Print("NEWS FILTER: Calling RefreshNewsData()...");
       RefreshNewsData();
       Print("NEWS FILTER: After RefreshNewsData - g_newsEventCount = ", g_newsEventCount);
       Print("g_usingCachedNews = ", g_usingCachedNews);
       Print("========== NEWS FILTER INIT COMPLETE ==========");
       
       // Log summary of loaded news
       int relevantCount = 0;
       for(int i = 0; i < g_newsEventCount; i++)
       {
          if(g_newsEvents[i].isRelevant)
             relevantCount++;
       }
       Print("NEWS FILTER: ", g_newsEventCount, " total events, ", relevantCount, " relevant to your filters");
       if(g_usingCachedNews)
          Print("NEWS FILTER: Using CACHED data (last successful load: ", TimeToString(g_lastGoodNewsTime), ")");
       
       // If no news loaded, show debug info
       if(g_newsEventCount == 0)
       {
          Print("NEWS FILTER WARNING: No news events loaded!");
          if(g_webRequestConfigured)
             Print("  -> WebRequest is configured, but no events parsed (check response format)");
          else
             Print("  -> WebRequest configuration error (4060 or 4024)");
       }
       
       // Only show setup alert if it's a REAL configuration error (not network error)
       if(!g_webRequestConfigured)
       {
          ShowWebRequestSetupAlert();
          g_lastWebRequestAlert = TimeCurrent();
       }
    }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // *** หยุด Timer ***
   EventKillTimer();
   
   // Remove Dashboard objects
   ObjectsDeleteAll(0, DashPrefix);
   
   // Remove all chart objects (current chart)
   ObjectsDeleteAll(0, ZZPrefix);
   ObjectsDeleteAll(0, CDCPrefix);
   ObjectsDeleteAll(0, TPPrefix);
   ObjectsDeleteAll(0, EMAPrefix);
   ObjectsDeleteAll(0, PAPrefix);  // Remove PA arrows and labels
   ObjectsDeleteAll(0, BBPrefix);  // Remove BB objects
   ObjectsDeleteAll(0, SMCPrefix); // Remove SMC Order Block objects
   
   // Release Bollinger Bands indicator handle
   if(BBHandle != INVALID_HANDLE)
   {
      // Remove indicator from chart before releasing handle
      ChartIndicatorDelete(0, 0, ChartIndicatorName(0, 0, ChartIndicatorsTotal(0, 0) - 1));
      IndicatorRelease(BBHandle);
      BBHandle = INVALID_HANDLE;
   }
   
   // Release ATR Grid indicator handles
   if(g_atrGridLossHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrGridLossHandle);
      g_atrGridLossHandle = INVALID_HANDLE;
   }
   if(g_atrGridProfitHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrGridProfitHandle);
      g_atrGridProfitHandle = INVALID_HANDLE;
   }
   
   // Clear SMC arrays
   ArrayFree(BullishOBs);
   ArrayFree(BearishOBs);
   BullishOBCount = 0;
   BearishOBCount = 0;
   
   // Remove ZigZag objects from the ZigZag timeframe chart (if opened)
   if(ZZTFChartId > 0)
   {
      ObjectsDeleteAll(ZZTFChartId, ZZPrefix);
      ChartClose(ZZTFChartId);
      ZZTFChartId = 0;
   }
   
   // ไม่ใช้ Comment แล้ว เพราะมี Dashboard แทน
   Print("EA Stopped - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function - เรียกทุก 1 วินาที                                  |
//| ใช้สำหรับอัพเดท Dashboard แม้ไม่มี tick (ตลาดไม่เคลื่อนไหว)           |
//+------------------------------------------------------------------+
void OnTimer()
{
   // อัพเดท Dashboard ทุก 1 วินาที
   UpdateDashboard();
   
   // อัพเดท Profit History (เรียกไม่บ่อย เพราะใช้ resources)
   static datetime lastHistoryUpdate = 0;
   if(TimeCurrent() - lastHistoryUpdate >= 30)  // ทุก 30 วินาที
   {
      UpdateProfitHistory();
      lastHistoryUpdate = TimeCurrent();
   }
   
   // *** NEWS FILTER - Re-check WebRequest configuration every hour ***
   if(InpEnableNewsFilter && !g_webRequestConfigured)
   {
      datetime now = TimeCurrent();
      // เช็คทุก 1 ชั่วโมง (3600 วินาที)
      if((now - g_lastWebRequestAlert) >= g_webRequestCheckInterval)
      {
         // ลองเช็คอีกครั้ง
         g_lastWebRequestCheck = now;
         if(!CheckWebRequestConfiguration())
         {
            // ยังไม่ได้ตั้งค่า - แจ้งเตือนอีกครั้ง
            ShowWebRequestSetupAlert();
            g_lastWebRequestAlert = now;
         }
      }
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| ==================== DASHBOARD FUNCTIONS ======================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Dashboard Panel on Chart                                    |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   if(!InpShowDashboard) return;
   
   int x = InpDashboardX;
   int y = InpDashboardY;
   int w = InpDashboardWidth;
   int rowH = 22;
   int labelW = 130;
   int valueW = 140;
   
   // ========== SYSTEM NAME HEADER (แทน Logo) ==========
   // กรอบสีส้มพร้อมชื่อระบบ Moneyx Smart System (ตาม Design)
   int headerH = 35;
   CreateDashLabel(DashPrefix + "TitleFrame", x, y, w, headerH, C'205,133,63'); // กรอบสีส้ม
   
   // สร้างข้อความและจัดให้อยู่กลาง
   string titleName = DashPrefix + "TitleText";
   ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, x + (w / 2));
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, y + 8);
   ObjectSetInteger(0, titleName, OBJPROP_ANCHOR, ANCHOR_UPPER);  // จัด Anchor ให้อยู่กลางบน
   ObjectSetString(0, titleName, OBJPROP_TEXT, "Moneyx Smart System");
   ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, titleName, OBJPROP_BACK, false);
   ObjectSetInteger(0, titleName, OBJPROP_ZORDER, 600);
   
   y += headerH + 3;
   
   // ========== DETAIL SECTION ==========
   // Header Row: System Status with Pause Button
   CreateDashLabel(DashPrefix + "HeaderBg", x, y, w, rowH + 2, InpDashHeaderColor);
   CreateDashText(DashPrefix + "HeaderLabel", x + 35, y + 3, "System Status", clrWhite, 10, true);
   
   // Status Text (Working/Paused)
   CreateDashText(DashPrefix + "StatusText", x + 150, y + 3, "Working", clrLime, 10, true);
   
   // Pause/Start Button
   CreateDashButton(DashPrefix + "BtnPause", x + w - 55, y + 2, 50, rowH - 2, "Pause", clrOrangeRed);
   
   y += rowH + 2;
   
   // Detail Section Sidebar Label (เพิ่มความสูงสำหรับ Accumulate Close และ News Filter)
   CreateDashLabel(DashPrefix + "DetailSide", x, y, 25, rowH * 14, InpDashHeaderColor);
   CreateDashText(DashPrefix + "DetailD", x + 7, y + 10, "D", clrWhite, 9, true);
   CreateDashText(DashPrefix + "DetailE", x + 7, y + 30, "E", clrWhite, 9, true);
   CreateDashText(DashPrefix + "DetailT", x + 7, y + 50, "T", clrWhite, 9, true);
   CreateDashText(DashPrefix + "DetailA", x + 7, y + 70, "A", clrWhite, 9, true);
   CreateDashText(DashPrefix + "DetailI", x + 7, y + 90, "I", clrWhite, 9, true);
   CreateDashText(DashPrefix + "DetailL", x + 7, y + 110, "L", clrWhite, 9, true);
   
   // Detail Rows
   int detailX = x + 25;
   int detailW = w - 25;
   string detailLabels[] = {"Balance", "Equity", "Margin", "Margin Level", "Floating P/L", 
                            "Current Trend", "Fix Scaling", "Position Buy P/L", "Position Sell P/L", 
                            "Current DD%", "Max DD%", "Accumulate Close", "News Filter"};
   
   for(int i = 0; i < ArraySize(detailLabels); i++)
   {
      color bgCol = (i % 2 == 0) ? InpDashDetailColor : C'50,60,70';
      CreateDashLabel(DashPrefix + "DetailRow" + IntegerToString(i), detailX, y, detailW, rowH, bgCol);
      CreateDashText(DashPrefix + "DetailLbl" + IntegerToString(i), detailX + 5, y + 3, detailLabels[i], clrWhite, 9, false);
      CreateDashText(DashPrefix + "DetailVal" + IntegerToString(i), detailX + labelW, y + 3, "-", clrLime, 9, false);
      y += rowH;
   }
   
   y += 5;
   
   // ========== HISTORY SECTION ==========
   CreateDashLabel(DashPrefix + "HistorySide", x, y, 25, rowH * 4, InpDashHistoryColor);
   CreateDashText(DashPrefix + "HistH", x + 7, y + 5, "H", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistI", x + 7, y + 20, "I", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistS", x + 7, y + 35, "S", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistT", x + 7, y + 50, "T", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistO", x + 7, y + 65, "O", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistR", x + 7, y + 80, "R", clrWhite, 9, true);
   CreateDashText(DashPrefix + "HistY", x + 7, y + 95, "Y", clrWhite, 9, true);
   
   int histX = x + 25;
   int histW = w - 25;
   string histLabels[] = {"Profit Daily", "Profit Weekly", "Profit Monthly", "All Time Profit"};
   
   for(int i = 0; i < ArraySize(histLabels); i++)
   {
      color bgCol = (i % 2 == 0) ? InpDashHistoryColor : C'30,90,50';
      CreateDashLabel(DashPrefix + "HistRow" + IntegerToString(i), histX, y, histW, rowH, bgCol);
      CreateDashText(DashPrefix + "HistLbl" + IntegerToString(i), histX + 5, y + 3, histLabels[i], clrWhite, 9, false);
      CreateDashText(DashPrefix + "HistVal" + IntegerToString(i), histX + labelW, y + 3, "0$", clrLime, 9, true);
      y += rowH;
   }
   
   y += 10;
   
   // ========== CONTROL BUTTONS ==========
   int btnW = (w - 10) / 2;
   int btnH = 30;
   
   // Close Buy / Close Sell
   CreateDashButton(DashPrefix + "BtnCloseBuy", x, y, btnW, btnH, "Close Buy", clrForestGreen);
   CreateDashButton(DashPrefix + "BtnCloseSell", x + btnW + 10, y, btnW, btnH, "Close Sell", clrOrangeRed);
   
   y += btnH + 5;
   
   // Close All
   CreateDashButton(DashPrefix + "BtnCloseAll", x, y, w, btnH, "Close All", clrDodgerBlue);
   
   // ========== CONFIRMATION DIALOG (Hidden by default) ==========
   int dialogY = InpDashboardY + InpLogoHeight + 100;
   CreateDashLabel(DashPrefix + "ConfirmBg", x + 20, dialogY, w - 40, 80, clrDarkSlateGray);
   CreateDashText(DashPrefix + "ConfirmText", x + 30, dialogY + 10, "Confirm Action?", clrWhite, 10, true);
   CreateDashButton(DashPrefix + "BtnConfirmYes", x + 30, dialogY + 40, 80, 30, "YES", clrGreen);
   CreateDashButton(DashPrefix + "BtnConfirmNo", x + 130, dialogY + 40, 80, 30, "NO", clrRed);
   
   // Hide confirmation dialog initially
   HideConfirmDialog();
   
   ChartRedraw();
   Print("Dashboard created successfully");
}

//+------------------------------------------------------------------+
//| Create Dashboard Label/Rectangle                                   |
//+------------------------------------------------------------------+
void CreateDashLabel(string name, int x, int y, int width, int height, color bgColor)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);      // ให้อยู่หน้ากว่า indicator panel
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 500);       // ต่ำกว่าปุ่ม (1000) เพื่อไม่บังคลิก
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Create Dashboard Text Label                                        |
//+------------------------------------------------------------------+
void CreateDashText(string name, int x, int y, string text, color textColor, int fontSize, bool bold)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 600);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Create Dashboard Button                                            |
//+------------------------------------------------------------------+
void CreateDashButton(string name, int x, int y, int width, int height, string text, color bgColor)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);   // ต้องเป็น true เพื่อให้กดได้ใน Tester
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);       // Z-order สูงมากเพื่อให้กดได้ใน Tester
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);      // ไม่ซ่อนใน object list
   ObjectSetInteger(0, name, OBJPROP_BACK, false);        // อยู่หน้าสุด ไม่ใช่ background
}

//+------------------------------------------------------------------+
//| Update Dashboard Values                                            |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginLevel = (margin > 0) ? (equity / margin * 100.0) : 0;
   double floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Calculate Position P/L
   double buyPL = 0, sellPL = 0;
   double buyLots = 0, sellLots = 0;
   int buyCount = 0, sellCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         double posProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         double posLots = PositionGetDouble(POSITION_VOLUME);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            buyPL += posProfit;
            buyLots += posLots;
            buyCount++;
         }
         else
         {
            sellPL += posProfit;
            sellLots += posLots;
            sellCount++;
         }
      }
   }
   
   // Calculate Drawdown
   if(equity > g_peakBalance) g_peakBalance = equity;
   double currentDD = (g_peakBalance > 0) ? ((g_peakBalance - equity) / g_peakBalance * 100.0) : 0;
   if(currentDD > g_maxDrawdownPercent) g_maxDrawdownPercent = currentDD;
   
   // Update History Profits
   UpdateProfitHistory();
   
   // Scale Factor for display
   double scaleFactor = GetScaleFactor();
   string scaleDisplay = InpUseAutoScale ? 
      (InpUseFixedScale ? DoubleToString(InpFixedScaleAccount, 0) + "$" : "Auto " + DoubleToString(scaleFactor, 2) + "x") 
      : "OFF";
   
   // Get Current Trend from CDC
   string trendDisplay = CDCTrend + " (" + EnumToString(InpCDCTimeframe) + ")";
   
   // Update Status - Priority: License Status > EA Pause Status
   string statusText = "Working";
   color statusColor = clrLime;
   
   // Check license status first (higher priority than pause status)
   if(g_licenseStatus == LICENSE_SUSPENDED)
   {
      statusText = "SUSPENDED";
      statusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_EXPIRED)
   {
      statusText = "EXPIRED";
      statusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_NOT_FOUND)
   {
      statusText = "INVALID";
      statusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_ERROR)
   {
      statusText = "ERROR";
      statusColor = clrOrangeRed;
   }
   else if(g_eaIsPaused)
   {
      statusText = "PAUSED";
      statusColor = clrOrangeRed;
   }
   // else: Working (default)
   
   ObjectSetString(0, DashPrefix + "StatusText", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, DashPrefix + "StatusText", OBJPROP_COLOR, statusColor);
   ObjectSetString(0, DashPrefix + "BtnPause", OBJPROP_TEXT, g_eaIsPaused ? "Start" : "Pause");
   ObjectSetInteger(0, DashPrefix + "BtnPause", OBJPROP_BGCOLOR, g_eaIsPaused ? clrGreen : clrOrangeRed);
   
   // Update Detail Values (เพิ่ม Accumulate Close)
   // คำนวณ Total P/L รวม (Floating + Accumulated Closed)
   double totalPLForAccumulate = floatingPL + g_accumulateClosedProfit;
   int currentPosCount = buyCount + sellCount;
   
   string detailValues[13];
   detailValues[0] = DoubleToString(balance, 2) + "$";
   detailValues[1] = DoubleToString(equity, 2) + "$";
   detailValues[2] = DoubleToString(margin, 2) + "$";
   detailValues[3] = DoubleToString(marginLevel, 0) + "%";
   detailValues[4] = (floatingPL >= 0 ? "+" : "") + DoubleToString(floatingPL, 2) + "$";
   detailValues[5] = trendDisplay;
   detailValues[6] = scaleDisplay;
   detailValues[7] = (buyPL >= 0 ? "+" : "") + DoubleToString(buyPL, 2) + "$ (" + DoubleToString(buyLots, 2) + "L," + IntegerToString(buyCount) + "ord)";
   detailValues[8] = (sellPL >= 0 ? "+" : "") + DoubleToString(sellPL, 2) + "$ (" + DoubleToString(sellLots, 2) + "L," + IntegerToString(sellCount) + "ord)";
   detailValues[9] = (floatingPL >= 0 ? "+" : "-") + DoubleToString(MathAbs(currentDD), 1) + "%";
   detailValues[10] = DoubleToString(g_maxDrawdownPercent, 1) + "%";
   // Accumulate Close: ใช้ Locked Target ถ้ามี order ค้าง, ไม่งั้นแสดง Current Scaled
   double displayAccumulateTarget = (g_lockedAccumulateTarget > 0) ? g_lockedAccumulateTarget : ApplyScaleDollar(InpAccumulateTarget);
   detailValues[11] = (totalPLForAccumulate >= 0 ? "+" : "") + DoubleToString(totalPLForAccumulate, 0) + "$ (Tg: " + DoubleToString(displayAccumulateTarget, 0) + "$)";
   // News Filter Status: 4 states
   // 1. "Disable" - when feature is off
   // 2. "WebRequest: NOT CONFIGURED!" - when WebRequest not set up (blinking red)
   // 3. "No Important news" - when enabled and no news affecting (simple green message)
   // 4. News title + Countdown - when paused due to news (shows remaining time until resume)
   string newsDisplayStatus;
   color newsStatusColor;
   
   if(!InpEnableNewsFilter)
   {
      newsDisplayStatus = "Disable";
      newsStatusColor = clrGray;
   }
   else if(!g_webRequestConfigured)
   {
      // WebRequest not configured - show warning with blinking effect
      static bool blinkState = false;
      blinkState = !blinkState;
      newsDisplayStatus = blinkState ? "⚠ WebRequest: NOT CONFIGURED!" : "⚠ Click OK on popup to see instructions";
      newsStatusColor = clrOrangeRed;
   }
   else if(g_isNewsPaused && StringLen(g_nextNewsTitle) > 0)
   {
      // Show the news title causing the pause + countdown timer
      // Countdown format: HH:MM:SS showing time until trading resumes
      string truncatedTitle = g_nextNewsTitle;
      if(StringLen(truncatedTitle) > 18)
         truncatedTitle = StringSubstr(truncatedTitle, 0, 15) + "...";
      
      // Calculate time remaining until pause ends
      string countdownStr = GetNewsCountdownString();
      newsDisplayStatus = truncatedTitle + " " + countdownStr;
      newsStatusColor = clrOrangeRed;
   }
   else if(g_newsEventCount == 0)
   {
      // No news loaded at all - show debug info
      static bool noNewsBlink = false;
      noNewsBlink = !noNewsBlink;
      newsDisplayStatus = noNewsBlink ? "⚠ 0 events (Check Experts tab)" : "⚠ Retry: Reload EA";
      newsStatusColor = clrYellow;
   }
   else
   {
      // Normal operation - no important news affecting trading
      newsDisplayStatus = "No Important news";
      newsStatusColor = clrLime;
   }
   detailValues[12] = newsDisplayStatus;
   
   color valueColors[13];
   valueColors[0] = clrWhite;
   valueColors[1] = clrWhite;
   valueColors[2] = clrWhite;
   valueColors[3] = clrWhite;
   valueColors[4] = (floatingPL >= 0) ? clrLime : clrOrangeRed;
   valueColors[5] = (CDCTrend == "BULLISH") ? clrLime : (CDCTrend == "BEARISH") ? clrOrangeRed : clrYellow;
   valueColors[6] = InpUseAutoScale ? clrAqua : clrGray;
   valueColors[7] = (buyPL >= 0) ? clrLime : clrOrangeRed;
   valueColors[8] = (sellPL >= 0) ? clrLime : clrOrangeRed;
   valueColors[9] = (currentDD <= 10) ? clrLime : (currentDD <= 20) ? clrYellow : clrOrangeRed;
   valueColors[10] = (g_maxDrawdownPercent <= 15) ? clrLime : (g_maxDrawdownPercent <= 30) ? clrYellow : clrOrangeRed;
   valueColors[11] = (totalPLForAccumulate >= displayAccumulateTarget * 0.8) ? clrLime : (totalPLForAccumulate >= 0) ? clrYellow : clrOrangeRed;
   // News Filter: use the color determined above
   valueColors[12] = newsStatusColor;
   
   for(int i = 0; i < 13; i++)
   {
      ObjectSetString(0, DashPrefix + "DetailVal" + IntegerToString(i), OBJPROP_TEXT, detailValues[i]);
      ObjectSetInteger(0, DashPrefix + "DetailVal" + IntegerToString(i), OBJPROP_COLOR, valueColors[i]);
   }
   
   // Update History Values
   string histValues[4];
   histValues[0] = (g_profitDaily >= 0 ? "+" : "") + DoubleToString(g_profitDaily, 2) + "$";
   histValues[1] = (g_profitWeekly >= 0 ? "+" : "") + DoubleToString(g_profitWeekly, 2) + "$";
   histValues[2] = (g_profitMonthly >= 0 ? "+" : "") + DoubleToString(g_profitMonthly, 2) + "$";
   histValues[3] = (g_profitAllTime >= 0 ? "+" : "") + DoubleToString(g_profitAllTime, 2) + "$";
   
   color histColors[4];
   histColors[0] = (g_profitDaily >= 0) ? clrLime : clrOrangeRed;
   histColors[1] = (g_profitWeekly >= 0) ? clrLime : clrOrangeRed;
   histColors[2] = (g_profitMonthly >= 0) ? clrLime : clrOrangeRed;
   histColors[3] = (g_profitAllTime >= 0) ? clrLime : clrOrangeRed;
   
   for(int i = 0; i < 4; i++)
   {
      ObjectSetString(0, DashPrefix + "HistVal" + IntegerToString(i), OBJPROP_TEXT, histValues[i]);
      ObjectSetInteger(0, DashPrefix + "HistVal" + IntegerToString(i), OBJPROP_COLOR, histColors[i]);
   }
}

//+------------------------------------------------------------------+
//| Update Profit History from Account History                         |
//+------------------------------------------------------------------+
void UpdateProfitHistory()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Calculate start times
   datetime todayStart = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime weekStart = todayStart - (dt.day_of_week * 86400);
   datetime monthStart = StringToTime(IntegerToString(dt.year) + "." + IntegerToString(dt.mon) + ".01");
   
   g_profitDaily = 0;
   g_profitWeekly = 0;
   g_profitMonthly = 0;
   g_profitAllTime = 0;
   
   // Select history for calculation
   if(!HistorySelect(0, now)) return;
   
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // Only count our EA's deals
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      // Only count profit-related entries (not deposits/withdrawals)
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + 
                      HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                      HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      
      g_profitAllTime += profit;
      
      if(dealTime >= monthStart) g_profitMonthly += profit;
      if(dealTime >= weekStart) g_profitWeekly += profit;
      if(dealTime >= todayStart) g_profitDaily += profit;
   }
}

//+------------------------------------------------------------------+
//| Show Confirmation Dialog                                           |
//+------------------------------------------------------------------+
void ShowConfirmDialog(string action, string message)
{
   g_showConfirmDialog = true;
   g_confirmAction = action;
   
   ObjectSetString(0, DashPrefix + "ConfirmText", OBJPROP_TEXT, message);
   
   ObjectSetInteger(0, DashPrefix + "ConfirmBg", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, DashPrefix + "ConfirmText", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, DashPrefix + "BtnConfirmYes", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, DashPrefix + "BtnConfirmNo", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Hide Confirmation Dialog                                           |
//+------------------------------------------------------------------+
void HideConfirmDialog()
{
   g_showConfirmDialog = false;
   g_confirmAction = "";
   
   ObjectSetInteger(0, DashPrefix + "ConfirmBg", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(0, DashPrefix + "ConfirmText", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(0, DashPrefix + "BtnConfirmYes", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(0, DashPrefix + "BtnConfirmNo", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   
   // Reset button states
   ObjectSetInteger(0, DashPrefix + "BtnConfirmYes", OBJPROP_STATE, false);
   ObjectSetInteger(0, DashPrefix + "BtnConfirmNo", OBJPROP_STATE, false);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Execute Confirmed Action                                           |
//+------------------------------------------------------------------+
void ExecuteConfirmedAction()
{
   if(g_confirmAction == "CLOSE_BUY")
   {
      CloseAllPositions(POSITION_TYPE_BUY);
      Print("All BUY positions closed by user request");
   }
   else if(g_confirmAction == "CLOSE_SELL")
   {
      CloseAllPositions(POSITION_TYPE_SELL);
      Print("All SELL positions closed by user request");
   }
   else if(g_confirmAction == "CLOSE_ALL")
   {
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      Print("All positions closed by user request");
   }
   
   HideConfirmDialog();
}

//+------------------------------------------------------------------+
//| Close All Positions of Specified Type                              |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE) != posType) continue;
         
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| ================== ACCUMULATE CLOSE SYSTEM ====================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Track and Accumulate Closed Profit                                 |
//| - เรียกทุก tick เพื่อ track กำไรจาก order ที่ปิดไป                   |
//| - Reset เมื่อไม่มี order ค้าง                                       |
//| - ทำงานได้ทั้งใน Working และ Pause mode                            |
//+------------------------------------------------------------------+
void TrackAccumulateProfit()
{
   if(!InpUseAccumulateClose) return;
   
   int currentPosCount = 0;
   double currentFloatingPL = 0.0;
   
   // นับจำนวน position และ floating P/L ปัจจุบัน
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         currentPosCount++;
         currentFloatingPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   
   // ถ้าไม่มี position แล้ว → Reset Accumulate และ Recalculate Target
   if(currentPosCount == 0)
   {
      if(g_accumulateClosedProfit != 0.0)
      {
         Print("ACCUMULATE CLOSE: Reset - No positions remaining. Last accumulated: ", 
               DoubleToString(g_accumulateClosedProfit, 2), "$");
      }
      g_accumulateClosedProfit = 0.0;
      g_lastKnownPositionCount = 0;
      g_lastKnownFloatingPL = 0.0;
      g_lockedAccumulateTarget = 0.0;  // Reset locked target → จะ recalculate ตอนมี order ใหม่
      return;
   }
   
   // ถ้าเป็น order แรก (จาก 0 → 1+) → ล็อค Scaled Target ไว้
   if(g_lastKnownPositionCount == 0 && currentPosCount > 0)
   {
      g_lockedAccumulateTarget = ApplyScaleDollar(InpAccumulateTarget);
      Print("ACCUMULATE CLOSE: Locked Target = ", DoubleToString(g_lockedAccumulateTarget, 2), 
            "$ (based on current balance scale)");
   }
   
   // ตรวจสอบว่ามี position ถูกปิดไปหรือไม่ (จำนวนลดลง)
   if(g_lastKnownPositionCount > 0 && currentPosCount < g_lastKnownPositionCount)
   {
      // มี position ถูกปิด → คำนวณกำไรที่ปิดไป
      // Profit ที่ปิด = (Floating เก่า) - (Floating ใหม่) + (Balance เปลี่ยน)
      // วิธีง่าย: ใช้ History ล่าสุด
      
      double closedProfit = GetRecentClosedProfit();
      g_accumulateClosedProfit += closedProfit;
      
      Print("ACCUMULATE CLOSE: Position closed. Profit: ", DoubleToString(closedProfit, 2), 
            "$ | Total Accumulated: ", DoubleToString(g_accumulateClosedProfit, 2), "$");
   }
   
   // Update tracking variables
   g_lastKnownPositionCount = currentPosCount;
   g_lastKnownFloatingPL = currentFloatingPL;
}

//+------------------------------------------------------------------+
//| Get Recent Closed Profit from History                              |
//| ดึงกำไรจาก order ที่เพิ่งปิดไปล่าสุด                                  |
//+------------------------------------------------------------------+
double GetRecentClosedProfit()
{
   double totalProfit = 0.0;
   datetime now = TimeCurrent();
   datetime startTime = now - 60;  // ดูย้อนหลัง 60 วินาที
   
   if(!HistorySelect(startTime, now)) return 0.0;
   
   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // เฉพาะ EA ของเรา
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      // เฉพาะ deal ที่เป็นการปิด position
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      
      totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + 
                     HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                     HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Check and Execute Accumulate Close                                 |
//| ตรวจสอบว่ากำไรสะสมถึงเป้าหมายหรือยัง ถ้าถึงให้ปิดทั้งหมด              |
//| ทำงานได้ทั้งใน Working และ Pause mode                              |
//+------------------------------------------------------------------+
bool CheckAccumulateClose()
{
   if(!InpUseAccumulateClose) return false;
   
   double currentFloatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // คำนวณ Total P/L = Floating + Accumulated Closed
   double totalPL = currentFloatingPL + g_accumulateClosedProfit;
   
   // ใช้ Locked Target (ล็อคไว้ตอนเริ่มมี order) หรือ Calculate ใหม่ถ้ายังไม่มี
   double scaledTarget = (g_lockedAccumulateTarget > 0) ? g_lockedAccumulateTarget : ApplyScaleDollar(InpAccumulateTarget);
   
   // ถ้าถึงเป้าหมาย → ปิดทั้งหมด
   if(totalPL >= scaledTarget)
   {
      Print("=== ACCUMULATE CLOSE TARGET REACHED ===");
      Print("Accumulated Closed: ", DoubleToString(g_accumulateClosedProfit, 2), "$");
      Print("Current Floating: ", DoubleToString(currentFloatingPL, 2), "$");
      Print("Total P/L: ", DoubleToString(totalPL, 2), "$ >= Locked Target: ", DoubleToString(scaledTarget, 2), "$");
      Print("Closing ALL positions...");
      
      // ปิด order ทั้งหมด
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      
      // Reset accumulate (จะถูก reset อีกครั้งใน TrackAccumulateProfit เมื่อ position = 0)
      Print("=== ACCUMULATE CLOSE COMPLETED ===");
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Handle Chart Events (Button Clicks)                                |
//| รองรับทั้ง Live Trading และ Backtest/Tester Mode                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // *** OBJECT CLICK EVENTS ***
   // ใช้งานได้ทั้ง Live และ Visual Backtest Mode
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle Dashboard Button Clicks
      if(sparam == DashPrefix + "BtnPause")
      {
         g_eaIsPaused = !g_eaIsPaused;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("EA ", g_eaIsPaused ? "PAUSED" : "RESUMED", " by user");
         UpdateDashboard();
         ChartRedraw(0);  // Force chart update in tester
      }
      else if(sparam == DashPrefix + "BtnCloseBuy")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_BUY", "Close all BUY orders?");
         ChartRedraw(0);
      }
      else if(sparam == DashPrefix + "BtnCloseSell")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_SELL", "Close all SELL orders?");
         ChartRedraw(0);
      }
      else if(sparam == DashPrefix + "BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_ALL", "Close ALL orders?");
         ChartRedraw(0);
      }
      else if(sparam == DashPrefix + "BtnConfirmYes")
      {
         ExecuteConfirmedAction();
         ChartRedraw(0);
      }
      else if(sparam == DashPrefix + "BtnConfirmNo")
      {
         HideConfirmDialog();
         ChartRedraw(0);
      }
   }
}

//+------------------------------------------------------------------+
//| ================== AUTO BALANCE SCALING ========================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Scale Factor based on Account Balance vs Base Account          |
//| Scale Factor = Account Balance / Base Account Size                 |
//| Example: Base=1000$, Balance=2000$ → Factor=2.0                   |
//|                                                                    |
//| Fixed Scale Mode:                                                  |
//| - ถ้าเปิด InpUseFixedScale จะใช้ InpFixedScaleAccount แทน Balance  |
//| - ทำให้ขนาดออเดอร์ถูกล็อคไว้ที่ค่าที่กำหนด ไม่เปลี่ยนตาม Balance     |
//| - ตัวอย่าง: Base=1000$, FixedScale=500$ → Factor=0.5 (ล็อคไว้)     |
//+------------------------------------------------------------------+
double GetScaleFactor()
{
   if(!InpUseAutoScale || InpBaseAccount <= 0)
      return 1.0;
   
   double accountSize;
   
   // Fixed Scale Mode: ใช้ค่าที่กำหนดแทน Balance จริง
   if(InpUseFixedScale && InpFixedScaleAccount > 0)
   {
      accountSize = InpFixedScaleAccount;
   }
   else
   {
      // Auto Scale Mode: ใช้ Balance จริงของ Account
      accountSize = AccountInfoDouble(ACCOUNT_BALANCE);
      if(accountSize <= 0)
         return 1.0;
   }
   
   double factor = accountSize / InpBaseAccount;
   
   // Minimum factor = 0.1 (to prevent extremely small lots)
   // Maximum factor = 100 (to prevent extremely large lots)
   factor = MathMax(0.1, MathMin(100.0, factor));
   
   return NormalizeDouble(factor, 2);
}

//+------------------------------------------------------------------+
//| Apply Auto Scale to Lot Size                                       |
//| Returns scaled lot size based on account balance                   |
//+------------------------------------------------------------------+
double ApplyScaleLot(double baseLot)
{
   double factor = GetScaleFactor();
   double scaledLot = baseLot * factor;
   
   // Normalize to broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   scaledLot = MathMax(minLot, MathMin(maxLot, scaledLot));
   scaledLot = MathFloor(scaledLot / lotStep) * lotStep;
   
   return NormalizeDouble(scaledLot, 2);
}

//+------------------------------------------------------------------+
//| Apply Auto Scale to Dollar Amount (TP/SL)                          |
//| Returns scaled dollar amount based on account balance              |
//+------------------------------------------------------------------+
double ApplyScaleDollar(double baseDollar)
{
   double factor = GetScaleFactor();
   return NormalizeDouble(baseDollar * factor, 2);
}

// หมายเหตุ: TP/SL Points ไม่ต้องปรับ Scale เพราะเป็นจำนวน points คงที่
// การปิดกำไร/ขาดทุนมี 2 แบบ: 1) ไปชนเส้น TP/SL Points 2) ถึง $ ที่กำหนด
// ดังนั้นปรับเฉพาะค่า $ เท่านั้นเพื่อไม่ให้คลาดเคลื่อน

//+------------------------------------------------------------------+
//| Parse semicolon-separated string to array                          |
//+------------------------------------------------------------------+
void ParseStringToDoubleArray(string inputStr, double &arr[])
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   ArrayResize(arr, count);
   for(int i = 0; i < count; i++)
   {
      arr[i] = StringToDouble(parts[i]);
   }
}

void ParseStringToIntArray(string inputStr, int &arr[])
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   ArrayResize(arr, count);
   for(int i = 0; i < count; i++)
   {
      arr[i] = (int)StringToInteger(parts[i]);
   }
}

//+------------------------------------------------------------------+
//| Get Lot Size for Grid based on level                               |
//| *** Grid Loss และ Grid Profit แยกนับ level กันอิสระ ***            |
//|                                                                    |
//| Initial Order = level 0 = InpInitialLot (เป็นตัวกลาง)               |
//|                                                                    |
//| Grid Loss Side:                                                    |
//|   - gridLevel = 1 = First Grid Loss = InitialLot + AddLotLoss      |
//|   - gridLevel = 2 = Second Grid Loss = InitialLot + AddLotLoss*2   |
//|                                                                    |
//| Grid Profit Side:                                                  |
//|   - gridLevel = 1 = First Grid Profit = InitialLot + AddLotProfit  |
//|   - gridLevel = 2 = Second Grid Profit = InitialLot + AddLotProfit*2|
//|                                                                    |
//| ตัวอย่าง: InitialLot=1, AddLotLoss=1, AddLotProfit=0.5            |
//|   Initial Order: 1.0 lot                                           |
//|   Grid Profit #1: 1.0 + 0.5*1 = 1.5 lot                            |
//|   Grid Loss #1: 1.0 + 1.0*1 = 2.0 lot                              |
//|   Grid Profit #2: 1.0 + 0.5*2 = 2.0 lot                            |
//|   Grid Loss #2: 1.0 + 1.0*2 = 3.0 lot                              |
//+------------------------------------------------------------------+
double GetGridLotSize(bool isLossSide, int gridLevel)
{
   ENUM_GRID_LOT_MODE lotMode = isLossSide ? InpGridLossLotMode : InpGridProfitLotMode;
   double baseLot = InpInitialLot;
   double calculatedLot = baseLot;
   
   // gridLevel = 0 means Initial Order (uses InitialLot only)
   if(gridLevel == 0)
   {
      calculatedLot = baseLot;
   }
   else if(lotMode == GRID_LOT_CUSTOM)
   {
      // Custom Lot Mode: Use the lot array from string
      // Index 0 = First Grid order (not Initial Order)
      double lots[];
      if(isLossSide)
         ParseStringToDoubleArray(InpGridLossCustomLot, lots);
      else
         ParseStringToDoubleArray(InpGridProfitCustomLot, lots);
      
      int idx = gridLevel - 1;  // Adjust for 0-based array
      if(idx < ArraySize(lots))
         calculatedLot = lots[idx];
      else if(ArraySize(lots) > 0)
         calculatedLot = lots[ArraySize(lots) - 1];  // Use last value for levels beyond array
   }
   else  // GRID_LOT_ADD
   {
      // Add Lot Mode: InitialLot + (AddLot * gridLevel)
      // Grid Loss และ Grid Profit ใช้ AddLot ของตัวเอง แยกกันอิสระ
      double addLot = isLossSide ? InpGridLossAddLot : InpGridProfitAddLot;
      
      // gridLevel = 1 = First Grid = InitialLot + AddLot*1
      // gridLevel = 2 = Second Grid = InitialLot + AddLot*2
      calculatedLot = baseLot + (addLot * gridLevel);
   }
   
   // Apply Auto Balance Scaling
   calculatedLot = ApplyScaleLot(calculatedLot);
   
   return calculatedLot;
}

//+------------------------------------------------------------------+
//| Get ATR Value for Grid                                             |
//+------------------------------------------------------------------+
double GetATRGridValue(bool isLossSide)
{
   int handle = isLossSide ? g_atrGridLossHandle : g_atrGridProfitHandle;
   
   if(handle == INVALID_HANDLE)
      return 0;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(handle, 0, 0, 1, atrBuffer) < 1)
   {
      Print("[ATR Grid] Warning: Failed to get ATR value for ", (isLossSide ? "Loss" : "Profit"), " side");
      return 0;
   }
   
   // Store last ATR value
   if(isLossSide)
      g_lastATRGridLossValue = atrBuffer[0];
   else
      g_lastATRGridProfitValue = atrBuffer[0];
   
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Get Grid Distance for level                                        |
//+------------------------------------------------------------------+
int GetGridDistance(bool isLossSide, int gridLevel)
{
   ENUM_GRID_GAP_TYPE gapType = isLossSide ? InpGridLossGapType : InpGridProfitGapType;
   int fixedPoints = isLossSide ? InpGridLossPoints : InpGridProfitPoints;
   string customDist = isLossSide ? InpGridLossCustomDist : InpGridProfitCustomDist;
   
   // Fixed Points
   if(gapType == GAP_FIXED_POINTS)
      return fixedPoints;
   
   // ATR-Based Dynamic
   if(gapType == GAP_ATR_BASED)
   {
      double atrValue = GetATRGridValue(isLossSide);
      if(atrValue == 0)
         return fixedPoints;  // Fallback to fixed if ATR fails
      
      double multiplier = isLossSide ? InpGridLossATRMultiplier : InpGridProfitATRMultiplier;
      double dynamicStep = atrValue * multiplier;
      
      // Convert to points
      int dynamicPoints = (int)(dynamicStep / _Point);
      
      // Log for debugging (only first time or when changes)
      static int lastLoggedLoss = 0;
      static int lastLoggedProfit = 0;
      
      if(isLossSide && dynamicPoints != lastLoggedLoss)
      {
         Print("[ATR Grid Loss] ATR: ", DoubleToString(atrValue, 5), 
               " x ", DoubleToString(multiplier, 1), 
               " = ", dynamicPoints, " points (", DoubleToString(dynamicStep * 10000, 1), " pips)");
         lastLoggedLoss = dynamicPoints;
      }
      else if(!isLossSide && dynamicPoints != lastLoggedProfit)
      {
         Print("[ATR Grid Profit] ATR: ", DoubleToString(atrValue, 5), 
               " x ", DoubleToString(multiplier, 1), 
               " = ", dynamicPoints, " points (", DoubleToString(dynamicStep * 10000, 1), " pips)");
         lastLoggedProfit = dynamicPoints;
      }
      
      return dynamicPoints;
   }
   
   // Custom Distance
   int distances[];
   ParseStringToIntArray(customDist, distances);
   
   if(gridLevel < ArraySize(distances))
      return distances[gridLevel];
   else if(ArraySize(distances) > 0)
      return distances[ArraySize(distances) - 1];
   
   return fixedPoints;
}

//+------------------------------------------------------------------+
//| ZigZag++ Algorithm (Based on DevLucem Pine Script)                |
//+------------------------------------------------------------------+
void CalculateZigZagPP()
{
   // Clear previous points
   ArrayResize(ZZPoints, 0);
   ZZPointCount = 0;
   
   // Remove old objects
   ObjectsDeleteAll(0, ZZPrefix);
   
   int barsToAnalyze = 200;
   
   // Buffers for ZigZag calculation
   double zigzagVal[];
   int zigzagDir[];      // 1 = high point, -1 = low point
   datetime zigzagTime[];
   int zigzagBar[];
   
   ArrayResize(zigzagVal, barsToAnalyze);
   ArrayResize(zigzagDir, barsToAnalyze);
   ArrayResize(zigzagTime, barsToAnalyze);
   ArrayResize(zigzagBar, barsToAnalyze);
   
   ArrayInitialize(zigzagVal, 0);
   ArrayInitialize(zigzagDir, 0);
   
   // Find swing highs and lows using Depth, Deviation, Backstep
   double lastHigh = 0, lastLow = DBL_MAX;
   int lastHighBar = 0, lastLowBar = 0;
   int direction = 0;  // 0 = unknown, 1 = up, -1 = down
   
   double deviationPips = InpDeviation * _Point * 10;
   
   // First pass: Find potential swing points
   double swingHigh[], swingLow[];
   int swingHighBar[], swingLowBar[];
   ArrayResize(swingHigh, 0);
   ArrayResize(swingLow, 0);
   ArrayResize(swingHighBar, 0);
   ArrayResize(swingLowBar, 0);
   
   for(int i = InpDepth; i < barsToAnalyze - InpDepth; i++)
   {
      // Check for swing high
      double high = iHigh(_Symbol, InpZigZagTimeframe, i);
      bool isSwingHigh = true;
      for(int j = 1; j <= InpDepth; j++)
      {
         if(iHigh(_Symbol, InpZigZagTimeframe, i - j) >= high || 
            iHigh(_Symbol, InpZigZagTimeframe, i + j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         int size = ArraySize(swingHigh);
         ArrayResize(swingHigh, size + 1);
         ArrayResize(swingHighBar, size + 1);
         swingHigh[size] = high;
         swingHighBar[size] = i;
      }
      
      // Check for swing low
      double low = iLow(_Symbol, InpZigZagTimeframe, i);
      bool isSwingLow = true;
      for(int j = 1; j <= InpDepth; j++)
      {
         if(iLow(_Symbol, InpZigZagTimeframe, i - j) <= low || 
            iLow(_Symbol, InpZigZagTimeframe, i + j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         int size = ArraySize(swingLow);
         ArrayResize(swingLow, size + 1);
         ArrayResize(swingLowBar, size + 1);
         swingLow[size] = low;
         swingLowBar[size] = i;
      }
   }
   
   // Build ZigZag from swing points (alternating high-low-high-low)
   double zzPrices[];
   int zzBars[];
   int zzDirs[];
   ArrayResize(zzPrices, 0);
   ArrayResize(zzBars, 0);
   ArrayResize(zzDirs, 0);
   
   int hiIdx = 0, loIdx = 0;
   int lastDir = 0;
   
   // Merge swing highs and lows in time order (newest first)
   while(hiIdx < ArraySize(swingHighBar) || loIdx < ArraySize(swingLowBar))
   {
      bool useHigh = false;
      
      if(hiIdx >= ArraySize(swingHighBar))
         useHigh = false;
      else if(loIdx >= ArraySize(swingLowBar))
         useHigh = true;
      else
         useHigh = (swingHighBar[hiIdx] < swingLowBar[loIdx]);
      
      if(useHigh)
      {
         if(lastDir != 1)  // Can add high after low or at start
         {
            int size = ArraySize(zzPrices);
            ArrayResize(zzPrices, size + 1);
            ArrayResize(zzBars, size + 1);
            ArrayResize(zzDirs, size + 1);
            zzPrices[size] = swingHigh[hiIdx];
            zzBars[size] = swingHighBar[hiIdx];
            zzDirs[size] = 1;
            lastDir = 1;
         }
         else if(ArraySize(zzPrices) > 0 && swingHigh[hiIdx] > zzPrices[ArraySize(zzPrices)-1])
         {
            // Replace last high with higher high
            zzPrices[ArraySize(zzPrices)-1] = swingHigh[hiIdx];
            zzBars[ArraySize(zzBars)-1] = swingHighBar[hiIdx];
         }
         hiIdx++;
      }
      else
      {
         if(lastDir != -1)  // Can add low after high or at start
         {
            int size = ArraySize(zzPrices);
            ArrayResize(zzPrices, size + 1);
            ArrayResize(zzBars, size + 1);
            ArrayResize(zzDirs, size + 1);
            zzPrices[size] = swingLow[loIdx];
            zzBars[size] = swingLowBar[loIdx];
            zzDirs[size] = -1;
            lastDir = -1;
         }
         else if(ArraySize(zzPrices) > 0 && swingLow[loIdx] < zzPrices[ArraySize(zzPrices)-1])
         {
            // Replace last low with lower low
            zzPrices[ArraySize(zzPrices)-1] = swingLow[loIdx];
            zzBars[ArraySize(zzBars)-1] = swingLowBar[loIdx];
         }
         loIdx++;
      }
      
      if(ArraySize(zzPrices) >= 20) break;  // Limit points
   }
   
   // Now label the points as HH, HL, LH, LL
   double lastHighPoint = 0;
   double lastLowPoint = DBL_MAX;
   
   // Process from oldest to newest for proper labeling
   for(int i = ArraySize(zzPrices) - 1; i >= 0; i--)
   {
      ZigZagPoint zp;
      zp.price = zzPrices[i];
      zp.barIndex = zzBars[i];
      zp.time = iTime(_Symbol, InpZigZagTimeframe, zzBars[i]);
      zp.direction = zzDirs[i];
      
      if(zzDirs[i] == 1)  // High point
      {
         if(lastHighPoint > 0)
         {
            if(zzPrices[i] > lastHighPoint)
               zp.label = "HH";
            else
               zp.label = "LH";
         }
         else
            zp.label = "HH";  // First high
            
         lastHighPoint = zzPrices[i];
      }
      else  // Low point
      {
         if(lastLowPoint < DBL_MAX)
         {
            if(zzPrices[i] < lastLowPoint)
               zp.label = "LL";
            else
               zp.label = "HL";
         }
         else
            zp.label = "LL";  // First low
            
         lastLowPoint = zzPrices[i];
      }
      
      int size = ArraySize(ZZPoints);
      ArrayResize(ZZPoints, size + 1);
      ZZPoints[size] = zp;
      ZZPointCount++;
   }
   
   // Reverse to have newest first
   ZigZagPoint tempPoints[];
   ArrayResize(tempPoints, ZZPointCount);
   for(int i = 0; i < ZZPointCount; i++)
      tempPoints[i] = ZZPoints[ZZPointCount - 1 - i];
   
   ArrayResize(ZZPoints, ZZPointCount);
   for(int i = 0; i < ZZPointCount; i++)
      ZZPoints[i] = tempPoints[i];
   
   // Draw ZigZag lines and labels
   if(InpShowLines || InpShowLabels)
   {
      DrawZigZagOnChart();
   }
   
   // Set last label for trading signal
   if(ZZPointCount > 0)
   {
      LastZZLabel = ZZPoints[0].label;
      CurrentDirection = ZZPoints[0].direction;
   }
}

//+------------------------------------------------------------------+
//| Convert ZigZag Timeframe time to Chart Timeframe time             |
//+------------------------------------------------------------------+
datetime ConvertToChartTime(datetime zzTime)
{
   // If using current timeframe, no conversion needed
   if(InpZigZagTimeframe == PERIOD_CURRENT || InpZigZagTimeframe == Period())
      return zzTime;
   
   // Find the bar index on current chart that corresponds to this time
   int chartBar = iBarShift(_Symbol, PERIOD_CURRENT, zzTime, false);
   if(chartBar < 0) chartBar = 0;
   
   // Return the time of that bar on the current chart
   return iTime(_Symbol, PERIOD_CURRENT, chartBar);
}

//+------------------------------------------------------------------+
//| Get price at ZigZag point mapped to Chart Timeframe               |
//+------------------------------------------------------------------+
double GetChartPrice(ZigZagPoint &zp)
{
   // If using current timeframe, use original price
   if(InpZigZagTimeframe == PERIOD_CURRENT || InpZigZagTimeframe == Period())
      return zp.price;
   
   // Find the bar on current chart
   int chartBar = iBarShift(_Symbol, PERIOD_CURRENT, zp.time, false);
   if(chartBar < 0) chartBar = 0;
   
   // For high points, use the high of that bar range
   // For low points, use the low of that bar range
   if(zp.direction == 1)  // High point
      return iHigh(_Symbol, PERIOD_CURRENT, chartBar);
   else  // Low point
      return iLow(_Symbol, PERIOD_CURRENT, chartBar);
}

//+------------------------------------------------------------------+
//| Draw ZigZag++ Lines and Labels on Chart                           |
//+------------------------------------------------------------------+
void DrawZigZagOnChart()
{
   // Draw on BOTH current chart AND ZigZag timeframe for visibility
   bool drawBothTimeframes = (InpZigZagTimeframe != PERIOD_CURRENT && InpZigZagTimeframe != Period());
   
   for(int i = 0; i < ZZPointCount - 1; i++)
   {
      ZigZagPoint p1 = ZZPoints[i];
      ZigZagPoint p2 = ZZPoints[i + 1];
      
      // Convert times to chart timeframe for drawing on current chart
      datetime p1ChartTime = ConvertToChartTime(p1.time);
      datetime p2ChartTime = ConvertToChartTime(p2.time);
      
      // === Draw on CURRENT CHART (converted times) ===
      if(InpShowLines)
      {
         string lineName = ZZPrefix + "Line_" + IntegerToString(i);
         color lineColor = (p1.direction == 1) ? InpBearColor : InpBullColor;
         
         ObjectCreate(0, lineName, OBJ_TREND, 0, p2ChartTime, p2.price, p1ChartTime, p1.price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      }
      
      if(InpShowLabels)
      {
         string labelName = ZZPrefix + "Label_" + IntegerToString(i);
         color labelColor = (p1.label == "LL" || p1.label == "HL") ? InpBullColor : InpBearColor;
         ENUM_ANCHOR_POINT anchor = (p1.direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
         
         ObjectCreate(0, labelName, OBJ_TEXT, 0, p1ChartTime, p1.price);
         ObjectSetString(0, labelName, OBJPROP_TEXT, p1.label);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      }
      
      // === Draw on ZIGZAG TIMEFRAME (original times) - for viewing in that TF ===
      // NOTE: Objects only appear on the chart they are created on.
      // We therefore create them on a dedicated chart for InpZigZagTimeframe.
      if(drawBothTimeframes && ZZTFChartId > 0)
      {
         if(InpShowLines)
         {
            string lineName = ZZPrefix + "TF_Line_" + IntegerToString(i);
            color lineColor = (p1.direction == 1) ? InpBearColor : InpBullColor;
            
            ObjectCreate(ZZTFChartId, lineName, OBJ_TREND, 0, p2.time, p2.price, p1.time, p1.price);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_BACK, false);
         }
         
         if(InpShowLabels)
         {
            string labelName = ZZPrefix + "TF_Label_" + IntegerToString(i);
            color labelColor = (p1.label == "LL" || p1.label == "HL") ? InpBullColor : InpBearColor;
            ENUM_ANCHOR_POINT anchor = (p1.direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
            
            ObjectCreate(ZZTFChartId, labelName, OBJ_TEXT, 0, p1.time, p1.price);
            ObjectSetString(ZZTFChartId, labelName, OBJPROP_TEXT, p1.label);
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_COLOR, labelColor);
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(ZZTFChartId, labelName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_ANCHOR, anchor);
         }
      }
   }
   
   // Draw label for last point
   if(InpShowLabels && ZZPointCount > 0)
   {
      int last = ZZPointCount - 1;
      datetime lastChartTime = ConvertToChartTime(ZZPoints[last].time);
      
      // Current chart
      string labelName = ZZPrefix + "Label_" + IntegerToString(last);
      color labelColor = (ZZPoints[last].label == "LL" || ZZPoints[last].label == "HL") ? 
                          InpBullColor : InpBearColor;
      ENUM_ANCHOR_POINT anchor = (ZZPoints[last].direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, lastChartTime, ZZPoints[last].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, ZZPoints[last].label);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      
      // ZigZag Timeframe
      if(drawBothTimeframes && ZZTFChartId > 0)
      {
         string labelNameTF = ZZPrefix + "TF_Label_" + IntegerToString(last);
         ObjectCreate(ZZTFChartId, labelNameTF, OBJ_TEXT, 0, ZZPoints[last].time, ZZPoints[last].price);
         ObjectSetString(ZZTFChartId, labelNameTF, OBJPROP_TEXT, ZZPoints[last].label);
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_FONTSIZE, 10);
         ObjectSetString(ZZTFChartId, labelNameTF, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_ANCHOR, anchor);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate CDC Action Zone Values                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Calculate CDC Action Zone Values                                   |
//+------------------------------------------------------------------+
void CalculateCDC()
{
   // Always calculate CDC values and draw lines for trend visualization
   // The InpUseCDCFilter only controls whether CDC gates trade execution
   
   double closeArr[], highArr[], lowArr[], openArr[];
   datetime timeArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(timeArr, true);
   
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;
   
   if(CopyClose(_Symbol, InpCDCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyHigh(_Symbol, InpCDCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpCDCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpCDCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   if(CopyTime(_Symbol, InpCDCTimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   double ohlc4[];
   ArrayResize(ohlc4, barsNeeded);
   for(int i = 0; i < barsNeeded; i++)
   {
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   }
   
   double ap[];
   ArrayResize(ap, barsNeeded);
   CalculateEMA(ohlc4, ap, 2, barsNeeded);
   
   double fast[];
   ArrayResize(fast, barsNeeded);
   CalculateEMA(ap, fast, InpCDCFastPeriod, barsNeeded);
   
   double slow[];
   ArrayResize(slow, barsNeeded);
   CalculateEMA(ap, slow, InpCDCSlowPeriod, barsNeeded);
   
   CDCAP = ap[0];
   CDCFast = fast[0];
   CDCSlow = slow[0];
   
   // CDC Trend Detection: Based on EMA CROSSOVER
   double fastPrev = fast[1];
   double slowPrev = slow[1];
   
   bool crossUp = (fastPrev <= slowPrev && CDCFast > CDCSlow);
   bool crossDown = (fastPrev >= slowPrev && CDCFast < CDCSlow);
   
   if(crossUp || CDCFast > CDCSlow)
   {
      CDCTrend = "BULLISH";
      CDCZoneColor = clrLime;
   }
   else if(crossDown || CDCFast < CDCSlow)
   {
      CDCTrend = "BEARISH";
      CDCZoneColor = clrRed;
   }
   
   // If CDC Filter is disabled, set trend to neutral for trade gating only
   // But still show visual on chart
   if(!InpUseCDCFilter)
   {
      // Keep CDCTrend calculated but it won't gate trades
      // Trade filter check will skip CDC when InpUseCDCFilter = false
   }
   
   // Always draw CDC lines when InpShowCDCLines is enabled
   if(InpShowCDCLines)
   {
      DrawCDCOnChart(fast, slow, timeArr, barsNeeded);
   }
}

//+------------------------------------------------------------------+
//| Calculate EMA Array                                                |
//+------------------------------------------------------------------+
void CalculateEMA(double &src[], double &result[], int period, int size)
{
   if(size < period) return;
   
   double multiplier = 2.0 / (period + 1);
   
   double sum = 0;
   for(int i = size - period; i < size; i++)
   {
      sum += src[i];
   }
   result[size - 1] = sum / period;
   
   for(int i = size - 2; i >= 0; i--)
   {
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
   }
}

//+------------------------------------------------------------------+
//| Draw CDC Lines on Chart                                            |
//+------------------------------------------------------------------+
void DrawCDCOnChart(double &fast[], double &slow[], datetime &time[], int size)
{
   ObjectsDeleteAll(0, CDCPrefix);
   
   int maxBars = MathMin(100, size - 1);
   
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = CDCPrefix + "Fast_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, fast[i + 1], t2, fast[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = CDCPrefix + "Slow_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, slow[i + 1], t2, slow[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   
   // ไม่สร้าง CDC Status Label แยกแล้ว เพราะมี Dashboard แสดงข้อมูล Current Trend อยู่แล้ว
   // ป้องกันไม่ให้ข้อความบัง Dashboard และ Logo
}

//+------------------------------------------------------------------+
//| Calculate EMA Channel Values                                       |
//+------------------------------------------------------------------+
void CalculateEMAChannel()
{
   if(InpSignalStrategy != STRATEGY_EMA_CHANNEL)
      return;
   
   double highArr[], lowArr[], closeArr[];
   datetime timeArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(timeArr, true);
   
   int barsNeeded = MathMax(InpEMAHighPeriod, InpEMALowPeriod) * 3 + 50;
   
   if(CopyHigh(_Symbol, InpEMATimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpEMATimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyClose(_Symbol, InpEMATimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyTime(_Symbol, InpEMATimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   // Calculate EMA of High prices
   double emaHighArr[];
   ArrayResize(emaHighArr, barsNeeded);
   CalculateEMA(highArr, emaHighArr, InpEMAHighPeriod, barsNeeded);
   
   // Calculate EMA of Low prices
   double emaLowArr[];
   ArrayResize(emaLowArr, barsNeeded);
   CalculateEMA(lowArr, emaLowArr, InpEMALowPeriod, barsNeeded);
   
   // Determine signal bar index based on setting
   int signalBar = (InpEMASignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   int prevBar = signalBar + 1;
   
   EMAHigh = emaHighArr[signalBar];
   EMALow = emaLowArr[signalBar];
   
   double signalClose = closeArr[signalBar];
   double prevClose = closeArr[prevBar];
   double prevEMAHigh = emaHighArr[prevBar];
   double prevEMALow = emaLowArr[prevBar];
   
   // Check for EMA Channel crossover
   // BUY Signal: Price is NOW above both EMA lines AND was previously NOT above both (inside or below channel)
   bool nowAboveBoth = (signalClose > EMAHigh && signalClose > EMALow);
   bool prevNotAboveBoth = (prevClose <= prevEMAHigh || prevClose <= prevEMALow);
   
   // SELL Signal: Price is NOW below both EMA lines AND was previously NOT below both (inside or above channel)
   bool nowBelowBoth = (signalClose < EMAHigh && signalClose < EMALow);
   bool prevNotBelowBoth = (prevClose >= prevEMALow || prevClose >= prevEMAHigh);
   
   EMASignal = "NONE";
   
   if(nowAboveBoth && prevNotAboveBoth)
   {
      EMASignal = "BUY";
      Print("EMA Channel: BUY Signal - Price crossed ABOVE channel");
      Print("  Signal Close: ", signalClose, " > EMA High: ", EMAHigh, " & EMA Low: ", EMALow);
      Print("  Prev Close: ", prevClose, " | Prev EMA High: ", prevEMAHigh, " | Prev EMA Low: ", prevEMALow);
   }
   else if(nowBelowBoth && prevNotBelowBoth)
   {
      EMASignal = "SELL";
      Print("EMA Channel: SELL Signal - Price crossed BELOW channel");
      Print("  Signal Close: ", signalClose, " < EMA Low: ", EMALow, " & EMA High: ", EMAHigh);
      Print("  Prev Close: ", prevClose, " | Prev EMA High: ", prevEMAHigh, " | Prev EMA Low: ", prevEMALow);
   }
   
   // Draw EMA lines on chart
   if(InpShowEMALines)
   {
      DrawEMAChannelOnChart(emaHighArr, emaLowArr, timeArr, barsNeeded);
   }
}

//+------------------------------------------------------------------+
//| Draw EMA Channel Lines on Chart                                    |
//+------------------------------------------------------------------+
void DrawEMAChannelOnChart(double &emaHigh[], double &emaLow[], datetime &time[], int size)
{
   ObjectsDeleteAll(0, EMAPrefix);
   
   // Extended to show full chart - use 500 bars for maximum visibility
   int maxBars = MathMin(500, size - 1);
   
   // Draw EMA High line with smooth style
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = EMAPrefix + "High_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, emaHigh[i + 1], t2, emaHigh[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpEMAHighColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);  // Smooth solid line
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);  // Draw in background for smoother appearance
   }
   
   // Draw EMA Low line with smooth style
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = EMAPrefix + "Low_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, emaLow[i + 1], t2, emaLow[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpEMALowColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);  // Smooth solid line
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);  // Draw in background for smoother appearance
   }
   
   // Draw status label ONLY if Dashboard is disabled (v5.1 fix: prevent overlap)
   if(!InpShowDashboard)
   {
      string labelName = EMAPrefix + "Status_Label";
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 70);
      
      string signalBarText = (InpEMASignalBar == EMA_CURRENT_BAR) ? "Current" : "LastClosed";
      string statusText = "EMA Channel (" + EnumToString(InpEMATimeframe) + ") [" + signalBarText + "]";
      statusText += " | H: " + DoubleToString(EMAHigh, _Digits) + " L: " + DoubleToString(EMALow, _Digits);
      
      ObjectSetString(0, labelName, OBJPROP_TEXT, statusText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   }
}


//+------------------------------------------------------------------+
//| ================== PRICE ACTION DETECTION ====================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if candle is Bullish                                         |
//+------------------------------------------------------------------+
bool IsBullishCandle(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return close > open;
}

//+------------------------------------------------------------------+
//| Check if candle is Bearish                                         |
//+------------------------------------------------------------------+
bool IsBearishCandle(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return close < open;
}

//+------------------------------------------------------------------+
//| Get candle body size                                               |
//+------------------------------------------------------------------+
double GetCandleBody(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return MathAbs(close - open);
}

//+------------------------------------------------------------------+
//| Get candle range (high - low)                                      |
//+------------------------------------------------------------------+
double GetCandleRange(int shift)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double low = iLow(_Symbol, PERIOD_CURRENT, shift);
   return high - low;
}

//+------------------------------------------------------------------+
//| Get upper tail size                                                |
//+------------------------------------------------------------------+
double GetUpperTail(int shift)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return high - MathMax(open, close);
}

//+------------------------------------------------------------------+
//| Get lower tail size                                                |
//+------------------------------------------------------------------+
double GetLowerTail(int shift)
{
   double low = iLow(_Symbol, PERIOD_CURRENT, shift);
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return MathMin(open, close) - low;
}

//+------------------------------------------------------------------+
//| Check if candle is a Doji (indecision)                             |
//+------------------------------------------------------------------+
bool IsDoji(int shift)
{
   double range = GetCandleRange(shift);
   if(range <= 0) return false;
   double body = GetCandleBody(shift);
   return (body / range) <= InpPADojiMaxRatio;
}

//+------------------------------------------------------------------+
//| Detect Hammer/Pin Bar (Bullish) - Long lower tail, small body up  |
//+------------------------------------------------------------------+
bool IsHammer(int shift)
{
   if(!InpPAHammer) return false;
   
   double body = GetCandleBody(shift);
   double lowerTail = GetLowerTail(shift);
   double upperTail = GetUpperTail(shift);
   
   if(body <= 0) return false;
   
   // Hammer: long lower tail >= body * ratio, small upper tail
   bool longLowerTail = lowerTail >= body * InpPAPinRatio;
   bool smallUpperTail = upperTail <= body * 0.5;
   bool bullishClose = IsBullishCandle(shift);
   
   return longLowerTail && smallUpperTail && bullishClose;
}

//+------------------------------------------------------------------+
//| Detect Shooting Star/Pin Bar (Bearish) - Long upper tail          |
//+------------------------------------------------------------------+
bool IsShootingStar(int shift)
{
   if(!InpPAShootingStar) return false;
   
   double body = GetCandleBody(shift);
   double lowerTail = GetLowerTail(shift);
   double upperTail = GetUpperTail(shift);
   
   if(body <= 0) return false;
   
   // Shooting Star: long upper tail >= body * ratio, small lower tail
   bool longUpperTail = upperTail >= body * InpPAPinRatio;
   bool smallLowerTail = lowerTail <= body * 0.5;
   bool bearishClose = IsBearishCandle(shift);
   
   return longUpperTail && smallLowerTail && bearishClose;
}

//+------------------------------------------------------------------+
//| Detect Bullish Engulfing Pattern                                   |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int shift)
{
   if(!InpPABullEngulfing) return false;
   if(shift < 1) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   // Previous candle must be bearish
   if(!IsBearishCandle(shift + 1)) return false;
   
   double currOpen = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Current body engulfs previous body
   bool engulfs = currOpen <= prevClose && currClose >= prevOpen;
   
   // Current body is significant
   double currRange = GetCandleRange(shift);
   double currBody = GetCandleBody(shift);
   bool significantBody = currRange > 0 && (currBody / currRange) >= InpPABodyMinRatio;
   
   return engulfs && significantBody;
}

//+------------------------------------------------------------------+
//| Detect Bearish Engulfing Pattern                                   |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int shift)
{
   if(!InpPABearEngulfing) return false;
   if(shift < 1) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   // Previous candle must be bullish
   if(!IsBullishCandle(shift + 1)) return false;
   
   double currOpen = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Current body engulfs previous body
   bool engulfs = currOpen >= prevClose && currClose <= prevOpen;
   
   // Current body is significant
   double currRange = GetCandleRange(shift);
   double currBody = GetCandleBody(shift);
   bool significantBody = currRange > 0 && (currBody / currRange) >= InpPABodyMinRatio;
   
   return engulfs && significantBody;
}

//+------------------------------------------------------------------+
//| Detect Tweezer Bottom Pattern (2 candles with same low)           |
//+------------------------------------------------------------------+
bool IsTweezerBottom(int shift)
{
   if(!InpPATweezerBottom) return false;
   if(shift < 1) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prevLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Lows are approximately equal (within 10 points)
   double tolerance = 10 * _Point;
   bool sameLows = MathAbs(currLow - prevLow) <= tolerance;
   
   // Both candles have long lower tails
   double currLowerTail = GetLowerTail(shift);
   double prevLowerTail = GetLowerTail(shift + 1);
   double currRange = GetCandleRange(shift);
   double prevRange = GetCandleRange(shift + 1);
   
   bool currLongTail = currRange > 0 && (currLowerTail / currRange) >= 0.4;
   bool prevLongTail = prevRange > 0 && (prevLowerTail / prevRange) >= 0.4;
   
   // Current candle should be bullish (reversal confirmation)
   bool bullishCurrent = IsBullishCandle(shift);
   
   return sameLows && currLongTail && prevLongTail && bullishCurrent;
}

//+------------------------------------------------------------------+
//| Detect Tweezer Top Pattern (2 candles with same high)             |
//+------------------------------------------------------------------+
bool IsTweezerTop(int shift)
{
   if(!InpPATweezerTop) return false;
   if(shift < 1) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Highs are approximately equal (within 10 points)
   double tolerance = 10 * _Point;
   bool sameHighs = MathAbs(currHigh - prevHigh) <= tolerance;
   
   // Both candles have long upper tails
   double currUpperTail = GetUpperTail(shift);
   double prevUpperTail = GetUpperTail(shift + 1);
   double currRange = GetCandleRange(shift);
   double prevRange = GetCandleRange(shift + 1);
   
   bool currLongTail = currRange > 0 && (currUpperTail / currRange) >= 0.4;
   bool prevLongTail = prevRange > 0 && (prevUpperTail / prevRange) >= 0.4;
   
   // Current candle should be bearish (reversal confirmation)
   bool bearishCurrent = IsBearishCandle(shift);
   
   return sameHighs && currLongTail && prevLongTail && bearishCurrent;
}

//+------------------------------------------------------------------+
//| Detect Morning Star Pattern (3 candles bullish reversal)          |
//+------------------------------------------------------------------+
bool IsMorningStar(int shift)
{
   if(!InpPAMorningStar) return false;
   if(shift < 2) return false;
   
   // Candle 3 (oldest): Bearish
   if(!IsBearishCandle(shift + 2)) return false;
   
   // Candle 2 (middle): Doji/Indecision (small body)
   if(!IsDoji(shift + 1)) return false;
   
   // Candle 1 (current/newest): Bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Current candle closes above midpoint of first candle
   double firstOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstClose = iClose(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstMid = (firstOpen + firstClose) / 2.0;
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   
   return currClose >= firstMid;
}

//+------------------------------------------------------------------+
//| Detect Evening Star Pattern (3 candles bearish reversal)          |
//+------------------------------------------------------------------+
bool IsEveningStar(int shift)
{
   if(!InpPAEveningStar) return false;
   if(shift < 2) return false;
   
   // Candle 3 (oldest): Bullish
   if(!IsBullishCandle(shift + 2)) return false;
   
   // Candle 2 (middle): Doji/Indecision (small body)
   if(!IsDoji(shift + 1)) return false;
   
   // Candle 1 (current/newest): Bearish
   if(!IsBearishCandle(shift)) return false;
   
   // Current candle closes below midpoint of first candle
   double firstOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstClose = iClose(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstMid = (firstOpen + firstClose) / 2.0;
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   
   return currClose <= firstMid;
}

//+------------------------------------------------------------------+
//| Detect Outside Candle Reversal (Bullish)                           |
//| - Price faked down then broke above 2 previous candle highs       |
//+------------------------------------------------------------------+
bool IsOutsideCandleBullish(int shift)
{
   if(!InpPAOutsideCandleBull) return false;
   if(shift < 2) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current candle breaks above both previous highs
   bool breakHighs = currHigh > prev1High && currHigh > prev2High;
   
   // Current candle went below at least one previous low (faked down)
   bool fakedDown = currLow < prev1Low || currLow < prev2Low;
   
   return breakHighs && fakedDown;
}

//+------------------------------------------------------------------+
//| Detect Outside Candle Reversal (Bearish)                           |
//| - Price faked up then broke below 2 previous candle lows          |
//+------------------------------------------------------------------+
bool IsOutsideCandleBearish(int shift)
{
   if(!InpPAOutsideCandleBear) return false;
   if(shift < 2) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current candle breaks below both previous lows
   bool breakLows = currLow < prev1Low && currLow < prev2Low;
   
   // Current candle went above at least one previous high (faked up)
   bool fakedUp = currHigh > prev1High || currHigh > prev2High;
   
   return breakLows && fakedUp;
}

//+------------------------------------------------------------------+
//| Detect Pullback Buy Pattern                                        |
//| - Uptrend with pullback, then broke previous candle highs         |
//+------------------------------------------------------------------+
bool IsPullbackBuy(int shift)
{
   if(!InpPAPullbackBuy) return false;
   // Need at least 3 candles of history from the reference point
   // shift=1 needs shift+1 and shift+2, so minimum shift is 1
   if(shift < 1) return false;
   
   // Current candle (shift) must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Check for uptrend with pullback pattern
   // Pattern: Bullish move → Bearish pullback → Bullish continuation (current)
   // Current (shift): Bullish and breaks previous highs
   // Previous (shift+1 or shift+2): Had a bearish pullback candle
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current breaks previous highs (bullish continuation)
   bool breaksHighs = currHigh > prev1High && currHigh > prev2High;
   
   // There was a pullback (bearish candle in recent history)
   bool hadPullback = IsBearishCandle(shift + 1) || IsBearishCandle(shift + 2);
   
   return breaksHighs && hadPullback;
}

//+------------------------------------------------------------------+
//| Detect Pullback Sell Pattern                                       |
//| - Downtrend with pullback, then broke previous candle lows        |
//+------------------------------------------------------------------+
bool IsPullbackSell(int shift)
{
   if(!InpPAPullbackSell) return false;
   // Need at least 3 candles of history from the reference point
   if(shift < 1) return false;
   
   // Current candle (shift) must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current breaks previous lows (bearish continuation)
   bool breaksLows = currLow < prev1Low && currLow < prev2Low;
   
   // There was a pullback (bullish candle in recent history)
   bool hadPullback = IsBullishCandle(shift + 1) || IsBullishCandle(shift + 2);
   
   return breaksLows && hadPullback;
}

//+------------------------------------------------------------------+
//| Detect Inside Candle Reversal (Bullish)                            |
//| - 3 candle pattern: first candle, inside candle, then bullish     |
//+------------------------------------------------------------------+
bool IsInsideCandleBullish(int shift)
{
   if(!InpPAInsideCandleBull) return false;
   if(shift < 2) return false;
   
   // Candle 1 (current): Must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Candle 2 (middle): Inside candle - high and low within candle 3
   double midHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double midLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double firstHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstLow = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Middle candle is inside first candle
   bool isInside = midHigh <= firstHigh && midLow >= firstLow;
   
   // First candle should be bearish (for bullish reversal)
   bool firstBearish = IsBearishCandle(shift + 2);
   
   return isInside && firstBearish;
}

//+------------------------------------------------------------------+
//| Detect Inside Candle Reversal (Bearish)                            |
//| - 3 candle pattern: first candle, inside candle, then bearish     |
//+------------------------------------------------------------------+
bool IsInsideCandleBearish(int shift)
{
   if(!InpPAInsideCandleBear) return false;
   if(shift < 2) return false;
   
   // Candle 1 (current): Must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   // Candle 2 (middle): Inside candle - high and low within candle 3
   double midHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double midLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double firstHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstLow = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Middle candle is inside first candle
   bool isInside = midHigh <= firstHigh && midLow >= firstLow;
   
   // First candle should be bullish (for bearish reversal)
   bool firstBullish = IsBullishCandle(shift + 2);
   
   return isInside && firstBullish;
}

//+------------------------------------------------------------------+
//| Detect Bullish Hotdog Pattern                                      |
//| - Price faked up then moved lower, but broke two previous highs   |
//+------------------------------------------------------------------+
bool IsBullishHotdog(int shift)
{
   if(!InpPABullHotdog) return false;
   // shift=1 is the last CLOSED candle; we need 3 more candles back (shift+3),
   // so minimum shift is 1 (not 3). Using 3 causes a consistent 3-bar delay.
   if(shift < 1) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Previous candles had small bodies (indecision)
   bool prev1Small = IsDoji(shift + 1) || IsSpinningTop(shift + 1);
   bool prev2Small = IsDoji(shift + 2) || IsSpinningTop(shift + 2);
   
   // Current candle breaks above previous highs
   bool breaksHighs = currHigh > prev1High && currHigh > prev2High;
   
   // There was a fake move down followed by reversal up
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev3Low = iLow(_Symbol, PERIOD_CURRENT, shift + 3);
   bool fakedDown = prev1Low < prev2Low || prev1Low < prev3Low;
   
   return breaksHighs && (prev1Small || prev2Small || fakedDown);
}

//+------------------------------------------------------------------+
//| Detect Bearish Hotdog Pattern                                      |
//| - Price faked down then moved higher, but broke two previous lows |
//+------------------------------------------------------------------+
bool IsBearishHotdog(int shift)
{
   if(!InpPABearHotdog) return false;
   // shift=1 is the last CLOSED candle; using 3 forces a 3-bar confirmation delay.
   if(shift < 1) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Previous candles had small bodies (indecision)
   bool prev1Small = IsDoji(shift + 1) || IsSpinningTop(shift + 1);
   bool prev2Small = IsDoji(shift + 2) || IsSpinningTop(shift + 2);
   
   // Current candle breaks below previous lows
   bool breaksLows = currLow < prev1Low && currLow < prev2Low;
   
   // There was a fake move up followed by reversal down
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev3High = iHigh(_Symbol, PERIOD_CURRENT, shift + 3);
   bool fakedUp = prev1High > prev2High || prev1High > prev3High;
   
   return breaksLows && (prev1Small || prev2Small || fakedUp);
}

//+------------------------------------------------------------------+
//| Check if candle is Spinning Top (indecision with long tails)      |
//+------------------------------------------------------------------+
bool IsSpinningTop(int shift)
{
   double body = GetCandleBody(shift);
   double range = GetCandleRange(shift);
   double upperTail = GetUpperTail(shift);
   double lowerTail = GetLowerTail(shift);
   
   if(range <= 0) return false;
   
   // Small body relative to range
   bool smallBody = (body / range) <= InpPASpinningTopRatio;
   
   // Both tails are significant (at least 20% of range each)
   bool longTails = (upperTail / range) >= 0.2 && (lowerTail / range) >= 0.2;
   
   return smallBody && longTails;
}

//+------------------------------------------------------------------+
//| Check for ANY Bullish PA Pattern on the last closed candle        |
//+------------------------------------------------------------------+
string DetectBullishPA(int shift)
{
   if(IsHammer(shift))
      return "HAMMER";
   if(IsBullishEngulfing(shift))
      return "BULL_ENGULFING";
   if(IsTweezerBottom(shift))
      return "TWEEZER_BOTTOM";
   if(IsMorningStar(shift))
      return "MORNING_STAR";
   if(IsOutsideCandleBullish(shift))
      return "OUTSIDE_CANDLE_BULL";
   if(IsPullbackBuy(shift))
      return "PULLBACK_BUY";
   if(IsInsideCandleBullish(shift))
      return "INSIDE_CANDLE_BULL";
   if(IsBullishHotdog(shift))
      return "BULL_HOTDOG";
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check for ANY Bearish PA Pattern on the last closed candle        |
//+------------------------------------------------------------------+
string DetectBearishPA(int shift)
{
   if(IsShootingStar(shift))
      return "SHOOTING_STAR";
   if(IsBearishEngulfing(shift))
      return "BEAR_ENGULFING";
   if(IsTweezerTop(shift))
      return "TWEEZER_TOP";
   if(IsEveningStar(shift))
      return "EVENING_STAR";
   if(IsOutsideCandleBearish(shift))
      return "OUTSIDE_CANDLE_BEAR";
   if(IsPullbackSell(shift))
      return "PULLBACK_SELL";
   if(IsInsideCandleBearish(shift))
      return "INSIDE_CANDLE_BEAR";
   if(IsBearishHotdog(shift))
      return "BEAR_HOTDOG";
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Encode PA Pattern name to numeric code for Global Variable         |
//| Used to send PA info to Indicator when EA opens order              |
//+------------------------------------------------------------------+
int EncodePAPattern(int shift)
{
   // First check bullish patterns
   if(IsHammer(shift)) return 1;
   if(IsBullishEngulfing(shift)) return 2;
   if(IsTweezerBottom(shift)) return 3;
   if(IsMorningStar(shift)) return 4;
   if(IsInsideCandleBullish(shift)) return 5;
   if(IsBullishHotdog(shift)) return 6;
   if(IsOutsideCandleBullish(shift)) return 8;
   if(IsPullbackBuy(shift)) return 9;
   
   // Then check bearish patterns
   if(IsShootingStar(shift)) return 7;
   if(IsBearishEngulfing(shift)) return 2;  // Same code as bullish engulf
   if(IsTweezerTop(shift)) return 3;        // Same code as tweezer bottom
   if(IsEveningStar(shift)) return 4;       // Same code as morning star
   if(IsInsideCandleBearish(shift)) return 5;
   if(IsBearishHotdog(shift)) return 6;
   if(IsOutsideCandleBearish(shift)) return 8;
   if(IsPullbackSell(shift)) return 9;
   
   return 10;  // Unknown pattern
}

//+------------------------------------------------------------------+
//| Draw PA Arrow and Label on Chart                                   |
//+------------------------------------------------------------------+
void DrawPAArrow(string tradeType, string paPattern, datetime barTime, double price)
{
   string uniqueId = IntegerToString((long)barTime);
   
   // Get average candle range for dynamic offset
   double avgRange = 0;
   for(int i = 1; i <= 10; i++)
   {
      avgRange += iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
   }
   avgRange /= 10;
   
   // Dynamic offsets based on average range
   double arrowOffset = avgRange * 0.4;    // Arrow distance from candle
   double labelOffset = avgRange * 1.2;    // Label distance from candle (much further than arrow)
   
   // Create Arrow Object
   string arrowName = PAPrefix + "Arrow_" + uniqueId;
   
   if(tradeType == "BUY")
   {
      // Draw UP arrow below the candle low (price)
      double arrowPrice = price - arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }
   else // SELL
   {
      // Draw DOWN arrow above the candle high (price)
      double arrowPrice = price + arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, false);
   
   // Create Text Label for PA Pattern (further away from candle)
   string labelName = PAPrefix + "Label_" + uniqueId;
   double labelPrice;
   
   if(tradeType == "BUY")
   {
      labelPrice = price - labelOffset;
   }
   else
   {
      labelPrice = price + labelOffset;
   }
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, barTime, labelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, paPattern);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, tradeType == "BUY" ? clrLime : clrRed);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, tradeType == "BUY" ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
   
   Print("PA Arrow drawn: ", tradeType, " | Pattern: ", paPattern, " | Time: ", TimeToString(barTime));
}

//+------------------------------------------------------------------+
//| Get readable PA Pattern name                                       |
//+------------------------------------------------------------------+
string GetPAPatternName(string paCode)
{
   if(paCode == "HAMMER") return "Hammer";
   if(paCode == "BULL_ENGULFING") return "Bull Engulf";
   if(paCode == "TWEEZER_BOTTOM") return "Twzr Bottom";
   if(paCode == "MORNING_STAR") return "Morn Star";
   if(paCode == "OUTSIDE_CANDLE_BULL") return "Outside Bull";
   if(paCode == "PULLBACK_BUY") return "Pullback";
   if(paCode == "INSIDE_CANDLE_BULL") return "Inside Bull";
   if(paCode == "BULL_HOTDOG") return "Bull Hotdog";
   
   if(paCode == "SHOOTING_STAR") return "Shoot Star";
   if(paCode == "BEAR_ENGULFING") return "Bear Engulf";
   if(paCode == "TWEEZER_TOP") return "Twzr Top";
   if(paCode == "EVENING_STAR") return "Even Star";
   if(paCode == "OUTSIDE_CANDLE_BEAR") return "Outside Bear";
   if(paCode == "PULLBACK_SELL") return "Pullback";
   if(paCode == "INSIDE_CANDLE_BEAR") return "Inside Bear";
   if(paCode == "BEAR_HOTDOG") return "Bear Hotdog";
   
   return paCode;
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for BUY                      |
//| Returns: pattern name if PA found, "NONE" if not                   |
//| IMPORTANT: PA must occur AFTER the signal touch time               |
//| signalTouchTime = time when OB touch/signal occurred               |
//|                   PA candle must close AFTER this time             |
//+------------------------------------------------------------------+
string CheckBuyPAConfirmationWithPattern(datetime signalTouchTime = 0)
{
   if(!InpUsePAConfirm)
      return "NO_PA_REQUIRED";  // PA not required
   
   // Scan recent closed candles for PA within lookback window.
   // CRITICAL: PA candle time must be >= signalTouchTime (PA must come AFTER signal)
   int maxLookback = MathMax(1, MathMin(InpPALookback, 10));
   
   for(int shift = 1; shift <= maxLookback; shift++)
   {
      datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, shift);
      
      // *** CRITICAL CHECK: PA must occur ON or AFTER the signal touch candle ***
      // Using '<' to allow PA in the SAME candle as touch (touch bar can close as PA)
      // Example: OB touched at bar X, PA forms when bar X closes → valid!
      if(signalTouchTime > 0 && candleTime < signalTouchTime)
      {
         // This PA candle is from BEFORE the touch candle - skip it
         continue;
      }
      
      string paPattern = DetectBullishPA(shift);
      if(paPattern != "NONE")
      {
         g_lastPABuyShift = shift;
         Print(">>> BULLISH PA CONFIRMED: ", paPattern, " | shift=", shift, " | candleTime=", TimeToString(candleTime), " | touchTime=", TimeToString(signalTouchTime));
         return paPattern;
      }
   }
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for SELL                     |
//| Returns: pattern name if PA found, "NONE" if not                   |
//| IMPORTANT: PA must occur AFTER the signal touch time               |
//+------------------------------------------------------------------+
string CheckSellPAConfirmationWithPattern(datetime signalTouchTime = 0)
{
   if(!InpUsePAConfirm)
      return "NO_PA_REQUIRED";  // PA not required
   
   int maxLookback = MathMax(1, MathMin(InpPALookback, 10));
   
   for(int shift = 1; shift <= maxLookback; shift++)
   {
      datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, shift);
      
      // *** CRITICAL CHECK: PA must occur ON or AFTER the signal touch candle ***
      // Using '<' to allow PA in the SAME candle as touch
      if(signalTouchTime > 0 && candleTime < signalTouchTime)
      {
         continue;
      }
      
      string paPattern = DetectBearishPA(shift);
      if(paPattern != "NONE")
      {
         g_lastPASellShift = shift;
         Print(">>> BEARISH PA CONFIRMED: ", paPattern, " | shift=", shift, " | candleTime=", TimeToString(candleTime), " | touchTime=", TimeToString(signalTouchTime));
         return paPattern;
      }
   }
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for BUY                      |
//| Returns: true if PA found OR PA not required                       |
//+------------------------------------------------------------------+
bool CheckBuyPAConfirmation()
{
   string result = CheckBuyPAConfirmationWithPattern();
   return result != "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for SELL                     |
//| Returns: true if PA found OR PA not required                       |
//+------------------------------------------------------------------+
bool CheckSellPAConfirmation()
{
   string result = CheckSellPAConfirmationWithPattern();
   return result != "NONE";
}

//+------------------------------------------------------------------+
//| Handle Pending Signal with PA Confirmation                         |
//| IMPORTANT: PA must occur AFTER g_signalTouchTime                   |
//| g_signalTouchTime is set when OB touch/signal first occurred       |
//+------------------------------------------------------------------+
void HandlePendingSignal()
{
   if(!InpUsePAConfirm || g_pendingSignal == "NONE")
      return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Check if we've exceeded max wait candles
   if(currentBarTime != g_signalBarTime)
   {
      g_paWaitCount++;
      g_signalBarTime = currentBarTime;
      
      if(g_paWaitCount > InpPALookback)
      {
         Print("PA TIMEOUT: Waited ", InpPALookback, " candles - Signal cancelled | TouchTime=", TimeToString(g_signalTouchTime));
         g_pendingSignal = "NONE";
         g_paWaitCount = 0;
         g_signalTouchTime = 0;  // Reset touch time
         return;
      }
   }
   
   // Check for PA confirmation
   // CRITICAL: Pass g_signalTouchTime to ensure PA occurred AFTER the signal/OB touch
   if(g_pendingSignal == "BUY")
   {
      string paPattern = CheckBuyPAConfirmationWithPattern(g_signalTouchTime);
      if(paPattern != "NONE")
      {
         // Check if trade is still allowed
         if(CountPositions(POSITION_TYPE_BUY) == 0 && IsTradeAllowed("BUY"))
         {
            // Try to execute first; only draw PA + clear pending if success
            if(ExecuteBuy())
            {
               // Draw PA arrow on chart (use the candle where PA was detected)
               int shift = g_lastPABuyShift;
               datetime signalBar = iTime(_Symbol, PERIOD_CURRENT, shift);
               double signalPrice = iLow(_Symbol, PERIOD_CURRENT, shift);
               DrawPAArrow("BUY", GetPAPatternName(paPattern), signalBar, signalPrice);
               
               Print("BUY executed after PA confirmation (", paPattern, ") - waited ", g_paWaitCount, " candles | TouchTime=", TimeToString(g_signalTouchTime));
               g_pendingSignal = "NONE";
               g_paWaitCount = 0;
               g_signalTouchTime = 0;  // Reset touch time
            }
            else
            {
               // Keep pending signal to retry next candle (prevents missing entry due to temporary trade failure)
               Print("BUY execution failed after PA; keeping pending to retry | Retcode=", trade.ResultRetcode());
            }
         }
         else
         {
            // Trade no longer allowed -> keep waiting (do not discard) until timeout
            Print("BUY blocked after PA due to filters; keeping pending | CDC=", CDCTrend);
         }
         
      }
      else
      {
         Print("Waiting for Bullish PA AFTER touch... (", g_paWaitCount, "/", InpPALookback, ") | TouchTime=", TimeToString(g_signalTouchTime));
      }
   }
   else if(g_pendingSignal == "SELL")
   {
      string paPattern = CheckSellPAConfirmationWithPattern(g_signalTouchTime);
      if(paPattern != "NONE")
      {
         // Check if trade is still allowed
         if(CountPositions(POSITION_TYPE_SELL) == 0 && IsTradeAllowed("SELL"))
         {
            // Try to execute first; only draw PA + clear pending if success
            if(ExecuteSell())
            {
               // Draw PA arrow on chart (use the candle where PA was detected)
               int shift = g_lastPASellShift;
               datetime signalBar = iTime(_Symbol, PERIOD_CURRENT, shift);
               double signalPrice = iHigh(_Symbol, PERIOD_CURRENT, shift);
               DrawPAArrow("SELL", GetPAPatternName(paPattern), signalBar, signalPrice);
               
               Print("SELL executed after PA confirmation (", paPattern, ") - waited ", g_paWaitCount, " candles | TouchTime=", TimeToString(g_signalTouchTime));
               g_pendingSignal = "NONE";
               g_paWaitCount = 0;
               g_signalTouchTime = 0;  // Reset touch time
            }
            else
            {
               Print("SELL execution failed after PA; keeping pending to retry | Retcode=", trade.ResultRetcode());
            }
         }
         else
         {
            Print("SELL blocked after PA due to filters; keeping pending | CDC=", CDCTrend);
         }
         
      }
      else
      {
         Print("Waiting for Bearish PA AFTER touch... (", g_paWaitCount, "/", InpPALookback, ") | TouchTime=", TimeToString(g_signalTouchTime));
      }
   }
}

//+------------------------------------------------------------------+
//| ================== END PRICE ACTION DETECTION ================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool IsTradeAllowed(string tradeType)
{
   if(tradeType == "BUY")
   {
      if(InpTradeMode == TRADE_SELL_ONLY)
         return false;
   }
   else if(tradeType == "SELL")
   {
      if(InpTradeMode == TRADE_BUY_ONLY)
         return false;
   }
   
   if(InpUseCDCFilter)
   {
      if(tradeType == "BUY" && CDCTrend != "BULLISH")
         return false;
      if(tradeType == "SELL" && CDCTrend != "BEARISH")
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Trade Mode description                                         |
//+------------------------------------------------------------------+
string GetTradeModeString()
{
   switch(InpTradeMode)
   {
      case TRADE_BUY_ONLY:  return "BUY ONLY";
      case TRADE_SELL_ONLY: return "SELL ONLY";
      default:              return "BUY/SELL";
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Lot Mode                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = InpInitialLot;
   
   if(InpLotMode == LOT_RISK_PERCENT)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * InpRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipValue = tickValue * (10 * _Point / tickSize);
      lot = riskAmount / (InpSLPoints * pipValue);
   }
   else if(InpLotMode == LOT_RISK_DOLLAR)
   {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipValue = tickValue * (10 * _Point / tickSize);
      double scaledRiskDollar = ApplyScaleDollar(InpRiskDollar);
      lot = scaledRiskDollar / (InpSLPoints * pipValue);
   }
   else
   {
      // Fixed Lot Mode - Apply Auto Scaling
      lot = ApplyScaleLot(InpInitialLot);
   }
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Get Total Floating Profit/Loss for this EA                         |
//+------------------------------------------------------------------+
double GetTotalFloatingPL()
{
   double totalPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            totalPL += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Get Floating PL by Position Type (BUY/SELL)                        |
//+------------------------------------------------------------------+
double GetFloatingPLByType(ENUM_POSITION_TYPE posType)
{
   double pl = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               pl += PositionGetDouble(POSITION_PROFIT);
            }
         }
      }
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Get Average Price and Total Lots by Position Type                  |
//+------------------------------------------------------------------+
void GetAveragePriceAndLots(ENUM_POSITION_TYPE posType, double &avgPrice, double &totalLots)
{
   double sumPriceLot = 0;
   totalLots = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               double price = PositionGetDouble(POSITION_PRICE_OPEN);
               double lot = PositionGetDouble(POSITION_VOLUME);
               sumPriceLot += price * lot;
               totalLots += lot;
            }
         }
      }
   }
   
   if(totalLots > 0)
      avgPrice = sumPriceLot / totalLots;
   else
      avgPrice = 0;
}

//+------------------------------------------------------------------+
//| Calculate TP Price based on Average Price and TP Points            |
//+------------------------------------------------------------------+
double CalculateTPPrice(ENUM_POSITION_TYPE posType, double avgPrice)
{
   if(!InpUseTPPoints || avgPrice == 0) return 0;
   
   // TP Points ไม่ปรับ Scale เพราะเป็นระยะทางคงที่
   if(posType == POSITION_TYPE_BUY)
      return avgPrice + InpTPPoints * _Point;
   else
      return avgPrice - InpTPPoints * _Point;
}

//+------------------------------------------------------------------+
//| Calculate SL Price based on Average Price and SL Points            |
//+------------------------------------------------------------------+
double CalculateSLPrice(ENUM_POSITION_TYPE posType, double avgPrice)
{
   if(!InpUseSLPoints || avgPrice == 0) return 0;
   
   // SL Points ไม่ปรับ Scale เพราะเป็นระยะทางคงที่
   if(posType == POSITION_TYPE_BUY)
      return avgPrice - InpSLPoints * _Point;
   else
      return avgPrice + InpSLPoints * _Point;
}

//+------------------------------------------------------------------+
//| Draw Average Price, TP and SL Lines                                |
//+------------------------------------------------------------------+
void DrawTPSLLines()
{
   // Remove old lines
   ObjectsDeleteAll(0, TPPrefix);
   
   // If hedge locked, don't draw any TP/SL lines
   if(g_isHedgeLocked) return;
   
   double avgBuy, lotsBuy, avgSell, lotsSell;
   GetAveragePriceAndLots(POSITION_TYPE_BUY, avgBuy, lotsBuy);
   GetAveragePriceAndLots(POSITION_TYPE_SELL, avgSell, lotsSell);
   
   datetime startTime = iTime(_Symbol, PERIOD_D1, 10);
   datetime endTime = TimeCurrent() + 86400 * 5;
   
   // Draw BUY Average Line and TP/SL
   if(avgBuy > 0 && InpShowAverageLine)
   {
      string lineName = TPPrefix + "AvgBuy";
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, avgBuy);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpAverageLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, lineName, OBJPROP_TEXT, "AVG BUY: " + DoubleToString(avgBuy, _Digits));
      
      // TP Line for BUY
      if(InpShowTPLine && InpUseTPPoints)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_BUY, avgBuy);
         string tpLineName = TPPrefix + "TPBuy";
         ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tpPrice);
         ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, InpTPLineColor);
         ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, tpLineName, OBJPROP_TEXT, "TP BUY: " + DoubleToString(tpPrice, _Digits));
      }
      
      // SL Line for BUY
      if(InpShowSLLine && InpUseSLPoints)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_BUY, avgBuy);
         string slLineName = TPPrefix + "SLBuy";
         ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, slPrice);
         ObjectSetInteger(0, slLineName, OBJPROP_COLOR, InpSLLineColor);
         ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, slLineName, OBJPROP_TEXT, "SL BUY: " + DoubleToString(slPrice, _Digits));
      }
   }
   
   // Draw SELL Average Line and TP/SL
   if(avgSell > 0 && InpShowAverageLine)
   {
      string lineName = TPPrefix + "AvgSell";
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, avgSell);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpAverageLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, lineName, OBJPROP_TEXT, "AVG SELL: " + DoubleToString(avgSell, _Digits));
      
      // TP Line for SELL
      if(InpShowTPLine && InpUseTPPoints)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_SELL, avgSell);
         string tpLineName = TPPrefix + "TPSell";
         ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tpPrice);
         ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, InpTPLineColor);
         ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, tpLineName, OBJPROP_TEXT, "TP SELL: " + DoubleToString(tpPrice, _Digits));
      }
      
      // SL Line for SELL
      if(InpShowSLLine && InpUseSLPoints)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_SELL, avgSell);
         string slLineName = TPPrefix + "SLSell";
         ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, slPrice);
         ObjectSetInteger(0, slLineName, OBJPROP_COLOR, InpSLLineColor);
         ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, slLineName, OBJPROP_TEXT, "SL SELL: " + DoubleToString(slPrice, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Close positions by type                                            |
//+------------------------------------------------------------------+
double ClosePositionsByType(ENUM_POSITION_TYPE posType)
{
   double closedProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               closedProfit += PositionGetDouble(POSITION_PROFIT);
               ulong ticket = PositionGetInteger(POSITION_TICKET);
               trade.PositionClose(ticket);
            }
         }
      }
   }
   
   // Reset grid counters and hedge flag for this side
   if(posType == POSITION_TYPE_BUY)
   {
      GridBuyCount = 0;
      InitialBuyBarTime = 0;
      g_isHedgedBuy = false;  // Reset hedge flag when positions closed

      // NOTE (SMC): We do NOT run per-side "signal reset" anymore.
      // Entry is re-armed ONLY when ALL EA positions are flat (see ResetSMCEntryCycle in OnTick).
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_waitBuySignalReset = false;
         g_smcBuyResetRequired = false;
         g_smcBuyResetPhaseComplete = false;

         // Clear BUY-side touch context so a NEW touch after flat is required.
         g_smcBuyTouchedOBPersist = false;
         g_smcBuyTouchedOB = false;
         g_smcBuyTouchedOBName = "";
         g_smcBuyTouchTime = 0;

         Print("*** SMC BUY: BUY positions closed - entries will re-arm only when ALL positions are flat ***");
      }
      else
      {
         // *** SET BUY SIGNAL RESET FLAG ***
         g_waitBuySignalReset = true;
         g_buyResetPhaseBelowEMA = false;
         g_buyResetWaitOppositeSignal = true;

         Print("*** BUY Signal Reset Required - Wait for price to cross below EMA then above ***");
      }
   }
   else
   {
      GridSellCount = 0;
      InitialSellBarTime = 0;
      g_isHedgedSell = false;  // Reset hedge flag when positions closed

      // NOTE (SMC): We do NOT run per-side "signal reset" anymore.
      // Entry is re-armed ONLY when ALL EA positions are flat (see ResetSMCEntryCycle in OnTick).
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_waitSellSignalReset = false;
         g_smcSellResetRequired = false;
         g_smcSellResetPhaseComplete = false;

         // Clear SELL-side touch context so a NEW touch after flat is required.
         g_smcSellTouchedOBPersist = false;
         g_smcSellTouchedOB = false;
         g_smcSellTouchedOBName = "";
         g_smcSellTouchTime = 0;

         Print("*** SMC SELL: SELL positions closed - entries will re-arm only when ALL positions are flat ***");
      }
      else
      {
         // *** SET SELL SIGNAL RESET FLAG ***
         g_waitSellSignalReset = true;
         g_sellResetPhaseAboveEMA = false;
         g_sellResetWaitOppositeSignal = true;

         Print("*** SELL Signal Reset Required - Wait for price to cross above EMA then below ***");
      }
   }
   
   // Reset global hedge lock if no more hedge positions
   if(!g_isHedgedBuy && !g_isHedgedSell)
   {
      g_isHedgeLocked = false;
      Print("Hedge lock released - trading resumed");
   }
   
   return closedProfit;
}

//+------------------------------------------------------------------+
//| Hedge positions by type (open opposite position to lock loss)      |
//| Opens exactly ONE hedge order and sets flag to prevent repeats     |
//+------------------------------------------------------------------+
bool HedgePositionsByType(ENUM_POSITION_TYPE posType, double totalLots)
{
   // If global hedge lock is already active - NO MORE HEDGE ORDERS AT ALL
   if(g_isHedgeLocked)
   {
      Print("HEDGE LOCK already active - NO more hedge orders allowed");
      return false;
   }
   
   // Check if this side already hedged - PREVENT MULTIPLE HEDGE ORDERS
   if(posType == POSITION_TYPE_BUY && g_isHedgedBuy)
   {
      Print("BUY side already hedged - skipping");
      return false;
   }
   if(posType == POSITION_TYPE_SELL && g_isHedgedSell)
   {
      Print("SELL side already hedged - skipping");
      return false;
   }
   
   // Calculate opposite order type
   ENUM_ORDER_TYPE hedgeType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   string hedgeTypeStr = (hedgeType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   
   double price = (hedgeType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Open hedge position with total lots - ONLY ONCE
   if(trade.PositionOpen(_Symbol, hedgeType, totalLots, price, 0, 0, "HEDGE_LOCK"))
   {
      Print("HEDGE ", hedgeTypeStr, " opened: ", totalLots, " lots at ", price, " to lock loss");
      Print("*** HEDGE LOCK ACTIVATED - All trading & TP/SL stopped until manual close ***");
      
      // Set hedge flag to prevent further hedge orders
      if(posType == POSITION_TYPE_BUY)
         g_isHedgedBuy = true;
      else
         g_isHedgedSell = true;
      
      // Set global hedge lock - STOPS ALL TRADING AND TP/SL
      g_isHedgeLocked = true;
      
      // Remove all TP/SL lines immediately
      ObjectsDeleteAll(0, TPPrefix);
         
      return true;
   }
   else
   {
      Print("HEDGE ", hedgeTypeStr, " failed: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Execute SL Action based on mode (Close or Hedge)                   |
//+------------------------------------------------------------------+
void ExecuteSLAction(ENUM_POSITION_TYPE posType, double totalLots, string reason)
{
   if(InpSLActionMode == SL_ACTION_CLOSE)
   {
      Print(reason, " - Closing positions");
      ClosePositionsByType(posType);
   }
   else // SL_ACTION_HEDGE
   {
      Print(reason, " - Hedging with ", totalLots, " lots");
      HedgePositionsByType(posType, totalLots);
   }
}

//+------------------------------------------------------------------+
//| Execute SL Action for All Positions (Close or Hedge)               |
//+------------------------------------------------------------------+
void ExecuteSLActionAll(double buyLots, double sellLots, string reason)
{
   if(InpSLActionMode == SL_ACTION_CLOSE)
   {
      Print(reason, " - Closing all positions");
      CloseAllPositions();
   }
   else // SL_ACTION_HEDGE
   {
      // Hedge both sides if they exist
      if(buyLots > 0)
      {
         Print(reason, " - Hedging BUY side with ", buyLots, " lots");
         HedgePositionsByType(POSITION_TYPE_BUY, buyLots);
      }
      if(sellLots > 0)
      {
         Print(reason, " - Hedging SELL side with ", sellLots, " lots");
         HedgePositionsByType(POSITION_TYPE_SELL, sellLots);
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
         }
      }
   }
   
   // Reset all counters
   GridBuyCount = 0;
   GridSellCount = 0;
   InitialBuyBarTime = 0;
   InitialSellBarTime = 0;
   
   // Reset hedge flags when all positions closed
   g_isHedgedBuy = false;
   g_isHedgedSell = false;
   g_isHedgeLocked = false;  // Reset global hedge lock

   if(InpSignalStrategy == STRATEGY_SMC)
   {
      // SMC entries re-arm only when ALL positions are flat (handled in OnTick).
      g_waitBuySignalReset = false;
      g_waitSellSignalReset = false;
      g_smcBuyResetRequired = false;
      g_smcSellResetRequired = false;
      g_smcBuyResetPhaseComplete = false;
      g_smcSellResetPhaseComplete = false;

      // Clear touch & pending PA context so a NEW OB touch is required.
      g_smcBuyTouchedOBPersist = false;
      g_smcSellTouchedOBPersist = false;
      g_smcBuyTouchedOB = false;
      g_smcSellTouchedOB = false;
      g_smcBuyTouchedOBName = "";
      g_smcSellTouchedOBName = "";
      g_smcBuyTouchTime = 0;
      g_smcSellTouchTime = 0;
      g_smcLastBuyOBUsed = "";
      g_smcLastSellOBUsed = "";

      g_pendingSignal = "NONE";
      g_paWaitCount = 0;
      g_signalTouchTime = 0;
      g_signalBarTime = 0;

      Print("*** SMC: All positions closed - waiting for a NEW OB touch to start a new entry cycle ***");
      return;
   }
   
   // *** SET SIGNAL RESET FLAGS ***
   // After closing all positions, require signal to reset before new entries
   g_waitBuySignalReset = true;
   g_waitSellSignalReset = true;
   g_buyResetPhaseBelowEMA = false;
   g_sellResetPhaseAboveEMA = false;
   g_buyResetWaitOppositeSignal = true;
   g_sellResetWaitOppositeSignal = true;
   
   Print("*** Signal Reset Required - Waiting for new signal cycle ***");
}

//+------------------------------------------------------------------+
//| Check TP/SL Conditions (Advanced Close Logic)                      |
//+------------------------------------------------------------------+
void CheckTPSLConditions()
{
   // If hedge locked, skip ALL TP/SL checks - wait for manual close only
   if(g_isHedgeLocked)
   {
      return;
   }
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalPL = GetTotalFloatingPL();
   double buyPL = GetFloatingPLByType(POSITION_TYPE_BUY);
   double sellPL = GetFloatingPLByType(POSITION_TYPE_SELL);
   
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   double avgBuy, lotsBuy, avgSell, lotsSell;
   GetAveragePriceAndLots(POSITION_TYPE_BUY, avgBuy, lotsBuy);
   GetAveragePriceAndLots(POSITION_TYPE_SELL, avgSell, lotsSell);
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // ========== TAKE PROFIT LOGIC ==========
   
   // Get scaled values for Auto Balance Scaling
   double scaledTPDollar = ApplyScaleDollar(InpTPDollarAmount);
   double scaledSLDollar = ApplyScaleDollar(InpSLDollarAmount);
   
   // 1. TP Fixed Dollar - Close each side when reaches target
   if(InpUseTPDollar)
   {
      if(buyPL >= scaledTPDollar && buyCount > 0)
      {
         Print("TP Dollar - BUY side reached $", buyPL, " (Target: $", scaledTPDollar, ")");
         ClosePositionsByType(POSITION_TYPE_BUY);
      }
      if(sellPL >= scaledTPDollar && sellCount > 0)
      {
         Print("TP Dollar - SELL side reached $", sellPL, " (Target: $", scaledTPDollar, ")");
         ClosePositionsByType(POSITION_TYPE_SELL);
      }
   }
   
   // 2. TP in Points - Close when price reaches TP from average
   if(InpUseTPPoints)
   {
      if(buyCount > 0 && avgBuy > 0)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_BUY, avgBuy);
         if(currentBid >= tpPrice)
         {
            Print("TP Points - BUY side hit TP at ", tpPrice);
            ClosePositionsByType(POSITION_TYPE_BUY);
         }
      }
      if(sellCount > 0 && avgSell > 0)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_SELL, avgSell);
         if(currentAsk <= tpPrice)
         {
            Print("TP Points - SELL side hit TP at ", tpPrice);
            ClosePositionsByType(POSITION_TYPE_SELL);
         }
      }
   }
   
   // 3. TP Percent of Balance
   if(InpUseTPPercent)
   {
      double tpAmount = balance * InpTPPercent / 100.0;
      if(buyPL >= tpAmount && buyCount > 0)
      {
         Print("TP Percent - BUY side reached ", InpTPPercent, "% ($", buyPL, ")");
         ClosePositionsByType(POSITION_TYPE_BUY);
      }
      if(sellPL >= tpAmount && sellCount > 0)
      {
         Print("TP Percent - SELL side reached ", InpTPPercent, "% ($", sellPL, ")");
         ClosePositionsByType(POSITION_TYPE_SELL);
      }
   }
   
   // ========== STOP LOSS LOGIC ==========
   // Skip if SL Settings is disabled
   if(!InpUseSLSettings) return;
   
   // Mode: SL_ACTION_CLOSE = Close positions | SL_ACTION_HEDGE = Open hedge to lock loss
   
   // 1. SL Fixed Dollar (scaled)
   if(InpUseSLDollar)
   {
      if(buyPL <= -scaledSLDollar && buyCount > 0)
      {
         ExecuteSLAction(POSITION_TYPE_BUY, lotsBuy, "SL Dollar - BUY side hit $" + DoubleToString(-scaledSLDollar, 2));
      }
      if(sellPL <= -scaledSLDollar && sellCount > 0)
      {
         ExecuteSLAction(POSITION_TYPE_SELL, lotsSell, "SL Dollar - SELL side hit $" + DoubleToString(-scaledSLDollar, 2));
      }
   }
   
   // 2. SL in Points (already scaled in CalculateSLPrice)
   if(InpUseSLPoints)
   {
      if(buyCount > 0 && avgBuy > 0)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_BUY, avgBuy);
         if(currentBid <= slPrice)
         {
            ExecuteSLAction(POSITION_TYPE_BUY, lotsBuy, "SL Points - BUY side hit SL at " + DoubleToString(slPrice, _Digits));
         }
      }
      if(sellCount > 0 && avgSell > 0)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_SELL, avgSell);
         if(currentAsk >= slPrice)
         {
            ExecuteSLAction(POSITION_TYPE_SELL, lotsSell, "SL Points - SELL side hit SL at " + DoubleToString(slPrice, _Digits));
         }
      }
   }
   
   // 3. SL Percent of Balance
   if(InpUseSLPercent)
   {
      double slAmount = balance * InpSLPercent / 100.0;
      if(totalPL <= -slAmount)
      {
         ExecuteSLActionAll(lotsBuy, lotsSell, "SL Percent - Total loss reached " + DoubleToString(InpSLPercent, 1) + "% ($" + DoubleToString(totalPL, 2) + ")");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Count positions by type                                            |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE posType)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
               count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get Last Position Price by type                                    |
//+------------------------------------------------------------------+
double GetLastPositionPrice(ENUM_POSITION_TYPE posType)
{
   double lastPrice = 0;
   datetime lastTime = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(posTime > lastTime)
               {
                  lastTime = posTime;
                  lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
      }
   }
   return lastPrice;
}

//+------------------------------------------------------------------+
//| Get First Position Price by type                                   |
//+------------------------------------------------------------------+
double GetFirstPositionPrice(ENUM_POSITION_TYPE posType)
{
   double firstPrice = 0;
   datetime firstTime = D'2099.01.01';
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(posTime < firstTime)
               {
                  firstTime = posTime;
                  firstPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
      }
   }
   return firstPrice;
}

//+------------------------------------------------------------------+
//| Check and Execute Grid Loss Side                                   |
//+------------------------------------------------------------------+
void CheckGridLossSide()
{
   if(InpGridLossMaxTrades <= 0) return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check BUY Grid (when price goes down = loss side for BUY)
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   
   // *** นับ Grid Loss orders แยกจาก Grid Profit โดยดูจาก comment ***
   int buyGridLossCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               string comment = PositionGetString(POSITION_COMMENT);
               if(StringFind(comment, "Grid Loss") >= 0)
                  buyGridLossCount++;
            }
         }
      }
   }
   
   if(buyCount > 0 && buyGridLossCount < InpGridLossMaxTrades)
   {
      // Check if should skip same candle
      if(InpGridLossDontOpenSameCandle && currentBarTime == InitialBuyBarTime)
         return;
      
      // Check new candle requirement
      if(InpGridLossNewCandle && currentBarTime == LastGridBuyTime)
         return;
      
      // Check signal requirement
      if(InpGridLossOnlySignal && !IsTradeAllowed("BUY"))
         return;
      
      double lastBuyPrice = GetLastPositionPrice(POSITION_TYPE_BUY);
      
      // *** Grid Loss นับ level แยกจาก Grid Profit ***
      // buyGridLossCount = จำนวน Grid Loss orders ที่มีอยู่แล้ว (นับจาก comment)
      // gridLevel สำหรับ Grid Loss = buyGridLossCount + 1 (ออเดอร์ถัดไป)
      int gridLossLevel = buyGridLossCount + 1;
      int distance = GetGridDistance(true, buyGridLossCount);
      
      // Price went DOWN from last buy by grid distance
      if(lastBuyPrice - currentPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLossLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         Print("Grid Loss BUY #", gridLossLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Buy(lot, _Symbol, price, 0, 0, "Grid Loss BUY #" + IntegerToString(gridLossLevel)))
         {
            LastGridBuyTime = currentBarTime;
            GridBuyCount = buyCount + 1;
         }
      }
   }
   
   // Check SELL Grid (when price goes up = loss side for SELL)
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   // *** นับ Grid Loss orders แยกจาก Grid Profit โดยดูจาก comment ***
   int sellGridLossCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               string comment = PositionGetString(POSITION_COMMENT);
               if(StringFind(comment, "Grid Loss") >= 0)
                  sellGridLossCount++;
            }
         }
      }
   }
   
   if(sellCount > 0 && sellGridLossCount < InpGridLossMaxTrades)
   {
      // Check if should skip same candle
      if(InpGridLossDontOpenSameCandle && currentBarTime == InitialSellBarTime)
         return;
      
      // Check new candle requirement
      if(InpGridLossNewCandle && currentBarTime == LastGridSellTime)
         return;
      
      // Check signal requirement
      if(InpGridLossOnlySignal && !IsTradeAllowed("SELL"))
         return;
      
      double lastSellPrice = GetLastPositionPrice(POSITION_TYPE_SELL);
      
      // *** Grid Loss นับ level แยกจาก Grid Profit ***
      // sellGridLossCount = จำนวน Grid Loss orders ที่มีอยู่แล้ว (นับจาก comment)
      // gridLevel สำหรับ Grid Loss = sellGridLossCount + 1 (ออเดอร์ถัดไป)
      int gridLossLevel = sellGridLossCount + 1;
      int distance = GetGridDistance(true, sellGridLossCount);
      
      // Price went UP from last sell by grid distance
      if(currentPrice - lastSellPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLossLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         Print("Grid Loss SELL #", gridLossLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Sell(lot, _Symbol, price, 0, 0, "Grid Loss SELL #" + IntegerToString(gridLossLevel)))
         {
            LastGridSellTime = currentBarTime;
            GridSellCount = sellCount + 1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check and Execute Grid Profit Side                                 |
//+------------------------------------------------------------------+
void CheckGridProfitSide()
{
   if(!InpUseGridProfit || InpGridProfitMaxTrades <= 0) return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check BUY Grid Profit (when price goes up = profit side for BUY)
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(buyCount > 0)
   {
      // Count profit grid orders by checking comment (more reliable than price comparison)
      int profitGridCount = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  string comment = PositionGetString(POSITION_COMMENT);
                  if(StringFind(comment, "Grid Profit") >= 0)
                     profitGridCount++;
               }
            }
         }
      }
      
      if(profitGridCount < InpGridProfitMaxTrades)
      {
         // Check new candle requirement
         if(InpGridProfitNewCandle && currentBarTime == LastGridBuyTime)
            return;
         
         // Check signal requirement
         if(InpGridProfitOnlySignal && !IsTradeAllowed("BUY"))
            return;
          
          // Get initial order price and last buy price
          double initialBuyPrice = GetFirstPositionPrice(POSITION_TYPE_BUY);
          double lastBuyPrice = GetLastPositionPrice(POSITION_TYPE_BUY);
          int distance = GetGridDistance(false, profitGridCount);
          
          // Grid Profit only triggers when:
          // 1. Current price is ABOVE initial order price (profit zone for BUY)
          // 2. Price went UP from last buy by grid distance
          if(currentPrice > initialBuyPrice && currentPrice - lastBuyPrice >= distance * _Point)
          {
            // Grid Profit uses gridLevel starting from 1 (Initial Order is the base)
            // profitGridCount=0 means first Grid Profit order, which should use level 1
            double lot = GetGridLotSize(false, profitGridCount + 1);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            Print("Grid Profit BUY #", profitGridCount, " | Lot: ", lot, " | Distance: ", distance);
            
            if(trade.Buy(lot, _Symbol, price, 0, 0, "Grid Profit BUY #" + IntegerToString(profitGridCount)))
            {
               LastGridBuyTime = currentBarTime;
            }
         }
      }
   }
   
   // Check SELL Grid Profit (when price goes down = profit side for SELL)
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(sellCount > 0)
   {
      // Count profit grid orders by checking comment (more reliable than price comparison)
      int profitGridCount = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                  string comment = PositionGetString(POSITION_COMMENT);
                  if(StringFind(comment, "Grid Profit") >= 0)
                     profitGridCount++;
               }
            }
         }
      }
      
      if(profitGridCount < InpGridProfitMaxTrades)
      {
         // Check new candle requirement
         if(InpGridProfitNewCandle && currentBarTime == LastGridSellTime)
            return;
         
         // Check signal requirement
         if(InpGridProfitOnlySignal && !IsTradeAllowed("SELL"))
            return;
          
          // Get initial order price and last sell price
          double initialSellPrice = GetFirstPositionPrice(POSITION_TYPE_SELL);
          double lastSellPrice = GetLastPositionPrice(POSITION_TYPE_SELL);
          int distance = GetGridDistance(false, profitGridCount);
          
          // Grid Profit only triggers when:
          // 1. Current price is BELOW initial order price (profit zone for SELL)
          // 2. Price went DOWN from last sell by grid distance
          if(currentPrice < initialSellPrice && lastSellPrice - currentPrice >= distance * _Point)
          {
            // Grid Profit uses gridLevel starting from 1 (Initial Order is the base)
            // profitGridCount=0 means first Grid Profit order, which should use level 1
            double lot = GetGridLotSize(false, profitGridCount + 1);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            Print("Grid Profit SELL #", profitGridCount, " | Lot: ", lot, " | Distance: ", distance);
            
            if(trade.Sell(lot, _Symbol, price, 0, 0, "Grid Profit SELL #" + IntegerToString(profitGridCount)))
            {
               LastGridSellTime = currentBarTime;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ================== NEWS FILTER FUNCTIONS ======================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Chart Base Currency (e.g., EURUSD -> EUR)                      |
//+------------------------------------------------------------------+
string GetChartBaseCurrency()
{
   string symbol = _Symbol;
   // Most pairs have 6 chars: EURUSD, GBPJPY, etc.
   // Some have suffixes like EURUSDm, EURUSD.i, etc.
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 0, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Get Chart Quote Currency (e.g., EURUSD -> USD)                     |
//+------------------------------------------------------------------+
string GetChartQuoteCurrency()
{
   string symbol = _Symbol;
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 3, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Check if Currency is Relevant for News Filter                      |
//+------------------------------------------------------------------+
bool IsCurrencyRelevant(string newsCurrency)
{
   // If using chart currency filter
   if(InpNewsUseChartCurrency)
   {
      string baseCurrency = GetChartBaseCurrency();
      string quoteCurrency = GetChartQuoteCurrency();
      
      if(newsCurrency == baseCurrency || newsCurrency == quoteCurrency)
         return true;
      return false;
   }
   
   // If using manual currency list
   string currencies = InpNewsCurrencies;
   if(StringLen(currencies) == 0)
      return false;
   
   // Parse semicolon-separated list
   string currencyList[];
   int count = StringSplit(currencies, ';', currencyList);
   
   for(int i = 0; i < count; i++)
   {
      string curr = currencyList[i];
      StringTrimLeft(curr);
      StringTrimRight(curr);
      if(curr == newsCurrency)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if News Title Matches Custom Keywords                        |
//+------------------------------------------------------------------+
bool IsCustomNewsMatch(string newsTitle)
{
   if(!InpFilterCustomNews)
      return false;
   
   string keywords = InpCustomNewsKeywords;
   if(StringLen(keywords) == 0)
      return false;
   
   // Parse semicolon-separated keywords
   string keywordList[];
   int count = StringSplit(keywords, ';', keywordList);
   
   // Convert news title to uppercase for case-insensitive matching
   string upperTitle = newsTitle;
   StringToUpper(upperTitle);
   
   for(int i = 0; i < count; i++)
   {
      string keyword = keywordList[i];
      StringTrimLeft(keyword);
      StringTrimRight(keyword);
      StringToUpper(keyword);
      
      if(StringLen(keyword) > 0 && StringFind(upperTitle, keyword) >= 0)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Parse News Time from ForexFactory format (MM-DD-YYYY, hh:mmap)     |
//+------------------------------------------------------------------+
datetime ParseNewsTime(string dateStr, string timeStr)
{
   // Clean CDATA whitespace
   StringTrimLeft(dateStr);
   StringTrimRight(dateStr);
   StringTrimLeft(timeStr);
   StringTrimRight(timeStr);
   
   // Parse date: MM-DD-YYYY
   string dateParts[];
   int datePartCount = StringSplit(dateStr, '-', dateParts);
   if(datePartCount < 3) return 0;
   
   int month = (int)StringToInteger(dateParts[0]);
   int day = (int)StringToInteger(dateParts[1]);
   int year = (int)StringToInteger(dateParts[2]);
   
   // Parse time: hh:mmap (e.g., "3:00pm", "11:50pm")
   int hour = 0;
   int minute = 0;
   
   // Find am/pm
   string lowerTime = timeStr;
   StringToLower(lowerTime);
   bool isPM = StringFind(lowerTime, "pm") >= 0;
   bool isAM = StringFind(lowerTime, "am") >= 0;
   
   // Remove am/pm
   StringReplace(lowerTime, "pm", "");
   StringReplace(lowerTime, "am", "");
   StringTrimRight(lowerTime);
   
   // Parse hour:minute
   string timeParts[];
   int timePartCount = StringSplit(lowerTime, ':', timeParts);
   if(timePartCount >= 1)
   {
      hour = (int)StringToInteger(timeParts[0]);
      if(timePartCount >= 2)
         minute = (int)StringToInteger(timeParts[1]);
   }
   
   // Convert to 24-hour format
   if(isPM && hour < 12) hour += 12;
   if(isAM && hour == 12) hour = 0;
   
   // Build datetime
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Extract text from JSON element (format: "key":"value")             |
//| สำหรับ ForexFactory JSON API                                        |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   // Supports both:
   // 1) "key":"value" (string)
   // 2) "key":123 / true / false / null (primitive)

   string quote = "\\"";
   string searchKey = quote + key + quote + ":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";

   startPos += StringLen(searchKey);

   // Skip whitespace
   while(startPos < StringLen(json) && StringSubstr(json, startPos, 1) == " ")
      startPos++;

   if(startPos >= StringLen(json)) return "";

   string firstChar = StringSubstr(json, startPos, 1);
   string value = "";

   // Quoted string
   if(firstChar == quote)
   {
      startPos++;
      int endPos = StringFind(json, quote, startPos);
      if(endPos < 0) return "";

      value = StringSubstr(json, startPos, endPos - startPos);

      // Unescape JSON special characters
      StringReplace(value, "\\\\/", "/");
      StringReplace(value, "\\\\\\"", "\\"");
      StringReplace(value, "\\\\n", "\\n");
   }
   else
   {
      // Primitive value: read until comma or closing brace/bracket
      int endPos = startPos;
      while(endPos < StringLen(json))
      {
         string c = StringSubstr(json, endPos, 1);
         if(c == "," || c == "}" || c == "]")
            break;
         endPos++;
      }

      value = StringSubstr(json, startPos, endPos - startPos);
   }

   StringTrimLeft(value);
   StringTrimRight(value);

   return value;
}

//+------------------------------------------------------------------+
//| Parse ISO 8601 DateTime (format: 2025-12-30T14:00:00-05:00)        |
//| Converts to MT5 server time correctly using server GMT offset      |
//+------------------------------------------------------------------+
datetime ParseISODateTime(string isoDate)
{
   // Format: "2025-12-30T14:00:00-05:00"
   if(StringLen(isoDate) < 19) return 0;
   
   // Extract date parts
   int year = (int)StringToInteger(StringSubstr(isoDate, 0, 4));
   int month = (int)StringToInteger(StringSubstr(isoDate, 5, 2));
   int day = (int)StringToInteger(StringSubstr(isoDate, 8, 2));
   int hour = (int)StringToInteger(StringSubstr(isoDate, 11, 2));
   int minute = (int)StringToInteger(StringSubstr(isoDate, 14, 2));
   int second = (int)StringToInteger(StringSubstr(isoDate, 17, 2));
   
   // Create datetime (this is in the event's local timezone)
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = second;
   
   datetime eventTime = StructToTime(dt);
   
   // Handle timezone offset (e.g., -05:00 means Eastern Time)
   // We need to convert to UTC first, then to MT5 server time
   if(StringLen(isoDate) >= 25)
   {
      string tzSign = StringSubstr(isoDate, 19, 1);
      int tzHour = (int)StringToInteger(StringSubstr(isoDate, 20, 2));
      int tzMin = (int)StringToInteger(StringSubstr(isoDate, 23, 2));
      int tzOffsetSeconds = (tzHour * 3600) + (tzMin * 60);
      
      // Convert from event timezone to UTC:
      // If event is at -05:00 (EST), we ADD 5 hours to get UTC
      // If event is at +02:00 (EET), we SUBTRACT 2 hours to get UTC
      if(tzSign == "-")
         eventTime += tzOffsetSeconds;
      else if(tzSign == "+")
         eventTime -= tzOffsetSeconds;
      
      // Now eventTime is in UTC
      // Calculate MT5 server offset from UTC: ServerTime - GMT
      // TimeGMT() returns current UTC time, TimeCurrent() returns server time
      int serverGMTOffset = (int)(TimeCurrent() - TimeGMT());
      
      // Convert UTC to server time
      eventTime += serverGMTOffset;
      
      // Debug: Print timezone conversion details (only first time per init)
      static bool debugPrinted = false;
      if(!debugPrinted)
      {
         Print("NEWS FILTER TZ DEBUG: Server GMT offset = ", serverGMTOffset / 3600, " hours (", serverGMTOffset, " sec)");
         Print("NEWS FILTER TZ DEBUG: TimeGMT() = ", TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS));
         Print("NEWS FILTER TZ DEBUG: TimeCurrent() = ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
         debugPrinted = true;
      }
   }
   
   return eventTime;
}

//+------------------------------------------------------------------+
//| Check if WebRequest is properly configured for News Filter         |
//| Tests by making a small request to the news URL                    |
//| Returns true if WebRequest works, false otherwise                  |
//+------------------------------------------------------------------+
bool CheckWebRequestConfiguration()
{
   if(!InpEnableNewsFilter)
   {
      g_webRequestConfigured = true;  // Not needed, so "configured"
      return true;
   }
   
   Print("NEWS FILTER: Checking WebRequest configuration...");
   
   // *** USE MONEYX API ENDPOINT INSTEAD OF EXTERNAL SOURCE ***
   string testUrl = InpLicenseServer + "/functions/v1/economic-news?limit=1";
   char postData[], resultData[];
   string headers = "";
   string resultHeaders;
   int timeout = 5000;  // 5 seconds for quick test
   
   // Reset error before test
   ResetLastError();
   
   int result = WebRequest("GET", testUrl, headers, timeout, postData, resultData, resultHeaders);
   
   if(result == -1)
   {
      int error = GetLastError();
      
      // Error 4060 = WebRequest not enabled in settings
      // Error 4024 = URL not in allowed list
      // Error 5203 = Connection failed / network error
      
      if(error == 4060)
      {
         Print("NEWS FILTER ERROR [4060]: WebRequest is NOT enabled in MT5 settings!");
         g_webRequestConfigured = false;
         return false;
      }
      else if(error == 4024)
      {
         Print("NEWS FILTER ERROR [4024]: URL is NOT in the allowed WebRequest list!");
         g_webRequestConfigured = false;
         return false;
      }
      else
       {
          Print("NEWS FILTER ERROR [", error, "]: WebRequest failed - possibly network issue");
          // Network errors shouldn't trigger the setup alert
          // Only true configuration errors (4060, 4024) should mark as not configured
          // For network errors, assume configured and let RefreshNewsData try anyway
          if(error == 5203 || error == 5200 || error == 5201)
          {
             Print("NEWS FILTER: Network error detected - WebRequest is configured, will retry in RefreshNewsData");
             g_webRequestConfigured = true;  // Assume configured for network errors
             return true;  // Let RefreshNewsData handle the actual fetch with retry
          }
          // Other unknown errors - don't change configuration status
          Print("NEWS FILTER: Unknown error - will retry later");
          return g_webRequestConfigured;
       }
   }
   
   // Success!
   g_webRequestConfigured = true;
   Print("NEWS FILTER: WebRequest is properly configured! ✓");
   return true;
}

//+------------------------------------------------------------------+
//| Show WebRequest Setup Alert with Instructions                      |
//| Displays a MessageBox with step-by-step instructions               |
//+------------------------------------------------------------------+
void ShowWebRequestSetupAlert()
{
   string alertTitle = "NEWS FILTER: WebRequest Configuration Required!";
   
   string alertMessage = 
      "⚠️ News Filter cannot fetch data because WebRequest is not configured.\\n\\n"
      "กรุณาตั้งค่า WebRequest ตามขั้นตอนนี้:\\n\\n"
      "=== STEP-BY-STEP GUIDE ===\\n\\n"
      "1. เปิด MT5 ไปที่ Tools → Options\\n"
      "   (หรือกด Ctrl+O เพื่อเปิด Options โดยตรง)\\n\\n"
      "2. ไปที่แท็บ 'Expert Advisors'\\n\\n"
      "3. ติ๊กเปิด ☑ 'Allow WebRequest for listed URL:'\\n\\n"
      "4. คลิกปุ่ม 'Add new URL' และเพิ่ม:\\n"
      "   " + InpLicenseServer + "\\n\\n"
      "5. คลิก OK แล้ว RESTART EA\\n"
      "   (ถอด EA ออกจากชาร์ตแล้วใส่ใหม่)\\n\\n"
      "=========================\\n\\n"
      "📌 URL ที่ต้องเพิ่ม: " + InpLicenseServer + "\\n\\n"
      "หมายเหตุ: ใช้ URL เดียวกับ License Server\\n"
      "ระบบจะแจ้งเตือนซ้ำทุก 1 ชั่วโมงจนกว่าจะตั้งค่าเสร็จ";
   
   // Show MessageBox with OK button
   // MB_OK | MB_ICONWARNING = 0x30
   MessageBox(alertMessage, alertTitle, 0x30);
   
   // Also print to journal for reference
   Print("========================================");
   Print("NEWS FILTER: WebRequest NOT CONFIGURED!");
   Print("URL Required: ", InpLicenseServer);
   Print("Go to: Tools -> Options -> Expert Advisors");
   Print("Enable: Allow WebRequest for listed URL");
   Print("Add URL: ", InpLicenseServer);
   Print("Then RESTART the EA");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Fetch and Parse News from ForexFactory XML                         |
//+------------------------------------------------------------------+

void RefreshNewsData()
{
   if(!InpEnableNewsFilter)
      return;
   
   datetime currentTime = TimeCurrent();
   
   // *** CHECK HOURLY LIMIT FIRST - before any logging ***
   // Use g_forceNewsRefresh to bypass on first call from OnInit
   // IMPORTANT: Only set g_lastNewsRefresh AFTER successful load
   if(!g_forceNewsRefresh && g_lastNewsRefresh > 0 && (currentTime - g_lastNewsRefresh) < 3600)
      return;  // Already refreshed within last hour - exit silently
   
   // Reset force flag after use
   g_forceNewsRefresh = false;
   
   // *** DO NOT set g_lastNewsRefresh here - only on SUCCESS ***
   Print("NEWS FILTER: Refreshing news data from MoneyX API...");
   
   // Get current week string for URL
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // *** USE MONEYX API ENDPOINT INSTEAD OF EXTERNAL SOURCE ***
   // Build URL with filters based on user settings
   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      // Get chart symbol currencies (e.g., XAUUSD -> XAU,USD)
      string sym = Symbol();
      if(StringLen(sym) >= 6)
      {
         currencies = StringSubstr(sym, 0, 3) + "," + StringSubstr(sym, 3, 3);
      }
   }
   else
   {
      // Use user-defined currencies (convert ; to , for API)
      currencies = InpNewsCurrencies;
      StringReplace(currencies, ";", ",");
   }
   
   // Build impact filter string
   string impacts = "";
   if(InpFilterHighNews) impacts += "High,";
   if(InpFilterMedNews) impacts += "Medium,";
   if(InpFilterLowNews) impacts += "Low,";
   if(StringLen(impacts) > 0)
      impacts = StringSubstr(impacts, 0, StringLen(impacts) - 1);  // Remove trailing comma
   
   // Construct API URL with cache-busting timestamp
   string apiUrl = InpLicenseServer + "/functions/v1/economic-news?ts=" + IntegerToString((long)currentTime);
   if(StringLen(currencies) > 0)
      apiUrl += "&currency=" + currencies;
   if(StringLen(impacts) > 0)
      apiUrl += "&impact=" + impacts;
   
   // Use WebRequest to fetch JSON with proper headers
   char postData[], resultData[];
   string headers = "User-Agent: MoneyX-EA/5.1\\r\\nAccept: application/json\\r\\nConnection: close";
   string resultHeaders;
   
   int timeout = 10000;  // 10 seconds for reliable fetch
   
   Print("NEWS FILTER: Fetching from ", apiUrl);
   
   int result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   
   // *** RETRY MECHANISM: If first attempt fails, try once more ***
   if(result == -1)
   {
      int firstError = GetLastError();
      Print("NEWS FILTER: First attempt failed (error ", firstError, "), retrying after 1 second...");
      Sleep(1000);  // Wait 1 second before retry
      ResetLastError();
      result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   }
   
   if(result == -1)
   {
      int error = GetLastError();
      Print("NEWS FILTER ERROR: WebRequest failed - Error ", error);
      
      // If error indicates configuration issue, mark as not configured
      if(error == 4060 || error == 4024)
      {
         g_webRequestConfigured = false;
      }
      
      // *** KEEP EXISTING CACHE - do not clear ***
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events from ", TimeToString(g_lastGoodNewsTime), ")");
      }
      // *** SET RETRY DELAY - wait 5 minutes before retrying on WebRequest failure ***
      g_lastNewsRefresh = currentTime - 3300;  // Will allow retry in 5 minutes (3600-3300=300 sec)
      return;
   }
   
   // *** CHECK HTTP STATUS CODE ***
   // result contains HTTP status code (200=OK, 401=Unauthorized, etc.)
   if(result != 200)
   {
      Print("NEWS FILTER ERROR: HTTP ", result, " - Server returned error");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events)");
      }
      // *** SET RETRY DELAY - wait 5 minutes before retrying on HTTP error ***
      g_lastNewsRefresh = currentTime - 3300;  // Will allow retry in 5 minutes
      return;
   }
   
   // *** DEBUG: Log response info ***
   int responseSize = ArraySize(resultData);
   Print("NEWS FILTER DEBUG: HTTP Result = ", result, ", Response size = ", responseSize, " bytes");
   
   // Convert to string - UTF-8 encoding for JSON
   string jsonContent = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   
   // *** DEBUG: Log first part of content ***
   Print("NEWS FILTER DEBUG: First 300 chars of response:");
   Print(StringSubstr(jsonContent, 0, 300));
   
   // *** VALIDATION: Check if response is valid JSON array ***
   if(responseSize < 10)
   {
      Print("NEWS FILTER WARNING: Response too short (", responseSize, " bytes) - may be error page");
      // Keep existing cache
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      return;
   }
   
   // Check if we got valid JSON response
   string trimmedContent = jsonContent;
   StringTrimLeft(trimmedContent);
   
   // *** MoneyX API returns { success: true, count: X, data: [...] } format ***
   // Check if we got a valid response object
   if(StringSubstr(trimmedContent, 0, 1) != "{")
   {
      Print("NEWS FILTER WARNING: Response is not a JSON object!");
      Print("NEWS FILTER DEBUG: Response starts with: ", StringSubstr(trimmedContent, 0, 50));
      Print("NEWS FILTER DEBUG: Response headers: ", resultHeaders);
      // Keep existing cache
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      return;
   }
   
   // Check for success field
   string successValue = ExtractJSONValue(jsonContent, "success");
   if(successValue != "true")
   {
      string errorMsg = ExtractJSONValue(jsonContent, "error");
      Print("NEWS FILTER ERROR: API returned error: ", errorMsg);
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      return;
   }
   
   // *** USE TEMPORARY VARIABLES FOR PARSING ***
   // Only update global data if parsing succeeds
   NewsEvent tmpEvents[];
   int tmpEventCount = 0;
   ArrayResize(tmpEvents, 100);  // Pre-allocate for 100 events
   
   // Find the data array
   int dataStart = StringFind(jsonContent, "\\"data\\":", 0);
   if(dataStart < 0)
   {
      Print("NEWS FILTER WARNING: No data array found in response!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      return;
   }
   
   // Find the start of the array [
   int arrayStart = StringFind(jsonContent, "[", dataStart);
   if(arrayStart < 0)
   {
      Print("NEWS FILTER WARNING: Data array not found!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      return;
   }
   
   int searchPos = arrayStart + 1;
   int eventCount = 0;
   
    // Find first { in the data array
    int firstBrace = StringFind(jsonContent, "{", searchPos);
    if(firstBrace < 0)
    {
       // *** EMPTY DATA ARRAY IS A VALID RESPONSE - NOT AN ERROR ***
       // API returned success:true with data:[] meaning no news matching filters
       // This is a successful refresh - mark as complete to prevent per-tick spam
       Print("NEWS FILTER: No news events for current filters (empty data array)");
       g_lastNewsRefresh = currentTime;  // CRITICAL: Mark refresh as successful!
       
       if(g_newsEventCount > 0)
       {
          g_usingCachedNews = true;
          Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events) - Next refresh in 1 hour");
       }
       else
       {
          // No cache either - this is fine, just means no relevant news
          g_usingCachedNews = false;
          Print("NEWS FILTER: No relevant news and no cache - Next refresh in 1 hour");
       }
       return;
    }
    
    searchPos = firstBrace;
   
   while(searchPos < StringLen(jsonContent))
   {
      // Find end of current object
      int braceDepth = 0;
      int objStart = searchPos;
      int objEnd = -1;
      
      for(int i = searchPos; i < StringLen(jsonContent); i++)
      {
         string c = StringSubstr(jsonContent, i, 1);
         if(c == "{") braceDepth++;
         else if(c == "}")
         {
            braceDepth--;
            if(braceDepth == 0)
            {
               objEnd = i;
               break;
            }
         }
         // Stop at end of array
         else if(c == "]" && braceDepth == 0)
         {
            break;
         }
      }
      
      if(objEnd < 0) break;
      
      string eventJson = StringSubstr(jsonContent, objStart, objEnd - objStart + 1);
      
      // *** Extract event data from MoneyX API format ***
      // API returns: title, currency, timestamp (Unix), impact, forecast, previous
      string title = ExtractJSONValue(eventJson, "title");
      string currency = ExtractJSONValue(eventJson, "currency");  // API uses 'currency' not 'country'
      string timestampStr = ExtractJSONValue(eventJson, "timestamp");  // Unix timestamp
      string impact = ExtractJSONValue(eventJson, "impact");
      
      // *** DEBUG: Log first 5 events parsed ***
      if(eventCount < 5)
      {
         Print("NEWS FILTER DEBUG: Event #", eventCount + 1);
         Print("  Title: ", title);
         Print("  Currency: ", currency);
         Print("  Timestamp: ", timestampStr);
         Print("  Impact: ", impact);
      }
      eventCount++;
      
      // *** Parse Unix timestamp (convert to datetime) ***
      datetime eventTime = (datetime)StringToInteger(timestampStr);
      
      // Skip holidays (impact == "Holiday")
      if(impact == "Holiday")
      {
         searchPos = objEnd + 1;
         continue;
      }
      
      // Check if this event is relevant
      bool isRelevant = false;
      
      if(IsCurrencyRelevant(currency))
      {
         // Check impact filters
         if(InpFilterHighNews && impact == "High")
            isRelevant = true;
         else if(InpFilterMedNews && impact == "Medium")
            isRelevant = true;
         else if(InpFilterLowNews && impact == "Low")
            isRelevant = true;
         
         // Check custom keywords
         if(IsCustomNewsMatch(title))
            isRelevant = true;
      }
      
      // Store event in TEMPORARY array
      if(tmpEventCount < ArraySize(tmpEvents))
      {
         tmpEvents[tmpEventCount].title = title;
         tmpEvents[tmpEventCount].country = currency;  // Store currency as country
         tmpEvents[tmpEventCount].time = eventTime;
         tmpEvents[tmpEventCount].impact = impact;
         tmpEvents[tmpEventCount].isRelevant = isRelevant;
         tmpEventCount++;
      }
      
      searchPos = objEnd + 1;
   }
   
   Print("NEWS FILTER: Parsed ", eventCount, " total events, stored ", tmpEventCount, " events");
   
   // *** SUCCESS - Now update global data ***
   if(tmpEventCount > 0)
   {
      // Copy temporary data to global arrays
      ArrayResize(g_newsEvents, tmpEventCount);
      for(int i = 0; i < tmpEventCount; i++)
      {
         g_newsEvents[i] = tmpEvents[i];
      }
      g_newsEventCount = tmpEventCount;
      
      // Mark as fresh data
      g_lastNewsRefresh = currentTime;
      g_lastGoodNewsTime = currentTime;
      g_usingCachedNews = false;
      
      Print("NEWS FILTER: Successfully loaded ", g_newsEventCount, " events (FRESH DATA)");
      
      // Save to file cache for persistence
      SaveNewsCacheToFile();
   }
   else
   {
      // API returned 0 events - keep existing cache but DO NOT spam refresh
      Print("NEWS FILTER: API returned 0 events (no relevant news for current filters)");
      g_lastNewsRefresh = currentTime;  // Mark refresh as successful to prevent per-tick spam
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      else
      {
         // No cache either - this is still a valid state
         g_usingCachedNews = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Save News Cache to File for Persistence                            |
//+------------------------------------------------------------------+
void SaveNewsCacheToFile()
{
   if(g_newsEventCount == 0)
      return;
   
   int handle = FileOpen(g_newsCacheFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot save cache file - ", GetLastError());
      return;
   }
   
   // Write header with timestamp
   FileWriteString(handle, "# MoneyX News Cache - " + TimeToString(TimeCurrent()) + "\\n");
   FileWriteString(handle, "# Count: " + IntegerToString(g_newsEventCount) + "\\n");
   
   // Write events as simple delimited format
   for(int i = 0; i < g_newsEventCount; i++)
   {
      string line = g_newsEvents[i].title + "|" + 
                    g_newsEvents[i].country + "|" +
                    IntegerToString((long)g_newsEvents[i].time) + "|" +
                    g_newsEvents[i].impact + "|" +
                    (g_newsEvents[i].isRelevant ? "1" : "0") + "\\n";
      FileWriteString(handle, line);
   }
   
   FileClose(handle);
   g_lastFileCacheSave = TimeCurrent();
   Print("NEWS FILTER: Saved ", g_newsEventCount, " events to cache file");
}

//+------------------------------------------------------------------+
//| Load News Cache from File                                          |
//+------------------------------------------------------------------+
void LoadNewsCacheFromFile()
{
   if(!FileIsExist(g_newsCacheFile))
   {
      Print("NEWS FILTER: No cache file found (first run)");
      return;
   }
   
   int handle = FileOpen(g_newsCacheFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot read cache file - ", GetLastError());
      return;
   }
   
   // Clear and prepare array
   ArrayResize(g_newsEvents, 100);
   g_newsEventCount = 0;
   
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      
      // Skip comment lines
      if(StringSubstr(line, 0, 1) == "#")
         continue;
      
      // Parse delimited line: title|country|time|impact|isRelevant
      string parts[];
      int partCount = StringSplit(line, '|', parts);
      
      if(partCount >= 5 && g_newsEventCount < ArraySize(g_newsEvents))
      {
         g_newsEvents[g_newsEventCount].title = parts[0];
         g_newsEvents[g_newsEventCount].country = parts[1];
         g_newsEvents[g_newsEventCount].time = (datetime)StringToInteger(parts[2]);
         g_newsEvents[g_newsEventCount].impact = parts[3];
         g_newsEvents[g_newsEventCount].isRelevant = (parts[4] == "1");
         g_newsEventCount++;
      }
   }
   
   FileClose(handle);
   
   if(g_newsEventCount > 0)
   {
      g_usingCachedNews = true;
      Print("NEWS FILTER: Loaded ", g_newsEventCount, " events from cache file");
   }
}

//+------------------------------------------------------------------+
//| Get Pause Duration for News Impact Level                           |
//| NOTE: If news matches BOTH Custom and Impact filters, use the      |
//| one with LARGER pause window (longer before+after total)           |
//+------------------------------------------------------------------+
void GetNewsPauseDuration(string impact, bool isCustomMatch, int &beforeMin, int &afterMin)
{
   beforeMin = 0;
   afterMin = 0;
   
   int customBefore = 0, customAfter = 0;
   int impactBefore = 0, impactAfter = 0;
   
   // Check Custom news timing
   if(isCustomMatch && InpFilterCustomNews)
   {
      customBefore = InpPauseBeforeCustom;
      customAfter = InpPauseAfterCustom;
   }
   
   // Check Impact-based timing
   if(impact == "High" && InpFilterHighNews)
   {
      impactBefore = InpPauseBeforeHigh;
      impactAfter = InpPauseAfterHigh;
   }
   else if(impact == "Medium" && InpFilterMedNews)
   {
      impactBefore = InpPauseBeforeMed;
      impactAfter = InpPauseAfterMed;
   }
   else if(impact == "Low" && InpFilterLowNews)
   {
      impactBefore = InpPauseBeforeLow;
      impactAfter = InpPauseAfterLow;
   }
   
   // *** CHOOSE THE LARGER PAUSE WINDOW ***
   // Compare total pause duration (before + after) and use the larger one
   int customTotal = customBefore + customAfter;
   int impactTotal = impactBefore + impactAfter;
   
   if(customTotal >= impactTotal && customTotal > 0)
   {
      beforeMin = customBefore;
      afterMin = customAfter;
   }
   else if(impactTotal > 0)
   {
      beforeMin = impactBefore;
      afterMin = impactAfter;
   }
}

//+------------------------------------------------------------------+
//| Check whether an event is relevant using CURRENT filter settings   |
//| (Do NOT rely on cached event.isRelevant because users can toggle   |
//| filters at runtime / after cached load)                             |
//+------------------------------------------------------------------+
bool IsEventRelevantNow(const NewsEvent &ev)
{
   if(!IsCurrencyRelevant(ev.country))
      return false;

   // Custom keyword match is independent from impact filters
   if(InpFilterCustomNews && IsCustomNewsMatch(ev.title))
      return true;

   if(InpFilterHighNews && ev.impact == "High")
      return true;

   if(InpFilterMedNews && ev.impact == "Medium")
      return true;

   if(InpFilterLowNews && ev.impact == "Low")
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if Currently in News Pause Window                            |
//+------------------------------------------------------------------+
bool IsNewsTimePaused()
{
   if(!InpEnableNewsFilter)
   {
      g_isNewsPaused = false;
      g_newsStatus = "OFF";
      // Reset log spam prevention when disabled
      if(g_lastPausedState)
      {
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      return false;
   }
   
   datetime currentTime = TimeCurrent();
   
   bool foundPause = false;
   string pauseKey = "";
   g_nextNewsTitle = "";
   g_nextNewsTime = 0;
   
   // Find the next/current relevant news
   datetime closestNewsTime = 0;
   string closestNewsTitle = "";
   int closestBeforeMin = 0;
   int closestAfterMin = 0;
   
   // *** PRIORITY LOGIC: Find news with EARLIEST resume time (pauseEnd) ***
   datetime earliestPauseEnd = 0;
   string earliestNewsTitle = "";
   datetime earliestNewsTime = 0;
   string earliestCountry = "";
   string earliestImpact = "";
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      // IMPORTANT: recompute relevance using CURRENT filter settings
      // (cached isRelevant can be stale after user toggles filters)
      if(!IsEventRelevantNow(g_newsEvents[i]))
         continue;

      datetime newsTime = g_newsEvents[i].time;
      string impact = g_newsEvents[i].impact;
      bool isCustom = IsCustomNewsMatch(g_newsEvents[i].title);
      
      int beforeMin, afterMin;
      GetNewsPauseDuration(impact, isCustom, beforeMin, afterMin);
      
      if(beforeMin == 0 && afterMin == 0)
         continue;
      
      // Calculate pause window
      datetime pauseStart = newsTime - beforeMin * 60;
      datetime pauseEnd = newsTime + afterMin * 60;
      
      // Check if current time is within pause window
      if(currentTime >= pauseStart && currentTime <= pauseEnd)
      {
         // *** Choose the news with EARLIEST pauseEnd (resume soonest) ***
         if(!foundPause || pauseEnd < earliestPauseEnd)
         {
            foundPause = true;
            earliestPauseEnd = pauseEnd;
            earliestNewsTitle = g_newsEvents[i].title;
            earliestNewsTime = newsTime;
            earliestCountry = g_newsEvents[i].country;
            earliestImpact = impact;
         }
      }
      
      // Track closest upcoming news for dashboard display (not yet paused)
      if(newsTime > currentTime && (closestNewsTime == 0 || newsTime < closestNewsTime))
      {
         datetime futureStart = newsTime - beforeMin * 60;
         if(currentTime < futureStart)  // Not yet in pause window
         {
            closestNewsTime = newsTime;
            closestNewsTitle = g_newsEvents[i].title;
            closestBeforeMin = beforeMin;
            closestAfterMin = afterMin;
         }
      }
   }
   
   // *** Set the selected pause info ***
   if(foundPause)
   {
      g_nextNewsTitle = earliestNewsTitle;
      g_nextNewsTime = earliestNewsTime;
      g_newsPauseEndTime = earliestPauseEnd;
      pauseKey = earliestNewsTitle + "|" + IntegerToString((long)earliestNewsTime);
      
      // Determine status text
      if(currentTime < earliestNewsTime)
      {
         int minsLeft = (int)((earliestNewsTime - currentTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " in " + IntegerToString(minsLeft) + "m";
      }
      else
      {
         int minsAfter = (int)((currentTime - earliestNewsTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " +" + IntegerToString(minsAfter) + "m ago";
      }
   }
   
   // *** LOG SPAM PREVENTION - Only print when status CHANGES ***
   if(foundPause)
   {
      g_isNewsPaused = true;
      
      // Only print if this is a NEW pause or different news event
      if(!g_lastPausedState || g_lastPauseKey != pauseKey)
      {
         Print("NEWS FILTER: Trading PAUSED - ", g_newsStatus, " | Event: ", g_nextNewsTitle);
         g_lastPausedState = true;
         g_lastPauseKey = pauseKey;
      }
      return true;
   }
   else
   {
      g_isNewsPaused = false;
      g_newsPauseEndTime = 0;  // Clear pause end time when not paused
      
      // Only print RESUME message if we were previously paused
      if(g_lastPausedState)
      {
         Print("NEWS FILTER: Trading RESUMED - News pause window ended");
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      
      // Show upcoming news if within 2 hours (optional - keep tracking but don't show in dashboard)
      if(closestNewsTime > 0 && (closestNewsTime - currentTime) <= 2 * 3600)
      {
         g_nextNewsTitle = closestNewsTitle;
         g_nextNewsTime = closestNewsTime;
      }
      
      // Always show "No Important news" when not paused
      g_newsStatus = "No Important news";
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Countdown String for News Pause (HH:MM:SS until resume)        |
//+------------------------------------------------------------------+
string GetNewsCountdownString()
{
   if(!g_isNewsPaused || g_newsPauseEndTime == 0)
      return "";
   
   datetime currentTime = TimeCurrent();
   
   if(currentTime >= g_newsPauseEndTime)
      return "00:00:00";
   
   int remainingSeconds = (int)(g_newsPauseEndTime - currentTime);
   
   int hours = remainingSeconds / 3600;
   int minutes = (remainingSeconds % 3600) / 60;
   int seconds = remainingSeconds % 60;
   
   // Format: HH:MM:SS
   string hh = (hours < 10 ? "0" : "") + IntegerToString(hours);
   string mm = (minutes < 10 ? "0" : "") + IntegerToString(minutes);
   string ss = (seconds < 10 ? "0" : "") + IntegerToString(seconds);
   
   return hh + ":" + mm + ":" + ss;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // *** LICENSE CHECK - SKIP IN TESTER MODE ***
   if(!g_isTesterMode)
   {
      if(!OnTickLicense())
      {
         UpdateChartComment("LICENSE", "License Invalid - Trading Disabled");
         return;
      }
   }
   
   // Update Dashboard every tick
   UpdateDashboard();
   
   // *** NEWS FILTER - Refresh data hourly and check pause ***
   RefreshNewsData();  // Called every tick, but only refreshes hourly
   
   // *** ACCUMULATE CLOSE SYSTEM - ทำงานทุก tick ไม่ว่าจะ Pause หรือไม่ ***
   TrackAccumulateProfit();
   if(CheckAccumulateClose())
   {
      return;  // ปิด order แล้ว รอ tick ถัดไป
   }
   
   // Check TP/SL conditions first (every tick) - this still runs even when paused or news filtered
   CheckTPSLConditions();
   
   // Draw TP/SL lines (every tick for real-time update)
   DrawTPSLLines();
   
   // *** EA PAUSE CHECK ***
   // If paused, only TP/SL/Hedge/Accumulate continues to work, no new orders
   if(g_eaIsPaused)
   {
      UpdateChartComment("PAUSED", "EA Paused - No new orders");
      return;
   }
   
   // *** NEWS FILTER PAUSE CHECK ***
   // If news pause is active, skip new orders and grid - but TP/SL/Hedge still work
   if(IsNewsTimePaused())
   {
      UpdateChartComment("NEWS_PAUSE", g_newsStatus);
      // Continue to Grid check but exit before initial order logic
      // Grid is also paused during news
      return;
   }
   
   DrawTPSLLines();
   
   // *** HEDGE LOCK CHECK ***
   // If hedge is active, stop ALL trading activities (no Grid, no new signals)
   if(g_isHedgeLocked)
   {
      UpdateChartComment("HEDGE_LOCKED", "Positions locked - Manual close required");
      return;  // Exit OnTick - no further trading until manual intervention
   }

   // ========== SMC ENTRY CYCLE (NEW LOGIC - PER SIDE) ==========
   // Concept:
   // - OB detection stops ONLY for the side that has open orders
   // - When BUY orders close: reset BUY SMC state only
   // - When SELL orders close: reset SELL SMC state only
   // - Each side is independent
   static int s_prevBuyCount = 0;
   static int s_prevSellCount = 0;
   
   int curBuyCount = CountPositions(POSITION_TYPE_BUY);
   int curSellCount = CountPositions(POSITION_TYPE_SELL);
   
   if(InpSignalStrategy == STRATEGY_SMC)
   {
      // Check if BUY side just became flat (had orders, now zero)
      if(s_prevBuyCount > 0 && curBuyCount == 0)
      {
         // Reset BUY SMC state only
         g_waitBuySignalReset = false;
         g_smcBuyResetRequired = false;
         g_smcBuyResetPhaseComplete = false;
         g_smcBuyTouchedOBPersist = false;
         g_smcBuyTouchedOB = false;
         g_smcBuyTouchedOBName = "";
         g_smcBuyTouchTime = 0;
         g_smcLastBuyOBUsed = "";
         
         // Only clear pending signal if it was BUY
         if(g_pendingSignal == "BUY")
         {
            g_pendingSignal = "NONE";
            g_paWaitCount = 0;
            g_signalTouchTime = 0;
            g_signalBarTime = 0;
         }
         
         Print("*** SMC BUY: Flat detected (BUY positions closed) - waiting for NEW Bullish OB touch ***");
      }
      
      // Check if SELL side just became flat (had orders, now zero)
      if(s_prevSellCount > 0 && curSellCount == 0)
      {
         // Reset SELL SMC state only
         g_waitSellSignalReset = false;
         g_smcSellResetRequired = false;
         g_smcSellResetPhaseComplete = false;
         g_smcSellTouchedOBPersist = false;
         g_smcSellTouchedOB = false;
         g_smcSellTouchedOBName = "";
         g_smcSellTouchTime = 0;
         g_smcLastSellOBUsed = "";
         
         // Only clear pending signal if it was SELL
         if(g_pendingSignal == "SELL")
         {
            g_pendingSignal = "NONE";
            g_paWaitCount = 0;
            g_signalTouchTime = 0;
            g_signalBarTime = 0;
         }
         
         Print("*** SMC SELL: Flat detected (SELL positions closed) - waiting for NEW Bearish OB touch ***");
      }
   }
   
   s_prevBuyCount = curBuyCount;
   s_prevSellCount = curSellCount;
   // ================================================
   
   // Check Grid conditions (every tick for real-time)
   CheckGridLossSide();
   CheckGridProfitSide();
   
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   // *** IMPORTANT: Calculate Indicators FIRST before PA confirmation ***
   // This ensures that SMC OB touch, CDC trend, etc. are already determined
   // before we check for PA confirmation as the final step.
   
   // Calculate CDC Action Zone (higher timeframe)
   CalculateCDC();
   
   // Calculate based on selected Signal Strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG)
   {
      // Calculate ZigZag++ (custom implementation)
      CalculateZigZagPP();
   }
   else if(InpSignalStrategy == STRATEGY_EMA_CHANNEL)
   {
      // Calculate EMA Channel
      CalculateEMAChannel();
   }
   else if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      // Calculate Bollinger Bands
      CalculateBollingerBands();
   }
   else if(InpSignalStrategy == STRATEGY_SMC)
   {
      // Calculate Smart Money Concepts (Order Blocks)
      CalculateSMC();
   }
   
   // *** PRICE ACTION CONFIRMATION CHECK ***
   // Handle pending signals waiting for PA confirmation
   // This runs AFTER indicators are calculated, so we have updated SMC OB touch, CDC trend, etc.
   if(InpUsePAConfirm && g_pendingSignal != "NONE")
   {
      HandlePendingSignal();
   }
   
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      UpdateChartComment("WAIT", "Outside trading hours");
      return;
   }
   
   // Check if we have enough data based on strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG && ZZPointCount < 4)
   {
      UpdateChartComment("WAIT", "Calculating ZigZag...");
      return;
   }
   
   // If we have a pending signal waiting for PA, don't look for new signals
   if(InpUsePAConfirm && g_pendingSignal != "NONE")
   {
      string paInfo = "Waiting PA for " + g_pendingSignal + " (" + IntegerToString(g_paWaitCount) + "/" + IntegerToString(InpPALookback) + ")";
      UpdateChartComment("PA_WAIT", paInfo);
      return;
   }
   
   string signal = AnalyzeSignal();
   string reason = "";
   
   if(signal == "BUY")
   {
      if(CountPositions(POSITION_TYPE_BUY) > 0)
      {
         reason = "BUY position already open";
         signal = "WAIT";
      }
      else if(!IsTradeAllowed("BUY"))
      {
         if(InpTradeMode == TRADE_SELL_ONLY)
            reason = "Trade Mode: SELL ONLY";
         else if(InpUseCDCFilter && CDCTrend != "BULLISH")
            reason = "CDC not Bullish (" + CDCTrend + ") - BUY blocked";
         signal = "WAIT";
      }
      else
      {
         // *** PRICE ACTION CONFIRMATION ***
         if(InpUsePAConfirm)
         {
            // *** IMPORTANT: Do NOT check for old PA patterns ***
            // PA must occur AFTER the signal/OB touch, not before
            // So we always set pending signal and wait for PA to occur on next candle(s)
            
            // Set pending signal - wait for PA to occur AFTER this touch
            g_pendingSignal = "BUY";
            g_signalBarTime = currentBarTime;
            
            // CRITICAL: currentBarTime is the NEW bar open time.
            // The signal/OB touch logically belongs to the previous closed candle (shift=1)
            // (and for SMC we may have an explicit touch timestamp).
            datetime fallbackTouch = iTime(_Symbol, PERIOD_CURRENT, 1);
            g_signalTouchTime = (InpSignalStrategy == STRATEGY_SMC && g_smcBuyTouchTime > 0) ? g_smcBuyTouchTime : fallbackTouch;
            
            g_paWaitCount = 0;
            reason = "BUY signal detected - Waiting for PA confirmation AFTER touch";
            Print(">>> BUY signal stored | TouchTime=", TimeToString(g_signalTouchTime), " | NowBar=", TimeToString(currentBarTime), " - Waiting for Bullish PA AFTER touch...");
            signal = "PA_WAIT";
         }
         else
         {
            if(ExecuteBuy())
               reason = "BUY executed | CDC: " + CDCTrend;
            else
               reason = "BUY failed to execute | CDC: " + CDCTrend;
         }
      }
   }
   else if(signal == "SELL")
   {
      if(CountPositions(POSITION_TYPE_SELL) > 0)
      {
         reason = "SELL position already open";
         signal = "WAIT";
      }
      else if(!IsTradeAllowed("SELL"))
      {
         if(InpTradeMode == TRADE_BUY_ONLY)
            reason = "Trade Mode: BUY ONLY";
         else if(InpUseCDCFilter && CDCTrend != "BEARISH")
            reason = "CDC not Bearish (" + CDCTrend + ") - SELL blocked";
         signal = "WAIT";
      }
      else
      {
         // *** PRICE ACTION CONFIRMATION ***
         if(InpUsePAConfirm)
         {
            // *** IMPORTANT: Do NOT check for old PA patterns ***
            // PA must occur AFTER the signal/OB touch, not before
            // So we always set pending signal and wait for PA to occur on next candle(s)
            
            // Set pending signal - wait for PA to occur AFTER this touch
            g_pendingSignal = "SELL";
            g_signalBarTime = currentBarTime;
            
            // CRITICAL: currentBarTime is the NEW bar open time.
            // The signal/OB touch logically belongs to the previous closed candle (shift=1)
            // (and for SMC we may have an explicit touch timestamp).
            datetime fallbackTouch = iTime(_Symbol, PERIOD_CURRENT, 1);
            g_signalTouchTime = (InpSignalStrategy == STRATEGY_SMC && g_smcSellTouchTime > 0) ? g_smcSellTouchTime : fallbackTouch;
            
            g_paWaitCount = 0;
            reason = "SELL signal detected - Waiting for PA confirmation AFTER touch";
            Print(">>> SELL signal stored | TouchTime=", TimeToString(g_signalTouchTime), " | NowBar=", TimeToString(currentBarTime), " - Waiting for Bearish PA AFTER touch...");
            signal = "PA_WAIT";
         }
         else
         {
            if(ExecuteSell())
               reason = "SELL executed | CDC: " + CDCTrend;
            else
               reason = "SELL failed to execute | CDC: " + CDCTrend;
         }
      }
   }
   
   UpdateChartComment(signal, reason);
}

//+------------------------------------------------------------------+
//| Analyze Signal - Based on Selected Strategy                        |
//+------------------------------------------------------------------+
string AnalyzeSignal()
{
   // Route to the appropriate signal analysis based on strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG)
   {
      return AnalyzeZigZagSignal();
   }
   else if(InpSignalStrategy == STRATEGY_EMA_CHANNEL)
   {
      return AnalyzeEMAChannelSignal();
   }
   else if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      return AnalyzeBollingerSignal();
   }
   else if(InpSignalStrategy == STRATEGY_SMC)
   {
      return AnalyzeSMCSignal();
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Analyze ZigZag Signal                                              |
//+------------------------------------------------------------------+
string AnalyzeZigZagSignal()
{
   if(ZZPointCount < 2)
      return "WAIT";
   
   // Get the newest confirmed ZigZag point (index 0 is newest)
   datetime newestPointTime = ZZPoints[0].time;
   
   // Check if this is a NEW confirmed point
   if(newestPointTime == LastConfirmedZZTime)
   {
      return "WAIT";
   }
   
   // NEW ZigZag point confirmed!
   LastConfirmedZZTime = newestPointTime;
   
   Print("*** NEW ZigZag++ Point Confirmed! ***");
   Print("Label: ", LastZZLabel, " | Time: ", TimeToString(newestPointTime), " | CDC: ", CDCTrend);
   
   // *** UPDATE ZIGZAG SIGNAL RESET STATUS ***
   // For ZigZag: BUY reset requires HH/LH point first, then LL/HL
   // For ZigZag: SELL reset requires LL/HL point first, then HH/LH
   if(g_waitBuySignalReset)
   {
      if(LastZZLabel == "HH" || LastZZLabel == "LH")
      {
         // Opposite signal detected - BUY reset phase 1 complete
         g_buyResetWaitOppositeSignal = false;
         Print("*** BUY Reset Phase 1 Complete - Opposite point (", LastZZLabel, ") detected ***");
      }
   }
   
   if(g_waitSellSignalReset)
   {
      if(LastZZLabel == "LL" || LastZZLabel == "HL")
      {
         // Opposite signal detected - SELL reset phase 1 complete
         g_sellResetWaitOppositeSignal = false;
         Print("*** SELL Reset Phase 1 Complete - Opposite point (", LastZZLabel, ") detected ***");
      }
   }
   
   // BUY Signal: Based on ZigZag Signal Mode
   if(InpZigZagSignalMode == ZIGZAG_BOTH)
   {
      // Both Signals: LL or HL triggers BUY
      if(LastZZLabel == "LL" || LastZZLabel == "HL")
      {
         // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
         if(g_waitBuySignalReset)
         {
            if(g_buyResetWaitOppositeSignal)
            {
               Print(">>> BUY Signal detected but waiting for opposite signal (HH/LH) first");
               return "WAIT";
            }
            else
            {
               // Reset complete - allow this BUY signal
               g_waitBuySignalReset = false;
               Print("*** BUY Signal Reset Complete - Executing new BUY! ***");
            }
         }
         Print(">>> NEW LOW point (", LastZZLabel, ") - Triggering BUY signal! [Both Mode]");
         return "BUY";
      }
      // Both Signals: HH or LH triggers SELL
      if(LastZZLabel == "HH" || LastZZLabel == "LH")
      {
         // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
         if(g_waitSellSignalReset)
         {
            if(g_sellResetWaitOppositeSignal)
            {
               Print(">>> SELL Signal detected but waiting for opposite signal (LL/HL) first");
               return "WAIT";
            }
            else
            {
               // Reset complete - allow this SELL signal
               g_waitSellSignalReset = false;
               Print("*** SELL Signal Reset Complete - Executing new SELL! ***");
            }
         }
         Print(">>> NEW HIGH point (", LastZZLabel, ") - Triggering SELL signal! [Both Mode]");
         return "SELL";
      }
   }
   else // ZIGZAG_SINGLE
   {
      // Single Signal: Only LL triggers BUY
      if(LastZZLabel == "LL")
      {
         // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
         if(g_waitBuySignalReset)
         {
            if(g_buyResetWaitOppositeSignal)
            {
               Print(">>> LL detected but waiting for opposite signal (HH) first");
               return "WAIT";
            }
            else
            {
               g_waitBuySignalReset = false;
               Print("*** BUY Signal Reset Complete - Executing new BUY! ***");
            }
         }
         Print(">>> NEW LL point - Triggering BUY signal! [Single Mode]");
         return "BUY";
      }
      // Single Signal: Only HH triggers SELL
      if(LastZZLabel == "HH")
      {
         // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
         if(g_waitSellSignalReset)
         {
            if(g_sellResetWaitOppositeSignal)
            {
               Print(">>> HH detected but waiting for opposite signal (LL) first");
               return "WAIT";
            }
            else
            {
               g_waitSellSignalReset = false;
               Print("*** SELL Signal Reset Complete - Executing new SELL! ***");
            }
         }
         Print(">>> NEW HH point - Triggering SELL signal! [Single Mode]");
         return "SELL";
      }
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Check and Update Signal Reset Status for EMA Strategy              |
//| Returns true if signal is allowed (reset complete or not required) |
//+------------------------------------------------------------------+
void UpdateEMASignalResetStatus()
{
   // Get current price relative to EMA
   int signalBar = (InpEMASignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpEMATimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // *** BUY SIGNAL RESET CHECK ***
   // Step 1: Price must close BELOW any EMA line (either one)
   // Step 2: Price must then close ABOVE both EMA lines again
   if(g_waitBuySignalReset)
   {
      bool nowBelowAny = (signalClose < EMAHigh || signalClose < EMALow);
      bool nowAboveBoth = (signalClose > EMAHigh && signalClose > EMALow);
      
      if(!g_buyResetPhaseBelowEMA && nowBelowAny)
      {
         // Step 1 complete: Price closed below any EMA line
         g_buyResetPhaseBelowEMA = true;
         Print("*** BUY Reset Phase 1 Complete - Price closed BELOW EMA line ***");
      }
      else if(g_buyResetPhaseBelowEMA && nowAboveBoth)
      {
         // Step 2 complete: Price closed above EMA again - BUY reset complete!
         g_waitBuySignalReset = false;
         g_buyResetPhaseBelowEMA = false;
         Print("*** BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }
   
   // *** SELL SIGNAL RESET CHECK ***
   // Step 1: Price must close ABOVE any EMA line (either one)
   // Step 2: Price must then close BELOW both EMA lines again
   if(g_waitSellSignalReset)
   {
      bool nowAboveAny = (signalClose > EMAHigh || signalClose > EMALow);
      bool nowBelowBoth = (signalClose < EMAHigh && signalClose < EMALow);
      
      if(!g_sellResetPhaseAboveEMA && nowAboveAny)
      {
         // Step 1 complete: Price closed above any EMA line
         g_sellResetPhaseAboveEMA = true;
         Print("*** SELL Reset Phase 1 Complete - Price closed ABOVE EMA line ***");
      }
      else if(g_sellResetPhaseAboveEMA && nowBelowBoth)
      {
         // Step 2 complete: Price closed below EMA again - SELL reset complete!
         g_waitSellSignalReset = false;
         g_sellResetPhaseAboveEMA = false;
         Print("*** SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze EMA Channel Signal                                         |
//+------------------------------------------------------------------+
string AnalyzeEMAChannelSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpEMATimeframe, 0);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpEMASignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastEMASignalTime)
      {
         return "WAIT";
      }
      LastEMASignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateEMASignalResetStatus();
   
   // Return the EMA signal calculated in CalculateEMAChannel()
   if(EMASignal == "BUY")
   {
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> BUY Signal detected but waiting for reset (Phase 1: ", g_buyResetPhaseBelowEMA ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> EMA Channel BUY Signal Confirmed!");
      return "BUY";
   }
   else if(EMASignal == "SELL")
   {
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> SELL Signal detected but waiting for reset (Phase 1: ", g_sellResetPhaseAboveEMA ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> EMA Channel SELL Signal Confirmed!");
      return "SELL";
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Calculate Bollinger Bands                                          |
//+------------------------------------------------------------------+
void CalculateBollingerBands()
{
   // Use iBands indicator handle for accurate calculation
   if(BBHandle == INVALID_HANDLE)
   {
      Print("Warning: Bollinger Bands handle not initialized");
      return;
   }
   
   double upperArr[], lowerArr[], basisArr[];
   ArraySetAsSeries(upperArr, true);
   ArraySetAsSeries(lowerArr, true);
   ArraySetAsSeries(basisArr, true);
   
   // Copy buffer data from indicator
   // Buffer 0 = Base (Middle), Buffer 1 = Upper, Buffer 2 = Lower
   if(CopyBuffer(BBHandle, 0, 0, 10, basisArr) < 10) return;
   if(CopyBuffer(BBHandle, 1, 0, 10, upperArr) < 10) return;
   if(CopyBuffer(BBHandle, 2, 0, 10, lowerArr) < 10) return;
   
   // Get values at signal bar
   int signalBar = (InpBBSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   BBBasis = basisArr[signalBar];
   BBUpper = upperArr[signalBar];
   BBLower = lowerArr[signalBar];
   
   // Get close price at signal bar
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpBBTimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // SELL signal: Price closes ABOVE upper band
   // BUY signal: Price closes BELOW lower band
   if(signalClose > BBUpper)
   {
      BBSignal = "SELL";
   }
   else if(signalClose < BBLower)
   {
      BBSignal = "BUY";
   }
   else
   {
      BBSignal = "NONE";
   }
   
   // Note: Bollinger Bands lines are displayed via ChartIndicatorAdd() in OnInit()
   // No need to draw objects manually - the indicator handle displays the lines automatically
}

//+------------------------------------------------------------------+
//| Check and Update Signal Reset Status for Bollinger Strategy        |
//+------------------------------------------------------------------+
void UpdateBBSignalResetStatus()
{
   // Get current price relative to BB bands
   int signalBar = (InpBBSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpBBTimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // *** BUY SIGNAL RESET CHECK ***
   // For BB: After BUY closes, price must go back ABOVE lower band (into channel)
   // then close BELOW lower band again to trigger new BUY
   if(g_waitBuySignalReset)
   {
      bool nowAboveLower = (signalClose > BBLower);
      bool nowBelowLower = (signalClose < BBLower);
      
      if(!g_bbBuyResetPhaseBelowBand && nowAboveLower)
      {
         // Step 1 complete: Price went back into the channel (above lower band)
         g_bbBuyResetPhaseBelowBand = true;
         Print("*** BB BUY Reset Phase 1 Complete - Price returned ABOVE lower band ***");
      }
      else if(g_bbBuyResetPhaseBelowBand && nowBelowLower)
      {
         // Step 2 complete: Price closed below lower band again - BUY reset complete!
         g_waitBuySignalReset = false;
         g_bbBuyResetPhaseBelowBand = false;
         Print("*** BB BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }
   
   // *** SELL SIGNAL RESET CHECK ***
   // For BB: After SELL closes, price must go back BELOW upper band (into channel)
   // then close ABOVE upper band again to trigger new SELL
   if(g_waitSellSignalReset)
   {
      bool nowBelowUpper = (signalClose < BBUpper);
      bool nowAboveUpper = (signalClose > BBUpper);
      
      if(!g_bbSellResetPhaseAboveBand && nowBelowUpper)
      {
         // Step 1 complete: Price went back into the channel (below upper band)
         g_bbSellResetPhaseAboveBand = true;
         Print("*** BB SELL Reset Phase 1 Complete - Price returned BELOW upper band ***");
      }
      else if(g_bbSellResetPhaseAboveBand && nowAboveUpper)
      {
         // Step 2 complete: Price closed above upper band again - SELL reset complete!
         g_waitSellSignalReset = false;
         g_bbSellResetPhaseAboveBand = false;
         Print("*** BB SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Bollinger Bands Signal                                     |
//+------------------------------------------------------------------+
string AnalyzeBollingerSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpBBTimeframe, 0);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpBBSignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastBBSignalTime)
      {
         return "WAIT";
      }
      LastBBSignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateBBSignalResetStatus();
   
   // Return the BB signal calculated in CalculateBollingerBands()
   if(BBSignal == "BUY")
   {
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> BB BUY Signal detected but waiting for reset (Phase 1: ", g_bbBuyResetPhaseBelowBand ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Bollinger Bands BUY Signal Confirmed! (Price closed BELOW lower band)");
      return "BUY";
   }
   else if(BBSignal == "SELL")
   {
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> BB SELL Signal detected but waiting for reset (Phase 1: ", g_bbSellResetPhaseAboveBand ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Bollinger Bands SELL Signal Confirmed! (Price closed ABOVE upper band)");
      return "SELL";
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Calculate Smart Money Concepts (Order Blocks) - LuxAlgo Style      |
//| Based on swing structure detection + BOS/CHoCH + ATR Filter         |
//+------------------------------------------------------------------+
void CalculateSMC()
{
   // Get price data - need more bars for ATR calculation and swing detection
   double highArr[], lowArr[], closeArr[], openArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(openArr, true);
   
   // LuxAlgo needs: SwingLength + ATR(200) + buffer for pivot detection
   int barsNeeded = MathMax(InpSMCSwingLength * 3, 300);
   if(CopyHigh(_Symbol, InpSMCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpSMCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyClose(_Symbol, InpSMCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpSMCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   
   datetime timeArr[];
   ArraySetAsSeries(timeArr, true);
   if(CopyTime(_Symbol, InpSMCTimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   // Update legacy SMCSwingHigh/Low for compatibility with other functions
   int lookback = InpSMCInternalLength;
   for(int i = lookback; i < MathMin(100, barsNeeded - lookback); i++)
   {
      bool isSwingHigh = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(highArr[i] <= highArr[i-j] || highArr[i] <= highArr[i+j])
         {
            isSwingHigh = false;
            break;
         }
      }
      if(isSwingHigh && highArr[i] > SMCSwingHigh)
      {
         SMCSwingHigh = highArr[i];
         SMCSwingHighTime = timeArr[i];
      }
      
      bool isSwingLow = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(lowArr[i] >= lowArr[i-j] || lowArr[i] >= lowArr[i+j])
         {
            isSwingLow = false;
            break;
         }
      }
      if(isSwingLow && (SMCSwingLow == 0 || lowArr[i] < SMCSwingLow))
      {
         SMCSwingLow = lowArr[i];
         SMCSwingLowTime = timeArr[i];
      }
   }
   
   // Determine trend based on structure
   double currentClose = closeArr[0];
   if(currentClose > SMCSwingHigh && SMCSwingHigh > 0)
      SMCTrend = 1;
   else if(currentClose < SMCSwingLow && SMCSwingLow > 0)
      SMCTrend = -1;
   
   // ===============================================================
   // LUXALGO-STYLE ORDER BLOCK DETECTION
   // - Uses Pivot Points (pivothigh/pivotlow) for swing structure
   // - Creates OBs ONLY on Structure Breaks (BOS/CHoCH)
   // - OB origin = min/max body bar between swing and break point
   // - ATR filter: bar range >= 2*ATR(200) for significance
   // ===============================================================
   DetectOrderBlocks(highArr, lowArr, openArr, closeArr, timeArr, barsNeeded);
   
   // Apply Confluence Filter (merge overlapping OBs)
   ApplyConfluenceFilter();
   
   // Draw Order Blocks on chart
   DrawOrderBlocks();
   
   // Check for price touch on Order Blocks
   CheckOBTouch(closeArr[0], highArr[0], lowArr[0]);
   
   // Generate SMC Signal
   GenerateSMCSignal(closeArr, lowArr, highArr);
}

//+------------------------------------------------------------------+
//| ============= HISTORICAL ORDER BLOCK SCAN (LuxAlgo) ============= |
//+------------------------------------------------------------------+
// Scans historical bars to find Order Blocks that are still valid
// (not yet mitigated by price closing through them)
// Called on EA Init to load existing OBs before real-time detection
//+------------------------------------------------------------------+

void ScanHistoricalOrderBlocks()
{
   if(InpSMCHistoryBars <= 0) return;
   
   Print("=== HISTORICAL ORDER BLOCK SCAN ===");
   
   // Load historical data
   double highArr[], lowArr[], openArr[], closeArr[];
   datetime timeArr[];
   
   int barCount = MathMin(InpSMCHistoryBars, Bars(_Symbol, InpSMCTimeframe) - 50);
   if(barCount < 50)
   {
      Print("Historical Scan: Not enough bars (", barCount, ") - skipping");
      return;
   }
   
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(timeArr, true);
   
   if(CopyHigh(_Symbol, InpSMCTimeframe, 0, barCount, highArr) < barCount) return;
   if(CopyLow(_Symbol, InpSMCTimeframe, 0, barCount, lowArr) < barCount) return;
   if(CopyOpen(_Symbol, InpSMCTimeframe, 0, barCount, openArr) < barCount) return;
   if(CopyClose(_Symbol, InpSMCTimeframe, 0, barCount, closeArr) < barCount) return;
   if(CopyTime(_Symbol, InpSMCTimeframe, 0, barCount, timeArr) < barCount) return;
   
   Print("Historical Scan: Loaded ", barCount, " bars from ", EnumToString(InpSMCTimeframe));
   
   // Structure tracking for historical scan
   double intSwingHigh = 0, intSwingLow = 0;
   int intSwingHighBar = 0, intSwingLowBar = 0;
   bool intHighCrossed = false, intLowCrossed = false;
   int intTrendBias = 0;
   
   double swingHigh = 0, swingLow = 0;
   int swingHighBar = 0, swingLowBar = 0;
   bool swingHighCrossed = false, swingLowCrossed = false;
   int swingTrendBias = 0;
   
   // Temp storage for potential OBs (store newest first)
   OrderBlockData tempBullOBs[];
   OrderBlockData tempBearOBs[];
   ArrayResize(tempBullOBs, 0);
   ArrayResize(tempBearOBs, 0);
   
   int internalLen = InpSMCInternalLength;
   int swingLen = InpSMCSwingLength;
   int totalBullFound = 0, totalBearFound = 0;
   int mitigatedBull = 0, mitigatedBear = 0;
   
   // Calculate ATR for OB filtering
   double atr = GetATRValue(0, highArr, lowArr, closeArr, 200);
   double obThreshold = (atr > 0) ? atr : 0.001;
   
   // ===============================================================
   // PASS 1: Scan from OLDEST to NEWEST to find structure breaks
   // and create OB candidates
   // ===============================================================
   
   for(int i = barCount - swingLen - 10; i >= internalLen + 2; i--)
   {
      // === INTERNAL STRUCTURE DETECTION (using internalLen) ===
      // Find pivot high
      bool isInternalPivotHigh = true;
      for(int j = 1; j <= internalLen; j++)
      {
         if(i + j >= barCount || i - j < 0) { isInternalPivotHigh = false; break; }
         if(highArr[i] <= highArr[i - j] || highArr[i] <= highArr[i + j])
         {
            isInternalPivotHigh = false;
            break;
         }
      }
      
      if(isInternalPivotHigh && (intSwingHighBar == 0 || highArr[i] != intSwingHigh))
      {
         intSwingHigh = highArr[i];
         intSwingHighBar = i;
         intHighCrossed = false;
      }
      
      // Find pivot low
      bool isInternalPivotLow = true;
      for(int j = 1; j <= internalLen; j++)
      {
         if(i + j >= barCount || i - j < 0) { isInternalPivotLow = false; break; }
         if(lowArr[i] >= lowArr[i - j] || lowArr[i] >= lowArr[i + j])
         {
            isInternalPivotLow = false;
            break;
         }
      }
      
      if(isInternalPivotLow && (intSwingLowBar == 0 || lowArr[i] != intSwingLow))
      {
         intSwingLow = lowArr[i];
         intSwingLowBar = i;
         intLowCrossed = false;
      }
      
      // Check for BULLISH structure break (close > swing high)
      if(intSwingHigh > 0 && !intHighCrossed && i > 0)
      {
         if(closeArr[i - 1] > intSwingHigh)
         {
            intHighCrossed = true;
            intTrendBias = 1;
            
            // Find OB origin bar (min low between break and pivot)
            int obBar = FindHistoricalOBOriginBar(false, intSwingHighBar, i - 1, highArr, lowArr, closeArr, barCount, obThreshold);
            
            if(obBar >= 0 && obBar < barCount && InpSMCShowInternalOB)
            {
               // Create temp Bullish OB
               OrderBlockData ob;
               ob.high = highArr[obBar];
               ob.low = lowArr[obBar];
               ob.time = timeArr[obBar];
               ob.barIndex = obBar;
               ob.bias = 1;
               ob.mitigated = false;
               ob.objName = SMCPrefix + "HistBullOB_" + IntegerToString((long)ob.time);
               
               // Check if already in blacklist
               if(!IsSMCRemovedTime(ob.time, true))
               {
                  int n = ArraySize(tempBullOBs);
                  ArrayResize(tempBullOBs, n + 1);
                  tempBullOBs[n] = ob;
                  totalBullFound++;
               }
            }
            
            intSwingHigh = 0;
            intSwingHighBar = 0;
         }
      }
      
      // Check for BEARISH structure break (close < swing low)
      if(intSwingLow > 0 && !intLowCrossed && i > 0)
      {
         if(closeArr[i - 1] < intSwingLow)
         {
            intLowCrossed = true;
            intTrendBias = -1;
            
            // Find OB origin bar (max high between break and pivot)
            int obBar = FindHistoricalOBOriginBar(true, intSwingLowBar, i - 1, highArr, lowArr, closeArr, barCount, obThreshold);
            
            if(obBar >= 0 && obBar < barCount && InpSMCShowInternalOB)
            {
               // Create temp Bearish OB
               OrderBlockData ob;
               ob.high = highArr[obBar];
               ob.low = lowArr[obBar];
               ob.time = timeArr[obBar];
               ob.barIndex = obBar;
               ob.bias = -1;
               ob.mitigated = false;
               ob.objName = SMCPrefix + "HistBearOB_" + IntegerToString((long)ob.time);
               
               // Check if already in blacklist
               if(!IsSMCRemovedTime(ob.time, false))
               {
                  int n = ArraySize(tempBearOBs);
                  ArrayResize(tempBearOBs, n + 1);
                  tempBearOBs[n] = ob;
                  totalBearFound++;
               }
            }
            
            intSwingLow = 0;
            intSwingLowBar = 0;
         }
      }
   }
   
   Print("Historical Scan: Found ", totalBullFound, " Bullish OB candidates, ", totalBearFound, " Bearish OB candidates");
   
   // ===============================================================
   // PASS 2: Check mitigation - remove OBs where price closed through
   // ===============================================================
   
   // Check Bullish OBs for mitigation
   for(int i = ArraySize(tempBullOBs) - 1; i >= 0; i--)
   {
      int obBarIndex = tempBullOBs[i].barIndex;
      bool isMitigated = false;
      
      // Check all bars AFTER the OB formation
      for(int b = obBarIndex - 1; b >= 1; b--)
      {
         if(closeArr[b] < tempBullOBs[i].low)
         {
            isMitigated = true;
            break;
         }
      }
      
      if(isMitigated)
      {
         tempBullOBs[i].mitigated = true;
         mitigatedBull++;
      }
   }
   
   // Check Bearish OBs for mitigation
   for(int i = ArraySize(tempBearOBs) - 1; i >= 0; i--)
   {
      int obBarIndex = tempBearOBs[i].barIndex;
      bool isMitigated = false;
      
      // Check all bars AFTER the OB formation
      for(int b = obBarIndex - 1; b >= 1; b--)
      {
         if(closeArr[b] > tempBearOBs[i].high)
         {
            isMitigated = true;
            break;
         }
      }
      
      if(isMitigated)
      {
         tempBearOBs[i].mitigated = true;
         mitigatedBear++;
      }
   }
   
   Print("Historical Scan: Mitigated ", mitigatedBull, " Bullish, ", mitigatedBear, " Bearish OBs");
   
   // ===============================================================
   // PASS 3: Add non-mitigated OBs to main arrays (newest first)
   // ===============================================================
   
   int addedBull = 0, addedBear = 0;
   int maxInternalOBs = InpSMCMaxInternalOB;
   int maxSwingOBs = InpSMCMaxSwingOB;
   int totalMaxOBs = maxInternalOBs + maxSwingOBs;
   
   // Sort by bar index (smaller = newer) and add newest first
   // Add Bullish OBs
   for(int i = 0; i < ArraySize(tempBullOBs) && addedBull < totalMaxOBs; i++)
   {
      if(!tempBullOBs[i].mitigated)
      {
         // Add to unified array
         if(BullishOBCount < totalMaxOBs)
         {
            BullishOBs[BullishOBCount] = tempBullOBs[i];
            BullishOBs[BullishOBCount].objName = SMCPrefix + "BullOB_" + IntegerToString(BullishOBCount);
            BullishOBCount++;
            addedBull++;
         }
      }
   }
   
   // Add Bearish OBs
   for(int i = 0; i < ArraySize(tempBearOBs) && addedBear < totalMaxOBs; i++)
   {
      if(!tempBearOBs[i].mitigated)
      {
         // Add to unified array
         if(BearishOBCount < totalMaxOBs)
         {
            BearishOBs[BearishOBCount] = tempBearOBs[i];
            BearishOBs[BearishOBCount].objName = SMCPrefix + "BearOB_" + IntegerToString(BearishOBCount);
            BearishOBCount++;
            addedBear++;
         }
      }
   }
   
   Print("=== HISTORICAL SCAN COMPLETE ===");
   Print("Loaded ", addedBull, " valid Bullish OBs");
   Print("Loaded ", addedBear, " valid Bearish OBs");
   Print("Total OBs: ", BullishOBCount + BearishOBCount);
   
   // Draw the loaded OBs
   DrawOrderBlocks();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Find OB Origin Bar for Historical Scan                             |
//| Similar to FindOBOriginBar but works with historical indices       |
//+------------------------------------------------------------------+
int FindHistoricalOBOriginBar(bool useMax, int pivotBar, int breakBar, 
                               double &highArr[], double &lowArr[], double &closeArr[], 
                               int barsTotal, double obThreshold)
{
   int idx = pivotBar - 1;
   double minVal = DBL_MAX;
   double maxVal = -DBL_MAX;
   
   if(idx < 0) idx = 0;
   if(idx >= barsTotal) idx = barsTotal - 1;
   
   // Search from break bar to pivot bar
   int searchStart = breakBar + 1;
   int searchEnd = pivotBar;
   
   if(searchStart > searchEnd)
   {
      int temp = searchStart;
      searchStart = searchEnd;
      searchEnd = temp;
   }
   
   for(int i = searchStart; i < searchEnd && i < barsTotal; i++)
   {
      double barRange = highArr[i] - lowArr[i];
      
      // ATR filter: only small/medium bars qualify
      if(barRange < obThreshold * 2.0)
      {
         if(useMax)  // Bearish OB: find bar with MAXIMUM high
         {
            if(highArr[i] > maxVal)
            {
               maxVal = highArr[i];
               idx = i;
            }
         }
         else  // Bullish OB: find bar with MINIMUM low
         {
            if(lowArr[i] < minVal)
            {
               minVal = lowArr[i];
               idx = i;
            }
         }
      }
   }
   
   // If no valid bar found with filter, use the bar closest to pivot
   if((useMax && maxVal == -DBL_MAX) || (!useMax && minVal == DBL_MAX))
   {
      idx = MathMax(0, pivotBar - 1);
   }
   
   return idx;
}

//+------------------------------------------------------------------+
//| =================== LUXALGO HELPER FUNCTIONS =================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR value for volatility measure                               |
//| LuxAlgo uses ATR(200) as volatility baseline                       |
//+------------------------------------------------------------------+
double GetATRValue(int barIndex, double &highArr[], double &lowArr[], double &closeArr[], int period = 200)
{
   int barsTotal = ArraySize(highArr);
   if(barIndex + period >= barsTotal) return 0;
   
   double sum = 0;
   for(int i = barIndex; i < barIndex + period && i < barsTotal - 1; i++)
   {
      double tr1 = highArr[i] - lowArr[i];
      double tr2 = MathAbs(highArr[i] - closeArr[i + 1]);
      double tr3 = MathAbs(lowArr[i] - closeArr[i + 1]);
      sum += MathMax(tr1, MathMax(tr2, tr3));
   }
   
   return sum / period;
}

//+------------------------------------------------------------------+
//| Get Cumulative Mean Range (alternative to ATR for low data)        |
//| LuxAlgo: cmean_range = ta.cum(high - low) / n                      |
//+------------------------------------------------------------------+
double GetCumulativeMeanRange(double &highArr[], double &lowArr[], int barsTotal)
{
   if(barsTotal <= 0) return 0;
   
   double cumRange = 0;
   for(int i = 0; i < barsTotal; i++)
   {
      cumRange += highArr[i] - lowArr[i];
   }
   return cumRange / barsTotal;
}

//+------------------------------------------------------------------+
//| LuxAlgo OB Coordinate Function (ob_coord) - EXACT IMPLEMENTATION   |
//| ================================================================== |
//| FROM LUXALGO Pine Script:                                          |
//| ob_coord(use_max, loc, n)=>                                        |
//|   idx = 1                                                          |
//|   ob_threshold = ob_filter == 'Atr' ? ta.atr(200) : cmean_range    |
//|   for i = 1 to n - loc - 1                                         |
//|     if (high[i] - low[i]) < ob_threshold * 2                       |
//|       if use_max → max(high[i]) else → min(low[i])                 |
//| Returns: [top, btm] where top = high[idx], btm = low[idx]          |
//+------------------------------------------------------------------+
int FindOBOriginBar(bool useMax, int pivotBar, int breakBar, double &highArr[], double &lowArr[], 
                    double &closeArr[], int barsTotal)
{
   int idx = 1;  // LuxAlgo default: idx = 1
   double minVal = DBL_MAX;
   double maxVal = -DBL_MAX;
   
   // Calculate threshold (LuxAlgo: ATR(200) or Cumulative Mean Range)
   double atr = GetATRValue(0, highArr, lowArr, closeArr, 200);
   double cmr = GetCumulativeMeanRange(highArr, lowArr, MathMin(barsTotal, 500));
   double obThreshold = (atr > 0) ? atr : cmr;
   
   // LuxAlgo: for i = 1 to (n - loc) - 1
   // n = breakBar (current bar when break happened)
   // loc = pivotBar (swing point location)
   // Search range: from bar 1 (most recent closed) to bar BETWEEN pivot and break
   int searchEnd = pivotBar;  // Search up to pivot bar
   if(searchEnd <= 1) searchEnd = 2;
   
   for(int i = 1; i < searchEnd && i < barsTotal; i++)
   {
      double barRange = highArr[i] - lowArr[i];
      
      // LuxAlgo filter: (high[i] - low[i]) < ob_threshold * 2
      // This filters out volatile/impulse candles - only small body candles qualify
      if(barRange < obThreshold * 2.0)
      {
         if(useMax)  // Bearish OB: find bar with MAXIMUM high (resistance zone)
         {
            if(highArr[i] > maxVal)
            {
               maxVal = highArr[i];
               idx = i;
            }
         }
         else  // Bullish OB: find bar with MINIMUM low (support zone)
         {
            if(lowArr[i] < minVal)
            {
               minVal = lowArr[i];
               idx = i;
            }
         }
      }
   }
   
   // If no valid bar found with ATR filter, return the last bar before pivot
   if((useMax && maxVal == -DBL_MAX) || (!useMax && minVal == DBL_MAX))
   {
      idx = MathMin(pivotBar - 1, barsTotal - 1);
      if(idx < 1) idx = 1;
   }
   
   return idx;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks (LuxAlgo Style - Full Algorithm)               |
//| ================================================================== |
//| KEY ALGORITHM (matching LuxAlgo ob_coord function):                 |
//| 1. Find swing highs/lows using pivot detection                      |
//| 2. When close crosses swing point → Structure Break (BOS/CHoCH)    |
//| 3. Call ob_coord to find origin candle:                            |
//|    - Search from bar 1 to pivot bar                                 |
//|    - Filter: bar range < 2 * ATR (non-volatile bars only)           |
//|    - Bullish OB (crossover): find min low[i]                        |
//|    - Bearish OB (crossunder): find max high[i]                      |
//| 4. OB zone = high[idx] to low[idx] of origin candle                 |
//+------------------------------------------------------------------+
void DetectOrderBlocks(double &highArr[], double &lowArr[], double &openArr[], 
                       double &closeArr[], datetime &timeArr[], int barsTotal)
{
   int internalLen = InpSMCInternalLength; // Internal swing (5 default)
   
   // Only scan/create new OBs once per NEW CLOSED candle on SMC timeframe
   datetime lastClosedSMCTime = iTime(_Symbol, InpSMCTimeframe, 1);
   bool canScanNewOBs = (lastClosedSMCTime > 0 && lastClosedSMCTime != g_lastSMCClosedBarTime);
   if(canScanNewOBs)
      g_lastSMCClosedBarTime = lastClosedSMCTime;

   if(canScanNewOBs)
   {
      // ===============================================================
      // STEP 1: FIND MOST RECENT PIVOT HIGH AND LOW
      // LuxAlgo style: swings(len) returns pivot highs and lows
      // ===============================================================
      int scanLimit = MathMin(100, barsTotal - internalLen - 5);
      
      // Find MOST RECENT confirmed pivots
      double recentPivotHigh = 0;
      double recentPivotLow = 0;
      int recentPivotHighBar = 0;
      int recentPivotLowBar = 0;
      
      for(int i = internalLen + 1; i < scanLimit; i++)
      {
         // --- Check for Pivot High ---
         if(recentPivotHighBar == 0)
         {
            bool isPivotHigh = true;
            for(int j = 1; j <= internalLen; j++)
            {
               if(i + j >= barsTotal || i - j < 0) { isPivotHigh = false; break; }
               if(highArr[i] <= highArr[i - j] || highArr[i] <= highArr[i + j])
               {
                  isPivotHigh = false;
                  break;
               }
            }
            if(isPivotHigh)
            {
               recentPivotHigh = highArr[i];
               recentPivotHighBar = i;
            }
         }
         
         // --- Check for Pivot Low ---
         if(recentPivotLowBar == 0)
         {
            bool isPivotLow = true;
            for(int j = 1; j <= internalLen; j++)
            {
               if(i + j >= barsTotal || i - j < 0) { isPivotLow = false; break; }
               if(lowArr[i] >= lowArr[i - j] || lowArr[i] >= lowArr[i + j])
               {
                  isPivotLow = false;
                  break;
               }
            }
            if(isPivotLow)
            {
               recentPivotLow = lowArr[i];
               recentPivotLowBar = i;
            }
         }
         
         if(recentPivotHighBar > 0 && recentPivotLowBar > 0) break;
      }
      
      // Update global swing tracking
      if(recentPivotHigh > 0 && recentPivotHighBar != g_InternalSwingHighBar)
      {
         g_InternalSwingHigh = recentPivotHigh;
         g_InternalSwingHighBar = recentPivotHighBar;
         g_InternalSwingHighCrossed = false;
      }
      
      if(recentPivotLow > 0 && recentPivotLowBar != g_InternalSwingLowBar)
      {
         g_InternalSwingLow = recentPivotLow;
         g_InternalSwingLowBar = recentPivotLowBar;
         g_InternalSwingLowCrossed = false;
      }
      
      // ===============================================================
      // STEP 2: CHECK FOR STRUCTURE BREAKS AND CREATE ORDER BLOCKS
      // LuxAlgo: ta.crossover(close, itop_y) → Bullish BOS/CHoCH
      // LuxAlgo: ta.crossunder(close, ibtm_y) → Bearish BOS/CHoCH
      // ===============================================================
      double currentClose = closeArr[1];  // Use CLOSED candle (shift 1)
      
      // === BULLISH BREAK: Close crosses ABOVE swing high ===
      // LuxAlgo: ob_coord(false, itop_x, ...) → Find min low for bullish OB
      if(g_InternalSwingHigh > 0 && !g_InternalSwingHighCrossed && currentClose > g_InternalSwingHigh)
      {
         g_InternalSwingHighCrossed = true;
         
         bool isCHoCH = (g_InternalTrendBias == -1);
         g_InternalTrendBias = 1;
         
         Print(">>> SMC LuxAlgo: ", (isCHoCH ? "CHoCH" : "BOS"), " BULLISH! Close=", 
               DoubleToString(currentClose, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), 
               " > Swing High=", DoubleToString(g_InternalSwingHigh, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
         
         // LuxAlgo ob_coord: use_max=false → find MINIMUM low
         if(InpSMCShowBullishOB && g_InternalSwingHighBar > 0)
         {
            // breakBar = 1 (closed candle that made the break)
            int obBar = FindOBOriginBar(false, g_InternalSwingHighBar, 1, highArr, lowArr, closeArr, barsTotal);
            if(obBar >= 0 && obBar < barsTotal)
            {
               // LuxAlgo: OB zone = high[idx] to low[idx]
               double obHigh = highArr[obBar];
               double obLow = lowArr[obBar];
               
               // Ensure minimum zone height (30% of avg candle for visibility)
               double zoneHeight = obHigh - obLow;
               double avgCandleSize = 0;
               for(int k = 1; k <= 20 && k < barsTotal; k++)
                  avgCandleSize += highArr[k] - lowArr[k];
               avgCandleSize /= 20.0;
               
               if(zoneHeight < avgCandleSize * 0.3)
               {
                  double mid = (obHigh + obLow) / 2.0;
                  obHigh = mid + avgCandleSize * 0.15;
                  obLow = mid - avgCandleSize * 0.15;
               }
               
               AddBullishOB(obHigh, obLow, timeArr[obBar], obBar);
               Print(">>> SMC LuxAlgo: Created Bullish OB at bar ", obBar, " | Zone: ", 
                     DoubleToString(obLow, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), " - ", 
                     DoubleToString(obHigh, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
            }
         }
         
         // Reset for next detection cycle
         g_InternalSwingHigh = 0;
         g_InternalSwingHighBar = 0;
      }
      
      // === BEARISH BREAK: Close crosses BELOW swing low ===
      // LuxAlgo: ob_coord(true, ibtm_x, ...) → Find max high for bearish OB
      if(g_InternalSwingLow > 0 && !g_InternalSwingLowCrossed && currentClose < g_InternalSwingLow)
      {
         g_InternalSwingLowCrossed = true;
         
         bool isCHoCH = (g_InternalTrendBias == 1);
         g_InternalTrendBias = -1;
         
         Print(">>> SMC LuxAlgo: ", (isCHoCH ? "CHoCH" : "BOS"), " BEARISH! Close=", 
               DoubleToString(currentClose, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), 
               " < Swing Low=", DoubleToString(g_InternalSwingLow, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
         
         // LuxAlgo ob_coord: use_max=true → find MAXIMUM high
         if(InpSMCShowBearishOB && g_InternalSwingLowBar > 0)
         {
            // breakBar = 1 (closed candle that made the break)
            int obBar = FindOBOriginBar(true, g_InternalSwingLowBar, 1, highArr, lowArr, closeArr, barsTotal);
            if(obBar >= 0 && obBar < barsTotal)
            {
               // LuxAlgo: OB zone = high[idx] to low[idx]
               double obHigh = highArr[obBar];
               double obLow = lowArr[obBar];
               
               // Ensure minimum zone height (30% of avg candle for visibility)
               double zoneHeight = obHigh - obLow;
               double avgCandleSize = 0;
               for(int k = 1; k <= 20 && k < barsTotal; k++)
                  avgCandleSize += highArr[k] - lowArr[k];
               avgCandleSize /= 20.0;
               
               if(zoneHeight < avgCandleSize * 0.3)
               {
                  double mid = (obHigh + obLow) / 2.0;
                  obHigh = mid + avgCandleSize * 0.15;
                  obLow = mid - avgCandleSize * 0.15;
               }
               
               AddBearishOB(obHigh, obLow, timeArr[obBar], obBar);
               Print(">>> SMC LuxAlgo: Created Bearish OB at bar ", obBar, " | Zone: ", 
                     DoubleToString(obLow, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), " - ", 
                     DoubleToString(obHigh, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
            }
         }
         
         // Reset for next detection cycle
         g_InternalSwingLow = 0;
         g_InternalSwingLowBar = 0;
      }
      
      // ===============================================================
      // FALLBACK: Simple OB detection when no structure breaks yet
      // Ensures some OBs appear even before BOS/CHoCH
      // ===============================================================
      if(BullishOBCount == 0 && BearishOBCount == 0)
      {
         for(int i = internalLen; i < MathMin(30, barsTotal - internalLen - 1); i++)
         {
            // Bullish OB: Bearish candle followed by strong up move
            if(closeArr[i] < openArr[i])
            {
               bool strongUp = false;
               for(int j = i - 1; j >= 1 && j > i - 4; j--)
               {
                  if(closeArr[j] > highArr[i] + (highArr[i] - lowArr[i]) * 0.5)
                  {
                     strongUp = true;
                     break;
                  }
               }
               if(strongUp && InpSMCShowBullishOB)
               {
                  AddBullishOB(highArr[i], lowArr[i], timeArr[i], i);
               }
            }
            
            // Bearish OB: Bullish candle followed by strong down move
            if(closeArr[i] > openArr[i])
            {
               bool strongDown = false;
               for(int j = i - 1; j >= 1 && j > i - 4; j--)
               {
                  if(closeArr[j] < lowArr[i] - (highArr[i] - lowArr[i]) * 0.5)
                  {
                     strongDown = true;
                     break;
                  }
               }
               if(strongDown && InpSMCShowBearishOB)
               {
                  AddBearishOB(highArr[i], lowArr[i], timeArr[i], i);
               }
            }
         }
      }
   }

   // =========================================================================
   // STEP 3: CHECK MITIGATION OF EXISTING ORDER BLOCKS (LuxAlgo Style)
   // =========================================================================
   double smcClose[];
   ArraySetAsSeries(smcClose, true);
   if(CopyClose(_Symbol, InpSMCTimeframe, 1, 1, smcClose) < 1) return;
   
   double confirmedClose = smcClose[0];
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   bool anyMitigated = false;
   
   // Check Bullish OBs (Support Zones) for mitigation
   for(int i = BullishOBCount - 1; i >= 0; i--)
   {
      if(BullishOBs[i].mitigated) continue;
      
      if(confirmedClose < BullishOBs[i].low)
      {
         Print(">>> SMC Mitigation: Bullish OB BROKEN! Close=", 
               DoubleToString(confirmedClose, digits), " < Zone Low=", 
               DoubleToString(BullishOBs[i].low, digits), " | Removing");

         RememberSMCRemovedTime(BullishOBs[i].time, true);
         ObjectDelete(0, BullishOBs[i].objName);
         
         for(int j = i; j < BullishOBCount - 1; j++)
            BullishOBs[j] = BullishOBs[j + 1];
         BullishOBCount--;
         anyMitigated = true;
      }
   }
   
   // Check Bearish OBs (Resistance Zones) for mitigation
   for(int i = BearishOBCount - 1; i >= 0; i--)
   {
      if(BearishOBs[i].mitigated) continue;
      
      if(confirmedClose > BearishOBs[i].high)
      {
         Print(">>> SMC Mitigation: Bearish OB BROKEN! Close=", 
               DoubleToString(confirmedClose, digits), " > Zone High=", 
               DoubleToString(BearishOBs[i].high, digits), " | Removing");

         RememberSMCRemovedTime(BearishOBs[i].time, false);
         ObjectDelete(0, BearishOBs[i].objName);
         
         for(int j = i; j < BearishOBCount - 1; j++)
            BearishOBs[j] = BearishOBs[j + 1];
         BearishOBCount--;
         anyMitigated = true;
      }
   }
   
   if(anyMitigated)
   {
      ChartRedraw(0);
      Print(">>> SMC: Chart refreshed after OB mitigation. Remaining: ", 
            IntegerToString(BullishOBCount), " Bull, ", IntegerToString(BearishOBCount), " Bear OBs");
   }
}

// CleanupMitigatedOBs() is no longer needed as mitigation now removes OBs immediately
//
// NEW: Consume OB on entry
// - ผู้ใช้ต้องการให้ “แถบสี/โซน” หายไปทันทีหลังจาก EA เปิดออเดอร์จาก OB นั้น (touch + PA confirm)
// - ดังนั้นเราจะลบ rectangle object และเอา OB ออกจาก array ทันทีเมื่อ ExecuteBuy/ExecuteSell สำเร็จ

void ConsumeSMCOrderBlock(string obName, bool isBullish)
{
   if(obName == "") return;

   if(isBullish)
   {
      for(int i = 0; i < BullishOBCount; i++)
      {
         if(BullishOBs[i].objName == obName)
         {
            // Remember this OB time so it will NOT be re-created later
            RememberSMCRemovedTime(BullishOBs[i].time, true);

            ObjectDelete(0, BullishOBs[i].objName);
            for(int j = i; j < BullishOBCount - 1; j++)
            {
               BullishOBs[j] = BullishOBs[j + 1];
            }
            BullishOBCount--;
            Print(">>> SMC: Consumed Bullish OB on entry | ", obName);
            return;
         }
      }
   }
   else
   {
      for(int i = 0; i < BearishOBCount; i++)
      {
         if(BearishOBs[i].objName == obName)
         {
            // Remember this OB time so it will NOT be re-created later
            RememberSMCRemovedTime(BearishOBs[i].time, false);

            ObjectDelete(0, BearishOBs[i].objName);
            for(int j = i; j < BearishOBCount - 1; j++)
            {
               BearishOBs[j] = BearishOBs[j + 1];
            }
            BearishOBCount--;
            Print(">>> SMC: Consumed Bearish OB on entry | ", obName);
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add Bullish Order Block to array                                   |
//| obType: 0 = Internal, 1 = Swing                                    |
//+------------------------------------------------------------------+
void AddBullishOB(double high, double low, datetime time, int barIndex, int obType = 0)
{
   // Skip if this OB time was already removed (consumed/mitigated)
   if(IsSMCRemovedTime(time, true)) return;

   // Check if this OB already exists
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].time == time) return;  // Already exists
   }
   
   // *** CHECK OVERLAP: If new OB overlaps with existing OBs, delete OLD ones ***
   if(InpSMCConfluenceFilter)
   {
      for(int i = BullishOBCount - 1; i >= 0; i--)  // Loop backward for safe removal
      {
         if(BullishOBs[i].mitigated) continue;
         
         double overlapPct = CalcOverlapPercent(high, low, BullishOBs[i].high, BullishOBs[i].low);
         
         if(overlapPct >= InpSMCConfluencePercent)
         {
            // New OB overlaps with existing OB - DELETE the OLD one (keep new)
            Print(">>> SMC Overlap: NEW OB overlaps with OLD OB (", 
                  DoubleToString(overlapPct, 1), "%) - Deleting OLD: ", 
                  BullishOBs[i].objName, " | Keeping NEW at time: ", TimeToString(time));
            
            // Delete old OB from chart
            ObjectDelete(0, BullishOBs[i].objName);
            
            // Remember this time to prevent re-detection
            RememberSMCRemovedTime(BullishOBs[i].time, true);
            
            // Remove from array
            for(int k = i; k < BullishOBCount - 1; k++)
            {
               BullishOBs[k] = BullishOBs[k + 1];
            }
            BullishOBCount--;
         }
      }
   }
   
   // FIFO (Circular Buffer): If array is full, remove the OLDEST OB (index 0)
   // This ensures OBs keep updating even when max limit is reached
   int maxBullOBs = InpSMCMaxInternalOB + InpSMCMaxSwingOB;
   if(BullishOBCount >= maxBullOBs)
   {
      // Delete the oldest OB object from chart
      ObjectDelete(0, BullishOBs[0].objName);
      
      // Shift all elements left (remove oldest at index 0)
      for(int k = 0; k < BullishOBCount - 1; k++)
      {
         BullishOBs[k] = BullishOBs[k + 1];
      }
      BullishOBCount--;
      
      Print(">>> SMC: Bullish OB FIFO rotation - removed oldest OB to add new one");
   }
   
   // Add new OB with obType for color differentiation
   string prefix = (obType == 0) ? "Int" : "Swg";
   BullishOBs[BullishOBCount].high = high;
   BullishOBs[BullishOBCount].low = low;
   BullishOBs[BullishOBCount].time = time;
   BullishOBs[BullishOBCount].barIndex = barIndex;
   BullishOBs[BullishOBCount].bias = 1;
   BullishOBs[BullishOBCount].mitigated = false;
   BullishOBs[BullishOBCount].obType = obType;
   BullishOBs[BullishOBCount].objName = SMCPrefix + prefix + "BullOB_" + IntegerToString((long)time);
   BullishOBCount++;
}

//+------------------------------------------------------------------+
//| Add Bearish Order Block to array                                   |
//| obType: 0 = Internal, 1 = Swing                                    |
//+------------------------------------------------------------------+
void AddBearishOB(double high, double low, datetime time, int barIndex, int obType = 0)
{
   // Skip if this OB time was already removed (consumed/mitigated)
   if(IsSMCRemovedTime(time, false)) return;

   // Check if this OB already exists
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].time == time) return;  // Already exists
   }
   
   // *** CHECK OVERLAP: If new OB overlaps with existing OBs, delete OLD ones ***
   if(InpSMCConfluenceFilter)
   {
      for(int i = BearishOBCount - 1; i >= 0; i--)  // Loop backward for safe removal
      {
         if(BearishOBs[i].mitigated) continue;
         
         double overlapPct = CalcOverlapPercent(high, low, BearishOBs[i].high, BearishOBs[i].low);
         
         if(overlapPct >= InpSMCConfluencePercent)
         {
            // New OB overlaps with existing OB - DELETE the OLD one (keep new)
            Print(">>> SMC Overlap: NEW OB overlaps with OLD OB (", 
                  DoubleToString(overlapPct, 1), "%) - Deleting OLD: ", 
                  BearishOBs[i].objName, " | Keeping NEW at time: ", TimeToString(time));
            
            // Delete old OB from chart
            ObjectDelete(0, BearishOBs[i].objName);
            
            // Remember this time to prevent re-detection
            RememberSMCRemovedTime(BearishOBs[i].time, false);
            
            // Remove from array
            for(int k = i; k < BearishOBCount - 1; k++)
            {
               BearishOBs[k] = BearishOBs[k + 1];
            }
            BearishOBCount--;
         }
      }
   }
   
   // FIFO (Circular Buffer): If array is full, remove the OLDEST OB (index 0)
   // This ensures OBs keep updating even when max limit is reached
   int maxBearOBs = InpSMCMaxInternalOB + InpSMCMaxSwingOB;
   if(BearishOBCount >= maxBearOBs)
   {
      // Delete the oldest OB object from chart
      ObjectDelete(0, BearishOBs[0].objName);
      
      // Shift all elements left (remove oldest at index 0)
      for(int k = 0; k < BearishOBCount - 1; k++)
      {
         BearishOBs[k] = BearishOBs[k + 1];
      }
      BearishOBCount--;
      
      Print(">>> SMC: Bearish OB FIFO rotation - removed oldest OB to add new one");
   }
   
   // Add new OB with obType for color differentiation
   string prefix = (obType == 0) ? "Int" : "Swg";
   BearishOBs[BearishOBCount].high = high;
   BearishOBs[BearishOBCount].low = low;
   BearishOBs[BearishOBCount].time = time;
   BearishOBs[BearishOBCount].barIndex = barIndex;
   BearishOBs[BearishOBCount].bias = -1;
   BearishOBs[BearishOBCount].mitigated = false;
   BearishOBs[BearishOBCount].obType = obType;
   BearishOBs[BearishOBCount].objName = SMCPrefix + prefix + "BearOB_" + IntegerToString((long)time);
   BearishOBCount++;
}

//+------------------------------------------------------------------+
//| Apply Confluence Filter - Merge overlapping Order Blocks           |
//| When enabled, OBs that overlap by >= InpSMCConfluencePercent       |
//| will be merged into a single larger OB zone                         |
//+------------------------------------------------------------------+
void ApplyConfluenceFilter()
{
   if(!InpSMCConfluenceFilter) return;  // Skip if disabled
   
   // Apply to Bullish OBs
   MergeBullishOBs();
   
   // Apply to Bearish OBs
   MergeBearishOBs();
}

//+------------------------------------------------------------------+
//| Calculate overlap percentage between two zones                      |
//+------------------------------------------------------------------+
double CalcOverlapPercent(double high1, double low1, double high2, double low2)
{
   // Find the overlap range
   double overlapHigh = MathMin(high1, high2);
   double overlapLow = MathMax(low1, low2);
   
   // If no overlap
   if(overlapHigh <= overlapLow) return 0.0;
   
   double overlapSize = overlapHigh - overlapLow;
   double size1 = high1 - low1;
   double size2 = high2 - low2;
   
   // Use the smaller zone as reference for percentage
   double smallerSize = MathMin(size1, size2);
   if(smallerSize <= 0) return 0.0;
   
   return (overlapSize / smallerSize) * 100.0;
}

//+------------------------------------------------------------------+
//| Handle overlapping Bullish Order Blocks                            |
//| When OBs overlap, keep ONLY the NEWER block, delete older block    |
//+------------------------------------------------------------------+
void MergeBullishOBs()
{
   if(BullishOBCount < 2) return;
   
   bool changed = true;
   
   // Keep checking until no more changes
   while(changed)
   {
      changed = false;
      
      for(int i = 0; i < BullishOBCount; i++)
      {
         if(BullishOBs[i].mitigated) continue;
         
         for(int j = i + 1; j < BullishOBCount; j++)
         {
            if(BullishOBs[j].mitigated) continue;
            
            // Check overlap percentage
            double overlapPct = CalcOverlapPercent(
               BullishOBs[i].high, BullishOBs[i].low,
               BullishOBs[j].high, BullishOBs[j].low);
            
            if(overlapPct >= InpSMCConfluencePercent)
            {
               // Determine which OB is NEWER (keep newer, delete older)
               int olderIdx, newerIdx;
               if(BullishOBs[i].time < BullishOBs[j].time)
               {
                  olderIdx = i;
                  newerIdx = j;
               }
               else
               {
                  olderIdx = j;
                  newerIdx = i;
               }
               
               // Delete the OLDER OB from chart
               ObjectDelete(0, BullishOBs[olderIdx].objName);
               
               Print(">>> SMC Confluence: Overlap detected (", 
                     DoubleToString(overlapPct, 1), "%) - Keeping NEW OB, Deleting OLD OB: ",
                     BullishOBs[olderIdx].objName);
               
               // Remove older OB from array
               for(int k = olderIdx; k < BullishOBCount - 1; k++)
               {
                  BullishOBs[k] = BullishOBs[k + 1];
               }
               BullishOBCount--;
               
               changed = true;
               break;
            }
         }
         if(changed) break;
      }
   }
}

//+------------------------------------------------------------------+
//| Handle overlapping Bearish Order Blocks                            |
//| When OBs overlap, keep ONLY the NEWER block, delete older block    |
//+------------------------------------------------------------------+
void MergeBearishOBs()
{
   if(BearishOBCount < 2) return;
   
   bool changed = true;
   
   // Keep checking until no more changes
   while(changed)
   {
      changed = false;
      
      for(int i = 0; i < BearishOBCount; i++)
      {
         if(BearishOBs[i].mitigated) continue;
         
         for(int j = i + 1; j < BearishOBCount; j++)
         {
            if(BearishOBs[j].mitigated) continue;
            
            // Check overlap percentage
            double overlapPct = CalcOverlapPercent(
               BearishOBs[i].high, BearishOBs[i].low,
               BearishOBs[j].high, BearishOBs[j].low);
            
            if(overlapPct >= InpSMCConfluencePercent)
            {
               // Determine which OB is NEWER (keep newer, delete older)
               int olderIdx, newerIdx;
               if(BearishOBs[i].time < BearishOBs[j].time)
               {
                  olderIdx = i;
                  newerIdx = j;
               }
               else
               {
                  olderIdx = j;
                  newerIdx = i;
               }
               
               // Delete the OLDER OB from chart
               ObjectDelete(0, BearishOBs[olderIdx].objName);
               
               Print(">>> SMC Confluence: Overlap detected (", 
                     DoubleToString(overlapPct, 1), "%) - Keeping NEW OB, Deleting OLD OB: ",
                     BearishOBs[olderIdx].objName);
               
               // Remove older OB from array
               for(int k = olderIdx; k < BearishOBCount - 1; k++)
               {
                  BearishOBs[k] = BearishOBs[k + 1];
               }
               BearishOBCount--;
               
               changed = true;
               break;
            }
         }
         if(changed) break;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Order Blocks as rectangles on chart                           |
//| Uses different colors for Internal vs Swing OBs                    |
//+------------------------------------------------------------------+
void DrawOrderBlocks()
{
   datetime currentTime = TimeCurrent();
   datetime endTime = currentTime + PeriodSeconds(InpSMCTimeframe) * 50;
   
   // Draw Bullish Order Blocks
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].mitigated) continue;
      
      string objName = BullishOBs[i].objName;
      
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                     BullishOBs[i].time, BullishOBs[i].high,
                     endTime, BullishOBs[i].low);
      }
      else
      {
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, endTime);
      }
      
      // Use different colors for Internal vs Swing OBs
      color obColor = (BullishOBs[i].obType == 0) ? InpSMCInternalBullColor : InpSMCSwingBullColor;
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, obColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   }
   
   // Draw Bearish Order Blocks
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].mitigated) continue;
      
      string objName = BearishOBs[i].objName;
      
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                     BearishOBs[i].time, BearishOBs[i].high,
                     endTime, BearishOBs[i].low);
      }
      else
      {
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, endTime);
      }
      
      // Use different colors for Internal vs Swing OBs
      color obColor = (BearishOBs[i].obType == 0) ? InpSMCInternalBearColor : InpSMCSwingBearColor;
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, obColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   }
}

//+------------------------------------------------------------------+
//| Check if price touched an Order Block                              |
//| IMPORTANT: Touch flags PERSIST until used for order or reset       |
//| NEW RULE: OB detection stops ONLY for the side that has open orders|
//| - If BUY orders exist: BUY OB touch frozen, SELL OB still active   |
//| - If SELL orders exist: SELL OB touch frozen, BUY OB still active  |
//| - If BOTH exist: both sides frozen                                  |
//+------------------------------------------------------------------+
void CheckOBTouch(double closePrice, double highPrice, double lowPrice)
{
   // Check which sides have open positions
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   bool freezeBuySide = (buyCount > 0);   // Freeze BUY OB detection if BUY orders exist
   bool freezeSellSide = (sellCount > 0); // Freeze SELL OB detection if SELL orders exist
   
   // If BUY side is frozen, don't detect new BUY OB touches
   if(freezeBuySide)
   {
      g_smcBuyTouchingNow = false;
   }
   
   // If SELL side is frozen, don't detect new SELL OB touches  
   if(freezeSellSide)
   {
      g_smcSellTouchingNow = false;
   }

   // DON'T reset touch flags every tick - let them persist for PA confirmation
   // Flags are only reset when:
   // 1. Order is executed (in ExecuteBuy/ExecuteSell)
   // 2. Signal reset is required (after position closes)

   // Current tick touch detection
   bool currentTickBuyTouch = false;
   bool currentTickSellTouch = false;

   // Check Bullish OB touch (price dipped into support zone)
   // ONLY if BUY side is NOT frozen
   if(!freezeBuySide)
   {
      for(int i = 0; i < BullishOBCount; i++)
      {
         if(BullishOBs[i].mitigated) continue;

         bool touched = false;

         // Price entered the Bullish OB zone (support)
         if(lowPrice <= BullishOBs[i].high && lowPrice >= BullishOBs[i].low)
         {
            touched = true;
         }
         // Price closed inside the zone
         else if(closePrice <= BullishOBs[i].high && closePrice >= BullishOBs[i].low)
         {
            touched = true;
         }

         if(touched)
         {
            currentTickBuyTouch = true;

            // IMPORTANT: If price moved from OB#1 to OB#2 (or #3) while waiting for PA,
            // we must switch the active OB and stop counting the previous one.
            // So: update the active OB if different from the previous touched OB.
            if(!g_smcBuyTouchedOBPersist || g_smcBuyTouchedOBName != BullishOBs[i].objName)
            {
               g_smcBuyTouchedOBPersist = true;
               g_smcBuyTouchedOB = true;
               g_smcBuyTouchedOBName = BullishOBs[i].objName;
               g_smcBuyTouchTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Use bar time, not tick time!

               // If we are already waiting for PA on BUY, switch context to this new OB.
               if(InpUsePAConfirm && InpSignalStrategy == STRATEGY_SMC && g_pendingSignal == "BUY")
               {
                  g_signalTouchTime = g_smcBuyTouchTime;
                  g_signalBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                  g_paWaitCount = 0;
                  Print(">>> SWITCH BUY OB: now waiting PA on ", g_smcBuyTouchedOBName, " | TouchTime=", TimeToString(g_signalTouchTime));
               }
               else
               {
                  Print(">>> Price touched Bullish Order Block! Zone: ", BullishOBs[i].low, " - ", BullishOBs[i].high, " | Active OB for PA: ", g_smcBuyTouchedOBName);
               }
            }
            break;
         }
      }
   }

   // Check Bearish OB touch (price spiked into resistance zone)
   // ONLY if SELL side is NOT frozen
   if(!freezeSellSide)
   {
      for(int i = 0; i < BearishOBCount; i++)
      {
         if(BearishOBs[i].mitigated) continue;

         bool touched = false;

         // Price entered the Bearish OB zone (resistance)
         if(highPrice >= BearishOBs[i].low && highPrice <= BearishOBs[i].high)
         {
            touched = true;
         }
         // Price closed inside the zone
         else if(closePrice >= BearishOBs[i].low && closePrice <= BearishOBs[i].high)
         {
            touched = true;
         }

         if(touched)
         {
            currentTickSellTouch = true;

            // Switch active OB if a different box is touched while waiting for PA
            if(!g_smcSellTouchedOBPersist || g_smcSellTouchedOBName != BearishOBs[i].objName)
            {
               g_smcSellTouchedOBPersist = true;
               g_smcSellTouchedOB = true;
               g_smcSellTouchedOBName = BearishOBs[i].objName;
               g_smcSellTouchTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Use bar time, not tick time!

               if(InpUsePAConfirm && InpSignalStrategy == STRATEGY_SMC && g_pendingSignal == "SELL")
               {
                  g_signalTouchTime = g_smcSellTouchTime;
                  g_signalBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                  g_paWaitCount = 0;
                  Print(">>> SWITCH SELL OB: now waiting PA on ", g_smcSellTouchedOBName, " | TouchTime=", TimeToString(g_signalTouchTime));
               }
               else
               {
                  Print(">>> Price touched Bearish Order Block! Zone: ", BearishOBs[i].low, " - ", BearishOBs[i].high, " | Active OB for PA: ", g_smcSellTouchedOBName);
               }
            }
            break;
         }
      }
   }

   // Track CURRENT touch (used by reset logic)
   // For frozen sides, keep the touch status as false
   if(!freezeBuySide)
   {
      g_smcBuyTouchingNow = currentTickBuyTouch;
   }
   if(!freezeSellSide)
   {
      g_smcSellTouchingNow = currentTickSellTouch;
   }

   // Keep the SMC signal trigger based on persistent touch (so PA can be confirmed after the touch)
   g_smcBuyTouchedOB = g_smcBuyTouchedOBPersist;
   g_smcSellTouchedOB = g_smcSellTouchedOBPersist;
}

//+------------------------------------------------------------------+
//| Generate SMC Signal based on OB touch and trend                    |
//+------------------------------------------------------------------+
void GenerateSMCSignal(double &closeArr[], double &lowArr[], double &highArr[])
{
   SMCSignal = "NONE";
   
   int signalBar = (InpSMCSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   // BUY Signal: Bullish trend + Price touched Bullish OB (support)
   // If PA confirmation is enabled, it will be checked in OnTick
   if(SMCTrend >= 0)  // Bullish or Neutral trend
   {
      if(g_smcBuyTouchedOB)
      {
         if(InpSMCRequireTouch)
         {
            SMCSignal = "BUY";
         }
         else
         {
            SMCSignal = "BUY";
         }
      }
   }
   
   // SELL Signal: Bearish trend + Price touched Bearish OB (resistance)
   if(SMCTrend <= 0)  // Bearish or Neutral trend
   {
      if(g_smcSellTouchedOB)
      {
         if(InpSMCRequireTouch)
         {
            SMCSignal = "SELL";
         }
         else
         {
            SMCSignal = "SELL";
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update SMC Signal Reset Status                                     |
//| IMPROVED: Reset can complete when:                                  |
//| - Price moves away from OB (original behavior)                     |
//| - Price touches a DIFFERENT OB (new behavior)                      |
//| - Price breaks through OB (mitigated) and a new candle forms       |
//+------------------------------------------------------------------+
void UpdateSMCSignalResetStatus()
{
   if(g_waitBuySignalReset && InpSignalStrategy == STRATEGY_SMC)
   {
      // BUY reset logic:
      // - Either price moves away from the OB zone, then touches again
      // - Or price touches a DIFFERENT OB than the one used to open the last order

      if(g_smcBuyResetRequired)
      {
         bool movedAway = !g_smcBuyTouchingNow;
         bool touchedDifferentOB = g_smcBuyTouchingNow && g_smcBuyTouchedOBPersist &&
                                    g_smcLastBuyOBUsed != "" &&
                                    g_smcBuyTouchedOBName != g_smcLastBuyOBUsed;

         if(movedAway || touchedDifferentOB)
         {
            // Phase 1: price moved away OR we touched a different OB.
            // IMPORTANT: once Phase 1 is complete, we must allow Phase 2 (touch again)
            // so we clear the "required" flag when movedAway happens.
            g_smcBuyResetPhaseComplete = true;

            if(touchedDifferentOB)
            {
               g_waitBuySignalReset = false;
               g_smcBuyResetRequired = false;
               g_smcBuyResetPhaseComplete = false;
               g_smcLastBuyOBUsed = "";
               Print("*** SMC BUY Signal Reset Complete - Touched DIFFERENT OB: ", g_smcBuyTouchedOBName, " ***");
            }
            else
            {
               // Allow Phase 2 to run on the next OB touch
               g_smcBuyResetRequired = false;
               Print("*** SMC BUY Reset Phase 1 Complete - Price moved away from OB ***");
            }
         }
      }
      else if(g_smcBuyResetPhaseComplete && g_smcBuyTouchedOBPersist)
      {
         g_waitBuySignalReset = false;
         g_smcBuyResetRequired = false;
         g_smcBuyResetPhaseComplete = false;
         g_smcLastBuyOBUsed = "";
         Print("*** SMC BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }

   if(g_waitSellSignalReset && InpSignalStrategy == STRATEGY_SMC)
   {
      if(g_smcSellResetRequired)
      {
         bool movedAway = !g_smcSellTouchingNow;
         bool touchedDifferentOB = g_smcSellTouchingNow && g_smcSellTouchedOBPersist &&
                                    g_smcLastSellOBUsed != "" &&
                                    g_smcSellTouchedOBName != g_smcLastSellOBUsed;

         if(movedAway || touchedDifferentOB)
         {
            // Phase 1 complete
            g_smcSellResetPhaseComplete = true;

            if(touchedDifferentOB)
            {
               g_waitSellSignalReset = false;
               g_smcSellResetRequired = false;
               g_smcSellResetPhaseComplete = false;
               g_smcLastSellOBUsed = "";
               Print("*** SMC SELL Signal Reset Complete - Touched DIFFERENT OB: ", g_smcSellTouchedOBName, " ***");
            }
            else
            {
               // Allow Phase 2 to run on the next OB touch
               g_smcSellResetRequired = false;
               Print("*** SMC SELL Reset Phase 1 Complete - Price moved away from OB ***");
            }
         }
      }
      else if(g_smcSellResetPhaseComplete && g_smcSellTouchedOBPersist)
      {
         g_waitSellSignalReset = false;
         g_smcSellResetRequired = false;
         g_smcSellResetPhaseComplete = false;
         g_smcLastSellOBUsed = "";
         Print("*** SMC SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Smart Money Concepts Signal                                |
//| NEW RULE: Check per-side, not global                               |
//| - BUY signal blocked only if BUY orders exist                      |
//| - SELL signal blocked only if SELL orders exist                    |
//+------------------------------------------------------------------+
string AnalyzeSMCSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpSMCTimeframe, 0);

   // Check which sides have open positions
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpSMCSignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastSMCSignalTime)
      {
         return "WAIT";
      }
      LastSMCSignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateSMCSignalResetStatus();
   
   // Return the SMC signal calculated in CalculateSMC()
   if(SMCSignal == "BUY")
   {
      // *** BLOCK BUY ONLY if BUY orders exist ***
      if(buyCount > 0)
      {
         return "WAIT";  // BUY side frozen
      }
      
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> SMC BUY Signal detected but waiting for reset (Phase 1: ", g_smcBuyResetPhaseComplete ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Smart Money Concepts BUY Signal Confirmed! (Price touched Bullish Order Block)");
      return "BUY";
   }
   else if(SMCSignal == "SELL")
   {
      // *** BLOCK SELL ONLY if SELL orders exist ***
      if(sellCount > 0)
      {
         return "WAIT";  // SELL side frozen
      }
      
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> SMC SELL Signal detected but waiting for reset (Phase 1: ", g_smcSellResetPhaseComplete ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Smart Money Concepts SELL Signal Confirmed! (Price touched Bearish Order Block)");
      return "SELL";
   }
   
   return "WAIT";
}

bool ExecuteBuy()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double lot = CalculateLotSize();
   
   Print("Executing BUY - CDC: ", CDCTrend, " | Mode: ", GetTradeModeString(), " | Lot Mode: ", EnumToString(InpLotMode));
   
   // Grid orders have no SL/TP - will use Close All
   if(trade.Buy(lot, _Symbol, price, 0, 0, "ZigZag++ Initial BUY"))
   {
      Print("BUY Success! Ticket: ", trade.ResultOrder());
      InitialBuyBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      GridBuyCount = 1;
      
      // *** SEND SIGNAL TO INDICATOR VIA GLOBAL VARIABLES ***
      // Encode PA pattern: 1=Hammer, 2=Engulf, 3=Tweezer, 4=MorningStar, 5=InsideCandle, 6=Hotdog, 7=ShootingStar, 8=OutsideCandle, 9=Pullback
      int paCode = EncodePAPattern(g_lastPABuyShift);
      GlobalVariableSet(GV_EA_BUY_SIGNAL, 1.0);
      GlobalVariableSet(GV_EA_BUY_PA, (double)paCode);
      GlobalVariableSet(GV_EA_BUY_TIME, (double)iTime(_Symbol, PERIOD_CURRENT, g_lastPABuyShift));
      Print(">>> Signal sent to Indicator: BUY | PA Code: ", paCode, " | Time: ", TimeToString(iTime(_Symbol, PERIOD_CURRENT, g_lastPABuyShift)));
      
      // *** RESET SMC TOUCH FLAGS AFTER ORDER EXECUTION ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         // Remember which OB was used to open this order (for reset comparisons)
         g_smcLastBuyOBUsed = g_smcBuyTouchedOBName;

         // NEW: consume/remove the OB that triggered this entry (remove zone immediately)
         ConsumeSMCOrderBlock(g_smcLastBuyOBUsed, true);

         g_smcBuyTouchedOBPersist = false;
         g_smcBuyTouchedOB = false;
         g_smcBuyTouchedOBName = "";
         g_smcBuyTouchTime = 0;
         Print(">>> SMC BUY touch flags reset after order execution | LastOBUsed=", g_smcLastBuyOBUsed);
      }
      return true;
   }
   
   Print("BUY Failed! Retcode: ", trade.ResultRetcode(), " | LastError: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Execute SELL order                                                 |
//+------------------------------------------------------------------+
bool ExecuteSell()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = CalculateLotSize();
   
   Print("Executing SELL - CDC: ", CDCTrend, " | Mode: ", GetTradeModeString(), " | Lot Mode: ", EnumToString(InpLotMode));
   
   // Grid orders have no SL/TP - will use Close All
   if(trade.Sell(lot, _Symbol, price, 0, 0, "ZigZag++ Initial SELL"))
   {
      Print("SELL Success! Ticket: ", trade.ResultOrder());
      InitialSellBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      GridSellCount = 1;
      
      // *** SEND SIGNAL TO INDICATOR VIA GLOBAL VARIABLES ***
      int paCode = EncodePAPattern(g_lastPASellShift);
      GlobalVariableSet(GV_EA_SELL_SIGNAL, 1.0);
      GlobalVariableSet(GV_EA_SELL_PA, (double)paCode);
      GlobalVariableSet(GV_EA_SELL_TIME, (double)iTime(_Symbol, PERIOD_CURRENT, g_lastPASellShift));
      Print(">>> Signal sent to Indicator: SELL | PA Code: ", paCode, " | Time: ", TimeToString(iTime(_Symbol, PERIOD_CURRENT, g_lastPASellShift)));
      
      // *** RESET SMC TOUCH FLAGS AFTER ORDER EXECUTION ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         // Remember which OB was used to open this order (for reset comparisons)
         g_smcLastSellOBUsed = g_smcSellTouchedOBName;

         // NEW: consume/remove the OB that triggered this entry (remove zone immediately)
         ConsumeSMCOrderBlock(g_smcLastSellOBUsed, false);

         g_smcSellTouchedOBPersist = false;
         g_smcSellTouchedOB = false;
         g_smcSellTouchedOBName = "";
         g_smcSellTouchTime = 0;
         Print(">>> SMC SELL touch flags reset after order execution | LastOBUsed=", g_smcLastSellOBUsed);
      }
      return true;
   }
   
   Print("SELL Failed! Retcode: ", trade.ResultRetcode(), " | LastError: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Count open orders for this EA                                      |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Parse time string "hh:mm" to minutes from midnight               |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr)
{
   if(StringLen(timeStr) < 5) return -1;
   
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0) return -1;
   
   string hourStr = StringSubstr(timeStr, 0, colonPos);
   string minStr = StringSubstr(timeStr, colonPos + 1, 2);
   
   int hour = (int)StringToInteger(hourStr);
   int min = (int)StringToInteger(minStr);
   
   if(hour < 0 || hour > 23 || min < 0 || min > 59) return -1;
   
   return hour * 60 + min;
}

//+------------------------------------------------------------------+
//| Parse session string "hh:mm-hh:mm" and check if time is in range |
//+------------------------------------------------------------------+
bool IsTimeInSession(string session, int currentMinutes)
{
   if(StringLen(session) < 11) return false;  // Minimum "00:00-23:59"
   
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   
   string startStr = StringSubstr(session, 0, dashPos);
   string endStr = StringSubstr(session, dashPos + 1);
   
   int startMinutes = ParseTimeToMinutes(startStr);
   int endMinutes = ParseTimeToMinutes(endStr);
   
   if(startMinutes < 0 || endMinutes < 0) return false;
   
   // Handle normal case (e.g., 08:00-20:00)
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   }
   // Handle overnight case (e.g., 22:00-06:00)
   else
   {
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check if current day is allowed for trading                       |
//+------------------------------------------------------------------+
bool IsTradableDay(int dayOfWeek)
{
   switch(dayOfWeek)
   {
      case 0: return InpTradeSunday;
      case 1: return InpTradeMonday;
      case 2: return InpTradeTuesday;
      case 3: return InpTradeWednesday;
      case 4: return InpTradeThursday;
      case 5: return InpTradeFriday;
      case 6: return InpTradeSaturday;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Check if trading day is allowed
   if(!IsTradableDay(dt.day_of_week))
      return false;
   
   // Calculate current time in minutes from midnight
   int currentMinutes = dt.hour * 60 + dt.min;
   
   // Check if Friday - use Friday sessions if available
   bool isFriday = (dt.day_of_week == 5);
   
   if(isFriday)
   {
      // Check Friday sessions first (if any are set)
      bool hasFridaySessions = (StringLen(InpFridaySession1) >= 5 || 
                                 StringLen(InpFridaySession2) >= 5 || 
                                 StringLen(InpFridaySession3) >= 5);
      
      if(hasFridaySessions)
      {
         // Use Friday sessions
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes))
            return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes))
            return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes))
            return true;
            
         return false;  // Friday has special sessions but not in any
      }
      // If no Friday sessions set, fall through to normal sessions
   }
   
   // Check normal sessions
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes))
      return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes))
      return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes))
      return true;
   
   // If no sessions are set, allow trading all day
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Update chart comment                                               |
//| หมายเหตุ: ไม่ใช้ Comment() แล้ว เพราะมี Dashboard แสดงข้อมูลแทน      |
//+------------------------------------------------------------------+
void UpdateChartComment(string signal, string reason = "")
{
   // Dashboard แสดงข้อมูลแล้ว ไม่ต้องใช้ Comment() ซ้อนกัน
   // เก็บค่า signal และ reason ไว้ใช้ใน Dashboard
   // ไม่เรียก Comment() เพื่อป้องกันข้อความซ้อนทับ Dashboard
}
//+------------------------------------------------------------------+`;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 border-b border-border bg-background/95 backdrop-blur">
        <div className="container py-4 flex items-center justify-between">
          <Link 
            to="/developer" 
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            กลับหน้า Developer Dashboard
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="container pt-12 pb-8">
        <div className="max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/30 mb-6">
            <FileCode className="w-4 h-4 text-primary" />
            <span className="text-sm font-mono text-primary">MQL5 Expert Advisor v5.0 + Grid + Auto Scale</span>
          </div>
          
          <h1 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            ZigZag++ <span className="text-primary">CDC Action Zone</span> EA + Grid
          </h1>
          
          <p className="text-lg text-muted-foreground">
            EA ที่ใช้ ZigZag++ (DevLucem) พร้อม CDC Trend Filter, Grid Trading System และ Auto Balance Scaling
          </p>
        </div>
      </section>

      {/* Warning */}
      <section className="container pb-8">
        <div className="max-w-4xl mx-auto">
          <div className="p-6 rounded-2xl bg-destructive/10 border border-destructive/30 flex items-start gap-4">
            <AlertTriangle className="w-6 h-6 text-destructive shrink-0 mt-1" />
            <div>
              <h3 className="font-bold text-destructive mb-2">คำเตือนสำคัญ!</h3>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>โค้ดนี้เป็นตัวอย่างเพื่อ<strong>การศึกษาเท่านั้น</strong></li>
                <li><strong>ทดสอบบน Demo Account</strong> อย่างน้อย 1-3 เดือนก่อนใช้เงินจริง</li>
                <li>ไม่มี EA ใดรับประกันกำไร - การเทรดมีความเสี่ยง</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">คุณสมบัติของ EA v4.0</h2>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-5 gap-4">
            <div className="glass-card rounded-xl p-5 text-center border-2 border-primary/30">
              <div className="w-12 h-12 rounded-xl bg-primary/20 text-primary flex items-center justify-center mx-auto mb-3">
                <TrendingUp className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">ZigZag++</h3>
              <p className="text-sm text-muted-foreground">พร้อม Labels HH/HL/LH/LL</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center border-2 border-bull/30">
              <div className="w-12 h-12 rounded-xl bg-bull/20 text-bull flex items-center justify-center mx-auto mb-3">
                <Filter className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">CDC Trend Filter</h3>
              <p className="text-sm text-muted-foreground">ฟิลเตอร์เทรนด์จาก TradingView</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center border-2 border-purple-500/30">
              <div className="w-12 h-12 rounded-xl bg-purple-500/20 text-purple-500 flex items-center justify-center mx-auto mb-3">
                <Settings className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Grid Trading</h3>
              <p className="text-sm text-muted-foreground">Loss Side & Profit Side พร้อม Custom Lot</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-bear/20 text-bear flex items-center justify-center mx-auto mb-3">
                <Shield className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Risk Management</h3>
              <p className="text-sm text-muted-foreground">คำนวณ Lot Size ตาม % เสี่ยง</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-secondary text-muted-foreground flex items-center justify-center mx-auto mb-3">
                <Settings className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Visual Display</h3>
              <p className="text-sm text-muted-foreground">แสดงเส้น MA และโซนสีบน chart</p>
            </div>
          </div>
        </div>
      </section>

      {/* CDC Action Zone Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">CDC Action Zone Logic</h2>
          
          <div className="glass-card rounded-2xl p-6 mb-6">
            <h3 className="font-semibold text-foreground mb-4">สูตรการคำนวณ (จาก TradingView)</h3>
            <div className="bg-secondary/50 rounded-xl p-4 font-mono text-sm space-y-2">
              <p><span className="text-primary">AP</span> = EMA(OHLC4, 2)</p>
              <p><span className="text-bear">Fast</span> = EMA(AP, 12)</p>
              <p><span className="text-bull">Slow</span> = EMA(AP, 26)</p>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bull">Green Zone</h3>
                  <p className="text-xs text-muted-foreground">BUY ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    Fast EMA {">"} Slow EMA (Bullish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    AP {">"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bear">Red Zone</h3>
                  <p className="text-xs text-muted-foreground">SELL ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    Fast EMA {"<"} Slow EMA (Bearish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    AP {"<"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6 mt-6">
            <div className="glass-card rounded-xl p-5 border border-yellow-500/30">
              <h4 className="font-semibold text-yellow-500 mb-2">Yellow Zone (Weak Bull)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {">"} Slow แต่ AP {"<"} Fast - เทรนด์ขาขึ้นแต่โมเมนตัมอ่อน
              </p>
            </div>
            
            <div className="glass-card rounded-xl p-5 border border-blue-500/30">
              <h4 className="font-semibold text-blue-500 mb-2">Blue Zone (Weak Bear)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {"<"} Slow แต่ AP {">"} Fast - เทรนด์ขาลงแต่โมเมนตัมอ่อน
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Parameters Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">Parameters ทั้งหมด</h2>
          
          {/* ZigZag++ Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-primary/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-primary flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                ZigZag++ Settings (Based on DevLucem)
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDepth</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Depth - จำนวนแท่งสำหรับหา Swing</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDeviation</td>
                  <td className="px-4 py-3">5</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Deviation (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBackstep</td>
                  <td className="px-4 py-3">2</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Backstep</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBullColor</td>
                  <td className="px-4 py-3 text-bull">clrLime</td>
                  <td className="px-4 py-3 text-muted-foreground">สี Labels LL/HL (Low points)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBearColor</td>
                  <td className="px-4 py-3 text-bear">clrRed</td>
                  <td className="px-4 py-3 text-muted-foreground">สี Labels HH/LH (High points)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpShowLabels</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดง HH/HL/LH/LL labels บน chart</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpShowLines</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดงเส้น ZigZag บน chart</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm text-muted-foreground">
                <span className="text-primary font-semibold">ZigZag++ </span>
                อ้างอิงจาก TradingView indicator โดย DevLucem - แสดง Labels อัตโนมัติ:
              </p>
              <div className="flex flex-wrap gap-2 mt-2">
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">HH - Higher High</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">LH - Lower High</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">HL - Higher Low</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">LL - Lower Low</span>
              </div>
            </div>
          </div>
          
          {/* CDC Action Zone Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-bull/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-bull flex items-center gap-2">
                <Filter className="w-4 h-4" />
                CDC Action Zone Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpUseCDCFilter</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดการใช้ CDC Action Zone Filter</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCTimeframe</td>
                  <td className="px-4 py-3">D1</td>
                  <td className="px-4 py-3 text-muted-foreground">Timeframe สำหรับคำนวณ CDC (D1, H4, H1, etc.)</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCFastPeriod</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Fast EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCSlowPeriod</td>
                  <td className="px-4 py-3">26</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Slow EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpShowCDCLines</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดงเส้น EMA และแถบสีบน chart</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Trade Mode Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-yellow-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-yellow-500 flex items-center gap-2">
                <Settings className="w-4 h-4" />
                Trade Mode Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-yellow-500/5">
                  <td className="px-4 py-3 font-mono text-yellow-500">InpTradeMode</td>
                  <td className="px-4 py-3">Buy and Sell</td>
                  <td className="px-4 py-3 text-muted-foreground">เลือก Buy/Sell, Buy Only, หรือ Sell Only</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm text-muted-foreground mb-2">ตัวเลือก Trade Mode:</p>
              <div className="flex flex-wrap gap-2">
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-foreground/10 text-foreground">Buy and Sell - เทรดทั้ง 2 ทิศทาง</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">Buy Only - ซื้อเท่านั้น</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">Sell Only - ขายเท่านั้น</span>
              </div>
            </div>
          </div>
          
          {/* Re-Entry Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-purple-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-purple-500 flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                Re-Entry Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-purple-500/5">
                  <td className="px-4 py-3 font-mono text-purple-500">InpUseReEntry</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดฟีเจอร์ Re-Entry</td>
                </tr>
                <tr className="bg-purple-500/5">
                  <td className="px-4 py-3 font-mono text-purple-500">InpReEntryMaxCount</td>
                  <td className="px-4 py-3">3</td>
                  <td className="px-4 py-3 text-muted-foreground">จำนวน Re-Entry สูงสุดต่อทิศทาง</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm font-semibold text-foreground mb-3">Re-Entry Logic:</p>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="p-3 rounded-lg bg-bull/10 border border-bull/30">
                  <p className="font-semibold text-bull mb-2">BUY Re-Entry</p>
                  <ul className="text-xs text-muted-foreground space-y-1">
                    <li>• ออเดอร์เดิมปิด (TP/SL)</li>
                    <li>• Swing Point ล่าสุด = LL หรือ LH</li>
                    <li>• CDC Zone = BULLISH (สีเขียว)</li>
                    <li>→ เปิด BUY ใหม่</li>
                  </ul>
                </div>
                <div className="p-3 rounded-lg bg-bear/10 border border-bear/30">
                  <p className="font-semibold text-bear mb-2">SELL Re-Entry</p>
                  <ul className="text-xs text-muted-foreground space-y-1">
                    <li>• ออเดอร์เดิมปิด (TP/SL)</li>
                    <li>• Swing Point ล่าสุด = HH หรือ HL</li>
                    <li>• CDC Zone = BEARISH (สีแดง)</li>
                    <li>→ เปิด SELL ใหม่</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
          
          {/* Trading Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-secondary px-4 py-3 border-b border-border">
              <h3 className="font-bold text-foreground flex items-center gap-2">
                <TrendingDown className="w-4 h-4" />
                Trading Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpLotSize</td>
                  <td className="px-4 py-3">0.01</td>
                  <td className="px-4 py-3 text-muted-foreground">Lot Size เริ่มต้น</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpStopLoss</td>
                  <td className="px-4 py-3">50</td>
                  <td className="px-4 py-3 text-muted-foreground">Stop Loss (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpTakeProfit</td>
                  <td className="px-4 py-3">100</td>
                  <td className="px-4 py-3 text-muted-foreground">Take Profit (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpMagicNumber</td>
                  <td className="px-4 py-3">123456</td>
                  <td className="px-4 py-3 text-muted-foreground">Magic Number สำหรับระบุ Order</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Risk Management */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-bear/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-bear flex items-center gap-2">
                <Shield className="w-4 h-4" />
                Risk Management
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-bear/5">
                  <td className="px-4 py-3 font-mono text-bear">InpMaxRiskPercent</td>
                  <td className="px-4 py-3">2.0</td>
                  <td className="px-4 py-3 text-muted-foreground">% ความเสี่ยงสูงสุดต่อออเดอร์</td>
                </tr>
                <tr className="bg-bear/5">
                  <td className="px-4 py-3 font-mono text-bear">InpMaxOrders</td>
                  <td className="px-4 py-3">1</td>
                  <td className="px-4 py-3 text-muted-foreground">จำนวนออเดอร์สูงสุดที่เปิดได้</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Time Filter */}
          <div className="glass-card rounded-2xl overflow-hidden">
            <div className="bg-blue-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-blue-500 flex items-center gap-2">
                <Info className="w-4 h-4" />
                Time Filter
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpUseTimeFilter</td>
                  <td className="px-4 py-3">false</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดฟิลเตอร์เวลา</td>
                </tr>
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpStartHour</td>
                  <td className="px-4 py-3">8</td>
                  <td className="px-4 py-3 text-muted-foreground">ชั่วโมงเริ่มเทรด</td>
                </tr>
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpEndHour</td>
                  <td className="px-4 py-3">20</td>
                  <td className="px-4 py-3 text-muted-foreground">ชั่วโมงหยุดเทรด</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Trading Logic */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">กลยุทธ์การเทรด (รวม CDC Filter)</h2>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull/20 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-bull" />
                </div>
                <h3 className="text-lg font-bold text-bull">สัญญาณ BUY</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">1.</span>
                  <span>Structure: มี <strong className="text-bull">HH + HL</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bull">HL</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bull font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>GREEN</strong> (Bullish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bull">BUY</strong></span>
                </li>
              </ol>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear/20 flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-bear" />
                </div>
                <h3 className="text-lg font-bold text-bear">สัญญาณ SELL</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">1.</span>
                  <span>Structure: มี <strong className="text-bear">LL + LH</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bear">LH</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bear font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>RED</strong> (Bearish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bear">SELL</strong></span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </section>

      {/* Installation */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <StepCard
            step={1}
            title="วิธีติดตั้ง EA"
            description="ทำตามขั้นตอนเหล่านี้เพื่อติดตั้ง EA บน MetaTrader 5"
            icon={<Download className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-secondary/50">
                <ol className="space-y-2 text-sm text-muted-foreground">
                  <li><span className="font-mono text-primary">1.</span> เปิด MetaTrader 5</li>
                  <li><span className="font-mono text-primary">2.</span> กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">File</kbd> → <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">Open Data Folder</kbd></li>
                  <li><span className="font-mono text-primary">3.</span> ไปที่โฟลเดอร์ <code className="text-primary">MQL5 → Experts</code></li>
                  <li><span className="font-mono text-primary">4.</span> สร้างไฟล์ใหม่ชื่อ <code className="text-primary">Moneyx_Smart_Gold_EA.mq5</code></li>
                  <li><span className="font-mono text-primary">5.</span> วางโค้ดด้านล่างลงไป แล้วบันทึก</li>
                  <li><span className="font-mono text-primary">6.</span> กลับไป MT5 กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">F7</kbd> เพื่อ Compile</li>
                  <li><span className="font-mono text-primary">7.</span> ลาก EA ไปวางบน Chart</li>
                  <li><span className="font-mono text-primary">8.</span> ตั้งค่าพารามิเตอร์ → กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">OK</kbd></li>
                </ol>
              </div>
              
              <div className="flex items-start gap-3 p-4 rounded-xl bg-primary/10 border border-primary/30">
                <Info className="w-5 h-5 text-primary shrink-0 mt-0.5" />
                <div className="text-sm text-muted-foreground">
                  <strong className="text-foreground">สำคัญ:</strong> ต้องเปิด Auto Trading บน MT5 ด้วย (ปุ่ม AutoTrading บน toolbar)
                </div>
              </div>
            </div>
          </StepCard>
        </div>
      </section>

      {/* Full Code */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">โค้ด EA ฉบับเต็ม (v5.1 + Dashboard Panel)</h2>
          <CodeBlock
            code={fullEACode}
            language="MQL5"
            filename="Moneyx_Smart_Gold_EA.mq5"
          />
        </div>
      </section>

      {/* Tips */}
      <section className="container py-12">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">เคล็ดลับการใช้งาน</h2>
          
          <div className="grid md:grid-cols-2 gap-4">
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- ใช้ CDC Filter TF ที่สูงกว่า Entry TF (เช่น Entry H1, Filter D1)</li>
                <li>- Backtest บน Strategy Tester ดูแถบสีและเส้น MA</li>
                <li>- ทดสอบบน Demo Account อย่างน้อย 1 เดือน</li>
                <li>- ปรับ Fast/Slow Period ให้เหมาะกับคู่เงิน</li>
              </ul>
            </div>
            
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ไม่ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- เปิด CDC Filter TF เดียวกับ Entry TF</li>
                <li>- ใช้เงินจริงโดยไม่ทดสอบ</li>
                <li>- เทรดเมื่อ Zone เป็น Yellow/Blue (โมเมนตัมอ่อน)</li>
                <li>- ปล่อยทิ้งไว้โดยไม่ตรวจสอบ</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8">
        <div className="container text-center text-sm text-muted-foreground">
          <p>โค้ดนี้เป็นตัวอย่างเพื่อการศึกษา - ไม่รับประกันผลกำไร กรุณาศึกษาและทดสอบอย่างละเอียด</p>
        </div>
      </footer>
    </div>
  );
};

export default MT5EAGuide;