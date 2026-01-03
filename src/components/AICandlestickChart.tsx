import { useEffect, useRef, useState } from 'react';

interface CandleData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface IndicatorData {
  time: string;
  ema20: number | null;
  ema50: number | null;
  rsi: number | null;
}

interface KeyLevels {
  support: number[];
  resistance: number[];
}

interface AICandlestickChartProps {
  candles: CandleData[];
  indicators?: IndicatorData[];
  keyLevels?: KeyLevels;
  symbol: string;
  height?: number;
}

const AICandlestickChart = ({ 
  candles, 
  indicators = [], 
  keyLevels = { support: [], resistance: [] },
  symbol,
  height = 300 
}: AICandlestickChartProps) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [hoveredCandle, setHoveredCandle] = useState<CandleData | null>(null);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container || candles.length === 0) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Set canvas size
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = rect.width * dpr;
    canvas.height = height * dpr;
    canvas.style.width = `${rect.width}px`;
    canvas.style.height = `${height}px`;
    ctx.scale(dpr, dpr);

    const width = rect.width;
    const chartHeight = height;
    const padding = { top: 20, right: 60, bottom: 30, left: 10 };
    const chartWidth = width - padding.left - padding.right;
    const chartArea = chartHeight - padding.top - padding.bottom;

    // Clear canvas
    ctx.fillStyle = 'hsl(224, 71%, 4%)';
    ctx.fillRect(0, 0, width, chartHeight);

    // Calculate price range
    const prices = candles.flatMap(c => [c.high, c.low]);
    const allLevels = [...keyLevels.support, ...keyLevels.resistance];
    const minPrice = Math.min(...prices, ...allLevels.filter(l => l > 0)) * 0.9995;
    const maxPrice = Math.max(...prices, ...allLevels.filter(l => l > 0)) * 1.0005;
    const priceRange = maxPrice - minPrice;

    const priceToY = (price: number) => {
      return padding.top + chartArea - ((price - minPrice) / priceRange) * chartArea;
    };

    const candleWidth = Math.max(2, (chartWidth / candles.length) * 0.7);
    const candleGap = chartWidth / candles.length;

    // Draw grid
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
    ctx.lineWidth = 1;
    
    const gridLevels = 5;
    for (let i = 0; i <= gridLevels; i++) {
      const y = padding.top + (chartArea / gridLevels) * i;
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(width - padding.right, y);
      ctx.stroke();

      // Price labels
      const price = maxPrice - (priceRange / gridLevels) * i;
      ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
      ctx.font = '10px monospace';
      ctx.textAlign = 'left';
      ctx.fillText(price.toFixed(symbol.includes('JPY') ? 3 : 5), width - padding.right + 5, y + 3);
    }

    // Draw support levels
    keyLevels.support.forEach(level => {
      if (level >= minPrice && level <= maxPrice) {
        const y = priceToY(level);
        ctx.strokeStyle = 'rgba(34, 197, 94, 0.5)';
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.moveTo(padding.left, y);
        ctx.lineTo(width - padding.right, y);
        ctx.stroke();
        ctx.setLineDash([]);
        
        ctx.fillStyle = 'rgba(34, 197, 94, 0.7)';
        ctx.font = '9px monospace';
        ctx.fillText(`S: ${level.toFixed(2)}`, padding.left + 5, y - 3);
      }
    });

    // Draw resistance levels
    keyLevels.resistance.forEach(level => {
      if (level >= minPrice && level <= maxPrice) {
        const y = priceToY(level);
        ctx.strokeStyle = 'rgba(239, 68, 68, 0.5)';
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.moveTo(padding.left, y);
        ctx.lineTo(width - padding.right, y);
        ctx.stroke();
        ctx.setLineDash([]);
        
        ctx.fillStyle = 'rgba(239, 68, 68, 0.7)';
        ctx.font = '9px monospace';
        ctx.fillText(`R: ${level.toFixed(2)}`, padding.left + 5, y - 3);
      }
    });

    // Draw EMA lines
    if (indicators.length > 0) {
      // EMA 20
      ctx.strokeStyle = 'rgba(59, 130, 246, 0.8)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      let started = false;
      indicators.forEach((ind, i) => {
        if (ind.ema20 !== null) {
          const x = padding.left + i * candleGap + candleGap / 2;
          const y = priceToY(ind.ema20);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        }
      });
      ctx.stroke();

      // EMA 50
      ctx.strokeStyle = 'rgba(168, 85, 247, 0.8)';
      ctx.beginPath();
      started = false;
      indicators.forEach((ind, i) => {
        if (ind.ema50 !== null) {
          const x = padding.left + i * candleGap + candleGap / 2;
          const y = priceToY(ind.ema50);
          if (!started) {
            ctx.moveTo(x, y);
            started = true;
          } else {
            ctx.lineTo(x, y);
          }
        }
      });
      ctx.stroke();
    }

    // Draw candles
    candles.forEach((candle, i) => {
      const x = padding.left + i * candleGap + candleGap / 2;
      const isBullish = candle.close >= candle.open;
      
      const color = isBullish ? '#22c55e' : '#ef4444';
      
      // Wick
      ctx.strokeStyle = color;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, priceToY(candle.high));
      ctx.lineTo(x, priceToY(candle.low));
      ctx.stroke();

      // Body
      const bodyTop = priceToY(Math.max(candle.open, candle.close));
      const bodyBottom = priceToY(Math.min(candle.open, candle.close));
      const bodyHeight = Math.max(1, bodyBottom - bodyTop);
      
      ctx.fillStyle = color;
      ctx.fillRect(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight);
    });

    // Draw legend
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    ctx.font = '10px sans-serif';
    ctx.fillText(symbol, padding.left + 5, padding.top + 15);
    
    // EMA legend
    ctx.fillStyle = 'rgba(59, 130, 246, 0.8)';
    ctx.fillText('EMA20', padding.left + 80, padding.top + 15);
    ctx.fillStyle = 'rgba(168, 85, 247, 0.8)';
    ctx.fillText('EMA50', padding.left + 130, padding.top + 15);

  }, [candles, indicators, keyLevels, symbol, height]);

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!containerRef.current || candles.length === 0) return;
    
    const rect = containerRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const padding = { left: 10, right: 60 };
    const chartWidth = rect.width - padding.left - padding.right;
    const candleGap = chartWidth / candles.length;
    
    const index = Math.floor((x - padding.left) / candleGap);
    if (index >= 0 && index < candles.length) {
      setHoveredCandle(candles[index]);
      setMousePos({ x: e.clientX - rect.left, y: e.clientY - rect.top });
    } else {
      setHoveredCandle(null);
    }
  };

  if (candles.length === 0) {
    return (
      <div className="flex items-center justify-center bg-muted/20 rounded-lg" style={{ height }}>
        <p className="text-sm text-muted-foreground">No candle data available</p>
      </div>
    );
  }

  return (
    <div ref={containerRef} className="relative w-full" onMouseMove={handleMouseMove} onMouseLeave={() => setHoveredCandle(null)}>
      <canvas ref={canvasRef} className="w-full rounded-lg" />
      
      {hoveredCandle && (
        <div 
          className="absolute z-10 bg-popover border border-border rounded-lg shadow-lg p-2 text-xs pointer-events-none"
          style={{ 
            left: Math.min(mousePos.x + 10, containerRef.current?.offsetWidth || 0 - 150),
            top: mousePos.y - 80
          }}
        >
          <div className="font-medium mb-1">{new Date(hoveredCandle.time).toLocaleString()}</div>
          <div className="grid grid-cols-2 gap-x-3 gap-y-0.5">
            <span className="text-muted-foreground">Open:</span>
            <span>{hoveredCandle.open.toFixed(5)}</span>
            <span className="text-muted-foreground">High:</span>
            <span className="text-green-400">{hoveredCandle.high.toFixed(5)}</span>
            <span className="text-muted-foreground">Low:</span>
            <span className="text-red-400">{hoveredCandle.low.toFixed(5)}</span>
            <span className="text-muted-foreground">Close:</span>
            <span className={hoveredCandle.close >= hoveredCandle.open ? 'text-green-400' : 'text-red-400'}>
              {hoveredCandle.close.toFixed(5)}
            </span>
          </div>
        </div>
      )}
    </div>
  );
};

export default AICandlestickChart;
