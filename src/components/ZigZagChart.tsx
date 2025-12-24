import { useEffect, useRef, useState } from 'react';

interface SwingPoint {
  x: number;
  y: number;
  type: 'high' | 'low';
  price: number;
  barCount: number;
  pattern: 'HH' | 'HL' | 'LH' | 'LL';
}

const ZigZagChart = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [hoveredPoint, setHoveredPoint] = useState<SwingPoint | null>(null);
  const [animationProgress, setAnimationProgress] = useState(0);

  // Sample candlestick data
  const candles = [
    { open: 100, high: 105, low: 98, close: 103 },
    { open: 103, high: 108, low: 101, close: 106 },
    { open: 106, high: 112, low: 104, close: 110 },
    { open: 110, high: 118, low: 108, close: 116 }, // Swing High
    { open: 116, high: 117, low: 110, close: 112 },
    { open: 112, high: 114, low: 106, close: 108 },
    { open: 108, high: 110, low: 102, close: 104 },
    { open: 104, high: 106, low: 98, close: 100 }, // Swing Low
    { open: 100, high: 108, low: 99, close: 107 },
    { open: 107, high: 114, low: 105, close: 112 },
    { open: 112, high: 120, low: 110, close: 118 },
    { open: 118, high: 125, low: 116, close: 122 }, // Higher High
    { open: 122, high: 124, low: 115, close: 117 },
    { open: 117, high: 119, low: 108, close: 110 },
    { open: 110, high: 112, low: 104, close: 106 }, // Higher Low
    { open: 106, high: 115, low: 105, close: 113 },
    { open: 113, high: 122, low: 111, close: 120 },
    { open: 120, high: 130, low: 118, close: 128 }, // Higher High
    { open: 128, high: 129, low: 120, close: 122 },
    { open: 122, high: 124, low: 112, close: 114 },
    { open: 114, high: 116, low: 105, close: 108 }, // Lower Low
    { open: 108, high: 115, low: 106, close: 113 },
    { open: 113, high: 118, low: 111, close: 116 }, // Lower High
  ];

  // Swing points with bar counts
  const swingPoints: SwingPoint[] = [
    { x: 3, y: 118, type: 'high', price: 118, barCount: 0, pattern: 'HH' },
    { x: 7, y: 98, type: 'low', price: 98, barCount: 4, pattern: 'LL' },
    { x: 11, y: 125, type: 'high', price: 125, barCount: 4, pattern: 'HH' },
    { x: 14, y: 104, type: 'low', price: 104, barCount: 3, pattern: 'HL' },
    { x: 17, y: 130, type: 'high', price: 130, barCount: 3, pattern: 'HH' },
    { x: 20, y: 105, type: 'low', price: 105, barCount: 3, pattern: 'LL' },
    { x: 22, y: 118, type: 'high', price: 118, barCount: 2, pattern: 'LH' },
  ];

  useEffect(() => {
    const timer = setTimeout(() => {
      setAnimationProgress(1);
    }, 100);

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;
    const padding = 60;
    const chartWidth = width - padding * 2;
    const chartHeight = height - padding * 2;

    // Clear canvas
    ctx.fillStyle = 'hsl(222, 47%, 6%)';
    ctx.fillRect(0, 0, width, height);

    // Draw grid
    ctx.strokeStyle = 'hsl(222, 30%, 15%)';
    ctx.lineWidth = 1;

    // Horizontal grid lines
    for (let i = 0; i <= 5; i++) {
      const y = padding + (chartHeight / 5) * i;
      ctx.beginPath();
      ctx.moveTo(padding, y);
      ctx.lineTo(width - padding, y);
      ctx.stroke();
    }

    // Calculate price range
    const minPrice = 90;
    const maxPrice = 140;
    const priceRange = maxPrice - minPrice;

    const getY = (price: number) => {
      return padding + chartHeight - ((price - minPrice) / priceRange) * chartHeight;
    };

    const getX = (index: number) => {
      return padding + (index / (candles.length - 1)) * chartWidth;
    };

    // Draw price labels
    ctx.fillStyle = 'hsl(215, 20%, 55%)';
    ctx.font = '12px "JetBrains Mono"';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 5; i++) {
      const price = minPrice + (priceRange / 5) * (5 - i);
      const y = padding + (chartHeight / 5) * i;
      ctx.fillText(price.toFixed(0), padding - 10, y + 4);
    }

    // Draw candlesticks
    candles.forEach((candle, i) => {
      const x = getX(i);
      const candleWidth = chartWidth / candles.length * 0.6;

      // Wick
      ctx.strokeStyle = candle.close >= candle.open ? 'hsl(142, 71%, 45%)' : 'hsl(0, 72%, 51%)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, getY(candle.high));
      ctx.lineTo(x, getY(candle.low));
      ctx.stroke();

      // Body
      ctx.fillStyle = candle.close >= candle.open ? 'hsl(142, 71%, 45%)' : 'hsl(0, 72%, 51%)';
      const bodyTop = Math.max(candle.open, candle.close);
      const bodyBottom = Math.min(candle.open, candle.close);
      ctx.fillRect(
        x - candleWidth / 2,
        getY(bodyTop),
        candleWidth,
        Math.max(getY(bodyBottom) - getY(bodyTop), 2)
      );
    });

    // Draw ZigZag lines with animation
    if (animationProgress > 0) {
      for (let i = 0; i < swingPoints.length - 1; i++) {
        const start = swingPoints[i];
        const end = swingPoints[i + 1];
        const isBullish = end.type === 'high';

        ctx.strokeStyle = isBullish ? 'hsl(187, 100%, 50%)' : 'hsl(0, 72%, 51%)';
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';

        // Add glow effect
        ctx.shadowColor = isBullish ? 'hsl(187, 100%, 50%)' : 'hsl(0, 72%, 51%)';
        ctx.shadowBlur = 10;

        ctx.beginPath();
        ctx.moveTo(getX(start.x), getY(start.y));
        ctx.lineTo(getX(end.x), getY(end.y));
        ctx.stroke();

        ctx.shadowBlur = 0;
      }

      // Draw swing point labels
      swingPoints.forEach((point, i) => {
        const x = getX(point.x);
        const y = getY(point.y);
        const isBullish = point.type === 'high';

        // Draw circle at swing point
        ctx.beginPath();
        ctx.arc(x, y, 6, 0, Math.PI * 2);
        ctx.fillStyle = isBullish ? 'hsl(187, 100%, 50%)' : 'hsl(0, 72%, 51%)';
        ctx.fill();

        // Draw label background
        const labelY = isBullish ? y - 45 : y + 25;
        ctx.fillStyle = 'hsl(222, 47%, 11%)';
        ctx.strokeStyle = isBullish ? 'hsl(187, 100%, 50%)' : 'hsl(0, 72%, 51%)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.roundRect(x - 35, labelY, 70, 40, 6);
        ctx.fill();
        ctx.stroke();

        // Draw label text
        ctx.fillStyle = isBullish ? 'hsl(187, 100%, 50%)' : 'hsl(0, 72%, 51%)';
        ctx.font = 'bold 11px "JetBrains Mono"';
        ctx.textAlign = 'center';
        ctx.fillText(point.pattern, x, labelY + 15);

        ctx.fillStyle = 'hsl(210, 40%, 96%)';
        ctx.font = '10px "JetBrains Mono"';
        ctx.fillText(`$${point.price}`, x, labelY + 27);

        if (i > 0) {
          ctx.fillStyle = 'hsl(215, 20%, 55%)';
          ctx.fillText(`C=${point.barCount}`, x, labelY + 37);
        }
      });
    }

    return () => clearTimeout(timer);
  }, [animationProgress]);

  return (
    <div className="relative w-full">
      <canvas
        ref={canvasRef}
        width={900}
        height={450}
        className="w-full h-auto rounded-xl border border-border"
      />
      {hoveredPoint && (
        <div className="absolute bg-card border border-border rounded-lg p-3 text-sm pointer-events-none">
          <div className={hoveredPoint.type === 'high' ? 'text-bull' : 'text-bear'}>
            {hoveredPoint.pattern}
          </div>
          <div className="text-foreground">${hoveredPoint.price}</div>
          <div className="text-muted-foreground">C={hoveredPoint.barCount}</div>
        </div>
      )}
    </div>
  );
};

export default ZigZagChart;
