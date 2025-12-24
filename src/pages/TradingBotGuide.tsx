import { Link } from 'react-router-dom';
import { ArrowLeft, Database, Calculator, Brain, Send, AlertTriangle, CheckCircle2, XCircle } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const TradingBotGuide = () => {
  const step1Code = `// ไฟล์: supabase/functions/fetch-candles/index.ts
// หน้าที่: ดึงข้อมูลแท่งเทียนจาก Binance

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ประเภทข้อมูลแท่งเทียน
interface Candle {
  time: number;      // เวลา (timestamp)
  open: number;      // ราคาเปิด
  high: number;      // ราคาสูงสุด
  low: number;       // ราคาต่ำสุด
  close: number;     // ราคาปิด
  volume: number;    // ปริมาณการซื้อขาย
}

serve(async (req) => {
  // รองรับ CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // รับพารามิเตอร์จาก request
    const { symbol, interval, limit } = await req.json();
    
    // symbol = "BTCUSDT" (คู่เหรียญ)
    // interval = "1h" (1 ชั่วโมง), "4h", "1d" ฯลฯ
    // limit = 100 (จำนวนแท่งเทียน)

    console.log(\`กำลังดึงข้อมูล \${symbol} (\${interval}) จำนวน \${limit} แท่ง\`);

    // เรียก Binance API
    const response = await fetch(
      \`https://api.binance.com/api/v3/klines?symbol=\${symbol}&interval=\${interval}&limit=\${limit}\`
    );

    if (!response.ok) {
      throw new Error('ไม่สามารถดึงข้อมูลจาก Binance ได้');
    }

    const rawData = await response.json();

    // แปลงข้อมูลให้อ่านง่าย
    // Binance ส่งข้อมูลเป็น array: [time, open, high, low, close, volume, ...]
    const candles: Candle[] = rawData.map((item: any[]) => ({
      time: item[0],                    // index 0 = เวลา
      open: parseFloat(item[1]),        // index 1 = ราคาเปิด
      high: parseFloat(item[2]),        // index 2 = ราคาสูงสุด
      low: parseFloat(item[3]),         // index 3 = ราคาต่ำสุด
      close: parseFloat(item[4]),       // index 4 = ราคาปิด
      volume: parseFloat(item[5]),      // index 5 = ปริมาณ
    }));

    console.log(\`ดึงข้อมูลสำเร็จ: \${candles.length} แท่ง\`);
    console.log(\`ราคาล่าสุด: \${candles[candles.length - 1].close}\`);

    return new Response(
      JSON.stringify({ candles }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});`;

  const step2Code = `// ไฟล์: src/utils/zigzag.ts
// หน้าที่: คำนวณ ZigZag และหา Swing Points (HH, HL, LH, LL)

// ประเภทข้อมูลแท่งเทียน
interface Candle {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
}

// ประเภท Swing Point
interface SwingPoint {
  index: number;           // ตำแหน่งในข้อมูล
  time: number;            // เวลา
  price: number;           // ราคา
  type: 'high' | 'low';    // จุดสูงสุด หรือ จุดต่ำสุด
  pattern: 'HH' | 'HL' | 'LH' | 'LL';  // รูปแบบ
}

/**
 * ฟังก์ชันหลัก: คำนวณ ZigZag
 * 
 * @param candles - ข้อมูลแท่งเทียน
 * @param depth - จำนวนแท่งที่ใช้หา high/low (ค่าเริ่มต้น 12)
 * @returns array ของ SwingPoint
 */
export function calculateZigZag(
  candles: Candle[],
  depth: number = 12
): SwingPoint[] {
  
  const swingPoints: SwingPoint[] = [];
  
  // ต้องมีข้อมูลอย่างน้อย depth * 2 แท่ง
  if (candles.length < depth * 2) {
    console.log('ข้อมูลไม่เพียงพอ');
    return [];
  }

  // วนลูปหา Swing Points
  // เริ่มจาก index = depth เพื่อให้มีแท่งก่อนหน้าเพียงพอ
  for (let i = depth; i < candles.length - depth; i++) {
    
    // ========== หา Swing High ==========
    // Swing High = แท่งที่มี high สูงกว่าแท่งรอบข้างทั้งหมด
    
    let isSwingHigh = true;
    const currentHigh = candles[i].high;
    
    // เช็คแท่งทางซ้าย (ก่อนหน้า)
    for (let j = 1; j <= depth; j++) {
      if (candles[i - j].high >= currentHigh) {
        isSwingHigh = false;
        break;
      }
    }
    
    // เช็คแท่งทางขวา (หลังจาก)
    if (isSwingHigh) {
      for (let j = 1; j <= depth; j++) {
        if (candles[i + j].high >= currentHigh) {
          isSwingHigh = false;
          break;
        }
      }
    }

    // ========== หา Swing Low ==========
    // Swing Low = แท่งที่มี low ต่ำกว่าแท่งรอบข้างทั้งหมด
    
    let isSwingLow = true;
    const currentLow = candles[i].low;
    
    // เช็คแท่งทางซ้าย
    for (let j = 1; j <= depth; j++) {
      if (candles[i - j].low <= currentLow) {
        isSwingLow = false;
        break;
      }
    }
    
    // เช็คแท่งทางขวา
    if (isSwingLow) {
      for (let j = 1; j <= depth; j++) {
        if (candles[i + j].low <= currentLow) {
          isSwingLow = false;
          break;
        }
      }
    }

    // ========== บันทึก Swing Point ==========
    
    if (isSwingHigh) {
      // หา Swing High ก่อนหน้า เพื่อเปรียบเทียบ
      const previousHighs = swingPoints.filter(p => p.type === 'high');
      const lastHigh = previousHighs[previousHighs.length - 1];
      
      // กำหนด pattern
      let pattern: 'HH' | 'LH';
      if (lastHigh) {
        // ถ้า high ปัจจุบัน > high ก่อนหน้า = Higher High (HH)
        // ถ้า high ปัจจุบัน < high ก่อนหน้า = Lower High (LH)
        pattern = currentHigh > lastHigh.price ? 'HH' : 'LH';
      } else {
        pattern = 'HH'; // จุดแรกให้เป็น HH
      }

      swingPoints.push({
        index: i,
        time: candles[i].time,
        price: currentHigh,
        type: 'high',
        pattern: pattern
      });

      console.log(\`พบ Swing High ที่ index \${i}: \${currentHigh} (\${pattern})\`);
    }

    if (isSwingLow) {
      // หา Swing Low ก่อนหน้า
      const previousLows = swingPoints.filter(p => p.type === 'low');
      const lastLow = previousLows[previousLows.length - 1];
      
      let pattern: 'HL' | 'LL';
      if (lastLow) {
        // ถ้า low ปัจจุบัน > low ก่อนหน้า = Higher Low (HL)
        // ถ้า low ปัจจุบัน < low ก่อนหน้า = Lower Low (LL)
        pattern = currentLow > lastLow.price ? 'HL' : 'LL';
      } else {
        pattern = 'HL';
      }

      swingPoints.push({
        index: i,
        time: candles[i].time,
        price: currentLow,
        type: 'low',
        pattern: pattern
      });

      console.log(\`พบ Swing Low ที่ index \${i}: \${currentLow} (\${pattern})\`);
    }
  }

  // เรียงตาม index
  swingPoints.sort((a, b) => a.index - b.index);
  
  console.log(\`พบ Swing Points ทั้งหมด \${swingPoints.length} จุด\`);
  
  return swingPoints;
}`;

  const step3Code = `// ไฟล์: src/utils/trading-signal.ts
// หน้าที่: วิเคราะห์ Swing Points และสร้างสัญญาณเทรด

interface SwingPoint {
  index: number;
  time: number;
  price: number;
  type: 'high' | 'low';
  pattern: 'HH' | 'HL' | 'LH' | 'LL';
}

// ประเภทสัญญาณ
type Signal = 'BUY' | 'SELL' | 'HOLD';

// ผลลัพธ์การวิเคราะห์
interface SignalResult {
  signal: Signal;
  reason: string;
  confidence: number;  // 0-100
  entryPrice?: number;
  stopLoss?: number;
  takeProfit?: number;
}

/**
 * วิเคราะห์โครงสร้างตลาด
 * 
 * หลักการ:
 * - Uptrend (ขาขึ้น) = HH + HL ติดต่อกัน
 * - Downtrend (ขาลง) = LL + LH ติดต่อกัน
 */
export function analyzeMarketStructure(
  swingPoints: SwingPoint[]
): 'UPTREND' | 'DOWNTREND' | 'SIDEWAYS' {
  
  if (swingPoints.length < 4) {
    return 'SIDEWAYS';
  }

  // ดู 4 จุดล่าสุด
  const recent = swingPoints.slice(-4);
  
  // นับ pattern
  const hhCount = recent.filter(p => p.pattern === 'HH').length;
  const hlCount = recent.filter(p => p.pattern === 'HL').length;
  const llCount = recent.filter(p => p.pattern === 'LL').length;
  const lhCount = recent.filter(p => p.pattern === 'LH').length;

  console.log(\`Pattern Count: HH=\${hhCount}, HL=\${hlCount}, LL=\${llCount}, LH=\${lhCount}\`);

  // Uptrend = มี HH และ HL
  if (hhCount >= 1 && hlCount >= 1) {
    return 'UPTREND';
  }

  // Downtrend = มี LL และ LH
  if (llCount >= 1 && lhCount >= 1) {
    return 'DOWNTREND';
  }

  return 'SIDEWAYS';
}

/**
 * สร้างสัญญาณเทรด
 * 
 * กลยุทธ์:
 * 1. Uptrend → รอซื้อที่ HL (pullback)
 * 2. Downtrend → รอขายที่ LH (bounce)
 */
export function generateSignal(
  swingPoints: SwingPoint[],
  currentPrice: number
): SignalResult {

  if (swingPoints.length < 4) {
    return {
      signal: 'HOLD',
      reason: 'ข้อมูลไม่เพียงพอ (ต้องการอย่างน้อย 4 Swing Points)',
      confidence: 0
    };
  }

  const structure = analyzeMarketStructure(swingPoints);
  const lastPoint = swingPoints[swingPoints.length - 1];
  const secondLast = swingPoints[swingPoints.length - 2];

  console.log(\`โครงสร้างตลาด: \${structure}\`);
  console.log(\`จุดล่าสุด: \${lastPoint.pattern} ที่ราคา \${lastPoint.price}\`);

  // ========== สัญญาณซื้อ (BUY) ==========
  if (structure === 'UPTREND') {
    // รอซื้อที่ HL
    if (lastPoint.type === 'low' && lastPoint.pattern === 'HL') {
      
      // หา HH ก่อนหน้าเพื่อตั้ง Take Profit
      const lastHigh = swingPoints
        .filter(p => p.type === 'high')
        .pop();
      
      // หา LL ก่อนหน้าเพื่อตั้ง Stop Loss
      const lastLow = swingPoints
        .filter(p => p.type === 'low' && p.index < lastPoint.index)
        .pop();

      return {
        signal: 'BUY',
        reason: \`Uptrend + เกิด Higher Low (HL) ที่ \${lastPoint.price}\`,
        confidence: 75,
        entryPrice: lastPoint.price,
        stopLoss: lastLow ? lastLow.price * 0.99 : lastPoint.price * 0.98,
        takeProfit: lastHigh ? lastHigh.price * 1.02 : lastPoint.price * 1.05
      };
    }
  }

  // ========== สัญญาณขาย (SELL) ==========
  if (structure === 'DOWNTREND') {
    // รอขายที่ LH
    if (lastPoint.type === 'high' && lastPoint.pattern === 'LH') {
      
      const lastLow = swingPoints
        .filter(p => p.type === 'low')
        .pop();
      
      const lastHigh = swingPoints
        .filter(p => p.type === 'high' && p.index < lastPoint.index)
        .pop();

      return {
        signal: 'SELL',
        reason: \`Downtrend + เกิด Lower High (LH) ที่ \${lastPoint.price}\`,
        confidence: 75,
        entryPrice: lastPoint.price,
        stopLoss: lastHigh ? lastHigh.price * 1.01 : lastPoint.price * 1.02,
        takeProfit: lastLow ? lastLow.price * 0.98 : lastPoint.price * 0.95
      };
    }
  }

  // ========== รอ (HOLD) ==========
  return {
    signal: 'HOLD',
    reason: \`\${structure} - รอสัญญาณที่ชัดเจนกว่านี้\`,
    confidence: 30
  };
}`;

  const step4Code = `// ไฟล์: supabase/functions/execute-trade/index.ts
// หน้าที่: ส่งคำสั่งซื้อขายไปยัง Binance

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createHmac } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ประเภทคำสั่ง
interface TradeOrder {
  symbol: string;        // เช่น "BTCUSDT"
  side: 'BUY' | 'SELL';  // ซื้อ หรือ ขาย
  quantity: number;      // จำนวน
  stopLoss?: number;     // ราคา Stop Loss
  takeProfit?: number;   // ราคา Take Profit
}

/**
 * สร้าง signature สำหรับ Binance API
 * Binance ต้องการ HMAC SHA256 signature
 */
function createSignature(queryString: string, secretKey: string): string {
  const encoder = new TextEncoder();
  const key = encoder.encode(secretKey);
  const data = encoder.encode(queryString);
  
  // สร้าง HMAC SHA256
  const hmac = createHmac('sha256', key);
  hmac.update(data);
  return hmac.digest('hex');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // ดึง API Keys จาก environment
    const apiKey = Deno.env.get('BINANCE_API_KEY');
    const secretKey = Deno.env.get('BINANCE_SECRET_KEY');

    if (!apiKey || !secretKey) {
      throw new Error('ไม่พบ API Keys - กรุณาตั้งค่าใน Supabase Secrets');
    }

    // รับคำสั่งจาก request
    const order: TradeOrder = await req.json();
    
    console.log('='.repeat(50));
    console.log('รับคำสั่งเทรด:');
    console.log(\`  Symbol: \${order.symbol}\`);
    console.log(\`  Side: \${order.side}\`);
    console.log(\`  Quantity: \${order.quantity}\`);
    console.log('='.repeat(50));

    // ========== ส่งคำสั่ง Market Order ==========
    
    const timestamp = Date.now();
    
    // สร้าง query string
    const params = new URLSearchParams({
      symbol: order.symbol,
      side: order.side,
      type: 'MARKET',           // คำสั่ง Market (ซื้อ/ขายทันที)
      quantity: order.quantity.toString(),
      timestamp: timestamp.toString(),
    });

    // สร้าง signature
    const signature = createSignature(params.toString(), secretKey);
    params.append('signature', signature);

    // ส่งคำสั่งไป Binance
    console.log('กำลังส่งคำสั่งไป Binance...');
    
    const response = await fetch(
      \`https://api.binance.com/api/v3/order?\${params.toString()}\`,
      {
        method: 'POST',
        headers: {
          'X-MBX-APIKEY': apiKey,
        },
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error('Binance Error:', result);
      throw new Error(result.msg || 'เกิดข้อผิดพลาดจาก Binance');
    }

    console.log('คำสั่งสำเร็จ!');
    console.log(\`  Order ID: \${result.orderId}\`);
    console.log(\`  ราคาเฉลี่ย: \${result.fills?.[0]?.price || 'N/A'}\`);

    // ========== ส่ง Stop Loss (ถ้ามี) ==========
    
    if (order.stopLoss) {
      console.log(\`กำลังตั้ง Stop Loss ที่ \${order.stopLoss}...\`);
      
      const slParams = new URLSearchParams({
        symbol: order.symbol,
        side: order.side === 'BUY' ? 'SELL' : 'BUY',  // ตรงข้าม
        type: 'STOP_LOSS_LIMIT',
        quantity: order.quantity.toString(),
        price: order.stopLoss.toString(),
        stopPrice: order.stopLoss.toString(),
        timeInForce: 'GTC',
        timestamp: Date.now().toString(),
      });

      const slSignature = createSignature(slParams.toString(), secretKey);
      slParams.append('signature', slSignature);

      await fetch(
        \`https://api.binance.com/api/v3/order?\${slParams.toString()}\`,
        {
          method: 'POST',
          headers: { 'X-MBX-APIKEY': apiKey },
        }
      );
      
      console.log('ตั้ง Stop Loss สำเร็จ!');
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId: result.orderId,
        executedQty: result.executedQty,
        status: result.status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Trade Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});`;

  const step5Code = `// ไฟล์: src/hooks/useTradingBot.ts
// หน้าที่: รวมทุกอย่างเข้าด้วยกัน - Hook หลักสำหรับ Trading Bot

import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { calculateZigZag } from '@/utils/zigzag';
import { generateSignal, SignalResult } from '@/utils/trading-signal';

interface BotState {
  isRunning: boolean;
  lastSignal: SignalResult | null;
  swingPoints: SwingPoint[];
  error: string | null;
}

export function useTradingBot(symbol: string = 'BTCUSDT') {
  const [state, setState] = useState<BotState>({
    isRunning: false,
    lastSignal: null,
    swingPoints: [],
    error: null,
  });

  /**
   * ขั้นตอนที่ 1: ดึงข้อมูลแท่งเทียน
   */
  const fetchCandles = useCallback(async () => {
    console.log('📊 กำลังดึงข้อมูลแท่งเทียน...');
    
    const { data, error } = await supabase.functions.invoke('fetch-candles', {
      body: { symbol, interval: '1h', limit: 100 }
    });

    if (error) throw new Error(\`ดึงข้อมูลล้มเหลว: \${error.message}\`);
    
    console.log(\`✅ ได้ข้อมูล \${data.candles.length} แท่ง\`);
    return data.candles;
  }, [symbol]);

  /**
   * ขั้นตอนที่ 2: คำนวณ ZigZag
   */
  const analyzeChart = useCallback((candles: Candle[]) => {
    console.log('📈 กำลังวิเคราะห์ ZigZag...');
    
    const swingPoints = calculateZigZag(candles, 12);
    
    console.log(\`✅ พบ Swing Points \${swingPoints.length} จุด\`);
    return swingPoints;
  }, []);

  /**
   * ขั้นตอนที่ 3: สร้างสัญญาณ
   */
  const getSignal = useCallback((swingPoints: SwingPoint[], currentPrice: number) => {
    console.log('🤖 กำลังวิเคราะห์สัญญาณ...');
    
    const signal = generateSignal(swingPoints, currentPrice);
    
    console.log(\`✅ สัญญาณ: \${signal.signal} (ความมั่นใจ \${signal.confidence}%)\`);
    console.log(\`   เหตุผล: \${signal.reason}\`);
    
    return signal;
  }, []);

  /**
   * ขั้นตอนที่ 4: ส่งคำสั่งเทรด (ถ้าต้องการ)
   */
  const executeTrade = useCallback(async (signal: SignalResult) => {
    if (signal.signal === 'HOLD') {
      console.log('⏸️ ไม่มีสัญญาณ - รอ');
      return null;
    }

    console.log(\`🚀 กำลังส่งคำสั่ง \${signal.signal}...\`);

    const { data, error } = await supabase.functions.invoke('execute-trade', {
      body: {
        symbol,
        side: signal.signal,
        quantity: 0.001,  // จำนวนน้อยๆ สำหรับทดสอบ
        stopLoss: signal.stopLoss,
        takeProfit: signal.takeProfit,
      }
    });

    if (error) throw new Error(\`ส่งคำสั่งล้มเหลว: \${error.message}\`);
    
    console.log(\`✅ คำสั่งสำเร็จ! Order ID: \${data.orderId}\`);
    return data;
  }, [symbol]);

  /**
   * รวมทุกขั้นตอน - รันครั้งเดียว
   */
  const runOnce = useCallback(async (autoTrade: boolean = false) => {
    setState(s => ({ ...s, isRunning: true, error: null }));

    try {
      // 1. ดึงข้อมูล
      const candles = await fetchCandles();
      
      // 2. วิเคราะห์
      const swingPoints = analyzeChart(candles);
      
      // 3. สร้างสัญญาณ
      const currentPrice = candles[candles.length - 1].close;
      const signal = getSignal(swingPoints, currentPrice);

      // 4. เทรด (ถ้าเปิด autoTrade)
      if (autoTrade && signal.signal !== 'HOLD') {
        await executeTrade(signal);
      }

      setState(s => ({
        ...s,
        isRunning: false,
        lastSignal: signal,
        swingPoints,
      }));

      return signal;

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'เกิดข้อผิดพลาด';
      setState(s => ({ ...s, isRunning: false, error: errorMessage }));
      throw error;
    }
  }, [fetchCandles, analyzeChart, getSignal, executeTrade]);

  return {
    ...state,
    runOnce,
  };
}`;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 border-b border-border bg-background/95 backdrop-blur">
        <div className="container py-4">
          <Link 
            to="/" 
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            กลับหน้าหลัก
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="container pt-12 pb-8">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            คู่มือโค้ด <span className="text-primary">Trading Bot</span> ฉบับเต็ม
          </h1>
          <p className="text-lg text-muted-foreground">
            อธิบายทุกขั้นตอนพร้อมโค้ดตัวอย่างที่ใช้งานได้จริง
          </p>
        </div>
      </section>

      {/* Flow Overview */}
      <section className="container pb-8">
        <div className="max-w-4xl mx-auto">
          <div className="glass-card rounded-2xl p-6">
            <h2 className="text-xl font-bold text-foreground mb-4">ภาพรวมการทำงาน</h2>
            <div className="flex flex-wrap items-center justify-center gap-2 text-sm">
              <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-secondary">
                <Database className="w-4 h-4 text-primary" />
                <span>ดึงข้อมูล</span>
              </div>
              <span className="text-muted-foreground">→</span>
              <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-secondary">
                <Calculator className="w-4 h-4 text-primary" />
                <span>คำนวณ ZigZag</span>
              </div>
              <span className="text-muted-foreground">→</span>
              <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-secondary">
                <Brain className="w-4 h-4 text-primary" />
                <span>วิเคราะห์สัญญาณ</span>
              </div>
              <span className="text-muted-foreground">→</span>
              <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-secondary">
                <Send className="w-4 h-4 text-primary" />
                <span>ส่งคำสั่ง</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Steps */}
      <section className="container py-8 space-y-8">
        <div className="max-w-5xl mx-auto space-y-8">
          
          {/* Step 1 */}
          <StepCard
            step={1}
            title="ดึงข้อมูลแท่งเทียนจาก Exchange"
            description="Edge Function ที่เรียก Binance API เพื่อดึงข้อมูล OHLC (Open, High, Low, Close)"
            icon={<Database className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                <span className="px-3 py-1 rounded-full bg-candle-green/20 text-candle-green text-sm">ไม่ต้องใช้ API Key</span>
                <span className="px-3 py-1 rounded-full bg-primary/20 text-primary text-sm">Public API</span>
              </div>
              <CodeBlock
                code={step1Code}
                language="TypeScript"
                filename="supabase/functions/fetch-candles/index.ts"
              />
            </div>
          </StepCard>

          {/* Step 2 */}
          <StepCard
            step={2}
            title="คำนวณ ZigZag และหา Swing Points"
            description="ฟังก์ชันที่วิเคราะห์ข้อมูลแท่งเทียนและหาจุด HH, HL, LH, LL เหมือน Indicator ใน TradingView"
            icon={<Calculator className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="grid md:grid-cols-4 gap-3 mb-4">
                <div className="p-3 rounded-lg bg-bull/10 border border-bull/30 text-center">
                  <div className="font-mono font-bold text-bull">HH</div>
                  <div className="text-xs text-muted-foreground">Higher High</div>
                </div>
                <div className="p-3 rounded-lg bg-bull/10 border border-bull/30 text-center">
                  <div className="font-mono font-bold text-bull">HL</div>
                  <div className="text-xs text-muted-foreground">Higher Low</div>
                </div>
                <div className="p-3 rounded-lg bg-bear/10 border border-bear/30 text-center">
                  <div className="font-mono font-bold text-bear">LH</div>
                  <div className="text-xs text-muted-foreground">Lower High</div>
                </div>
                <div className="p-3 rounded-lg bg-bear/10 border border-bear/30 text-center">
                  <div className="font-mono font-bold text-bear">LL</div>
                  <div className="text-xs text-muted-foreground">Lower Low</div>
                </div>
              </div>
              <CodeBlock
                code={step2Code}
                language="TypeScript"
                filename="src/utils/zigzag.ts"
              />
            </div>
          </StepCard>

          {/* Step 3 */}
          <StepCard
            step={3}
            title="วิเคราะห์และสร้างสัญญาณเทรด"
            description="ใช้ Swing Points ตัดสินใจว่าควร BUY, SELL หรือ HOLD พร้อมคำนวณ Stop Loss และ Take Profit"
            icon={<Brain className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="grid md:grid-cols-2 gap-4 mb-4">
                <div className="p-4 rounded-xl bg-bull/10 border border-bull/30">
                  <div className="flex items-center gap-2 mb-2">
                    <CheckCircle2 className="w-5 h-5 text-bull" />
                    <span className="font-semibold text-bull">สัญญาณซื้อ (BUY)</span>
                  </div>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• โครงสร้าง Uptrend (HH + HL)</li>
                    <li>• เกิด Higher Low (HL) ใหม่</li>
                    <li>• Stop Loss ใต้ Low ก่อนหน้า</li>
                  </ul>
                </div>
                <div className="p-4 rounded-xl bg-bear/10 border border-bear/30">
                  <div className="flex items-center gap-2 mb-2">
                    <XCircle className="w-5 h-5 text-bear" />
                    <span className="font-semibold text-bear">สัญญาณขาย (SELL)</span>
                  </div>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• โครงสร้าง Downtrend (LL + LH)</li>
                    <li>• เกิด Lower High (LH) ใหม่</li>
                    <li>• Stop Loss เหนือ High ก่อนหน้า</li>
                  </ul>
                </div>
              </div>
              <CodeBlock
                code={step3Code}
                language="TypeScript"
                filename="src/utils/trading-signal.ts"
              />
            </div>
          </StepCard>

          {/* Step 4 */}
          <StepCard
            step={4}
            title="ส่งคำสั่งซื้อขายไปยัง Exchange"
            description="Edge Function ที่ส่งคำสั่ง Market Order พร้อม Stop Loss ไปยัง Binance (ต้องใช้ API Key)"
            icon={<Send className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-destructive/10 border border-destructive/30 flex items-start gap-3">
                <AlertTriangle className="w-5 h-5 text-destructive shrink-0 mt-0.5" />
                <div>
                  <div className="font-semibold text-destructive mb-1">ข้อควรระวัง!</div>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• ต้องใช้ Binance API Key และ Secret Key</li>
                    <li>• ทดสอบกับ Testnet ก่อนใช้เงินจริง</li>
                    <li>• เก็บ API Key ใน Supabase Secrets เท่านั้น</li>
                  </ul>
                </div>
              </div>
              <CodeBlock
                code={step4Code}
                language="TypeScript"
                filename="supabase/functions/execute-trade/index.ts"
              />
            </div>
          </StepCard>

          {/* Step 5 */}
          <StepCard
            step={5}
            title="รวมทุกอย่างเข้าด้วยกัน (React Hook)"
            description="Custom Hook ที่รวมทุกขั้นตอน สามารถเรียกใช้จาก Component ได้ง่ายๆ"
            icon={<Brain className="w-6 h-6" />}
          >
            <CodeBlock
              code={step5Code}
              language="TypeScript"
              filename="src/hooks/useTradingBot.ts"
            />
          </StepCard>

        </div>
      </section>

      {/* Next Steps */}
      <section className="container py-12">
        <div className="max-w-4xl mx-auto">
          <div className="glass-card rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-foreground mb-6 text-center">ขั้นตอนถัดไป</h2>
            <div className="grid md:grid-cols-3 gap-4">
              <div className="p-4 rounded-xl bg-secondary text-center">
                <div className="text-3xl mb-2">1️⃣</div>
                <div className="font-semibold text-foreground mb-1">เปิดใช้ Lovable Cloud</div>
                <div className="text-sm text-muted-foreground">สำหรับสร้าง Edge Functions</div>
              </div>
              <div className="p-4 rounded-xl bg-secondary text-center">
                <div className="text-3xl mb-2">2️⃣</div>
                <div className="font-semibold text-foreground mb-1">ทดสอบกับ Testnet</div>
                <div className="text-sm text-muted-foreground">ใช้ Binance Testnet ก่อน</div>
              </div>
              <div className="p-4 rounded-xl bg-secondary text-center">
                <div className="text-3xl mb-2">3️⃣</div>
                <div className="font-semibold text-foreground mb-1">Backtest กลยุทธ์</div>
                <div className="text-sm text-muted-foreground">ทดสอบกับข้อมูลย้อนหลัง</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8">
        <div className="container text-center text-sm text-muted-foreground">
          <p>คู่มือนี้เป็นตัวอย่างเพื่อการศึกษา - กรุณาทดสอบอย่างละเอียดก่อนใช้งานจริง</p>
        </div>
      </footer>
    </div>
  );
};

export default TradingBotGuide;
