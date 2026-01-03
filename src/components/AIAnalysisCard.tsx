import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { TrendingUp, TrendingDown, Minus, Target, Shield, Clock } from 'lucide-react';
import AICandlestickChart from './AICandlestickChart';

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

interface AnalysisData {
  bullish_probability: number;
  bearish_probability: number;
  sideways_probability: number;
  dominant_bias: string;
  threshold_met: boolean;
  market_structure: string;
  trend_h4: string;
  trend_daily: string;
  key_levels: { support: number[]; resistance: number[] };
  patterns: string;
  reasoning: string;
  recommendation: string;
  created_at: string;
  candle_time: string;
}

interface AIAnalysisCardProps {
  symbol: string;
  timeframe: string;
  analysis: AnalysisData | null;
  candles: CandleData[];
  indicators: IndicatorData[];
  isExpanded?: boolean;
  onToggleExpand?: () => void;
}

const AIAnalysisCard = ({ 
  symbol, 
  timeframe, 
  analysis, 
  candles, 
  indicators,
  isExpanded = false,
  onToggleExpand
}: AIAnalysisCardProps) => {
  
  const getBiasIcon = (bias: string) => {
    switch (bias) {
      case 'bullish': return <TrendingUp className="w-4 h-4 text-green-400" />;
      case 'bearish': return <TrendingDown className="w-4 h-4 text-red-400" />;
      default: return <Minus className="w-4 h-4 text-yellow-400" />;
    }
  };

  const getBiasColor = (bias: string) => {
    switch (bias) {
      case 'bullish': return 'bg-green-500/20 text-green-400 border-green-500/50';
      case 'bearish': return 'bg-red-500/20 text-red-400 border-red-500/50';
      default: return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/50';
    }
  };

  const getRecommendationBadge = (rec: string) => {
    switch (rec) {
      case 'Only LONG': return <Badge className="bg-green-500/20 text-green-400 border-green-500">BUY Only</Badge>;
      case 'Only SHORT': return <Badge className="bg-red-500/20 text-red-400 border-red-500">SELL Only</Badge>;
      default: return <Badge variant="outline" className="text-muted-foreground">No Trade</Badge>;
    }
  };

  const hasData = candles.length > 0;
  const hasAnalysis = analysis !== null;

  return (
    <Card className={`overflow-hidden transition-all ${isExpanded ? 'col-span-full' : ''}`}>
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg flex items-center gap-2">
            {symbol}
            <Badge variant="outline" className="text-xs">{timeframe}</Badge>
          </CardTitle>
          <div className="flex items-center gap-2">
            {hasAnalysis && getRecommendationBadge(analysis.recommendation)}
            {onToggleExpand && (
              <button 
                onClick={onToggleExpand}
                className="text-muted-foreground hover:text-foreground transition-colors text-sm"
              >
                {isExpanded ? 'ย่อ' : 'ขยาย'}
              </button>
            )}
          </div>
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4">
        {/* Chart */}
        <div className="rounded-lg overflow-hidden">
          <AICandlestickChart 
            candles={candles}
            indicators={indicators}
            keyLevels={analysis?.key_levels}
            symbol={symbol}
            height={isExpanded ? 350 : 200}
          />
        </div>

        {hasAnalysis ? (
          <>
            {/* Probability Bars */}
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-green-400" />
                <span className="text-sm w-16">Bullish</span>
                <Progress value={analysis.bullish_probability} className="flex-1 h-2" />
                <span className="text-sm font-medium w-10 text-right">{analysis.bullish_probability}%</span>
              </div>
              <div className="flex items-center gap-2">
                <TrendingDown className="w-4 h-4 text-red-400" />
                <span className="text-sm w-16">Bearish</span>
                <Progress value={analysis.bearish_probability} className="flex-1 h-2 [&>div]:bg-red-500" />
                <span className="text-sm font-medium w-10 text-right">{analysis.bearish_probability}%</span>
              </div>
              <div className="flex items-center gap-2">
                <Minus className="w-4 h-4 text-yellow-400" />
                <span className="text-sm w-16">Sideways</span>
                <Progress value={analysis.sideways_probability} className="flex-1 h-2 [&>div]:bg-yellow-500" />
                <span className="text-sm font-medium w-10 text-right">{analysis.sideways_probability}%</span>
              </div>
            </div>

            {/* Dominant Bias */}
            <div className="flex items-center justify-between p-3 rounded-lg bg-muted/50">
              <div className="flex items-center gap-2">
                {getBiasIcon(analysis.dominant_bias)}
                <span className="text-sm font-medium capitalize">{analysis.dominant_bias} Bias</span>
              </div>
              <Badge className={getBiasColor(analysis.dominant_bias)}>
                {analysis.threshold_met ? 'Tradable' : 'Below Threshold'}
              </Badge>
            </div>

            {/* Details (only when expanded) */}
            {isExpanded && (
              <div className="space-y-3 pt-2">
                {/* Market Structure */}
                <div className="p-3 rounded-lg bg-muted/30 space-y-2">
                  <h4 className="text-sm font-medium flex items-center gap-2">
                    <Target className="w-4 h-4 text-primary" />
                    Market Structure
                  </h4>
                  <p className="text-sm text-muted-foreground">{analysis.market_structure}</p>
                  <div className="flex gap-4 text-xs">
                    <span>H4: <span className={analysis.trend_h4 === 'bullish' ? 'text-green-400' : analysis.trend_h4 === 'bearish' ? 'text-red-400' : 'text-yellow-400'}>{analysis.trend_h4}</span></span>
                    <span>Daily: <span className={analysis.trend_daily === 'bullish' ? 'text-green-400' : analysis.trend_daily === 'bearish' ? 'text-red-400' : 'text-yellow-400'}>{analysis.trend_daily}</span></span>
                  </div>
                </div>

                {/* Key Levels */}
                <div className="p-3 rounded-lg bg-muted/30 space-y-2">
                  <h4 className="text-sm font-medium flex items-center gap-2">
                    <Shield className="w-4 h-4 text-primary" />
                    Key Levels
                  </h4>
                  <div className="flex gap-4 text-xs">
                    <div>
                      <span className="text-green-400">Support:</span>{' '}
                      {analysis.key_levels.support.length > 0 
                        ? analysis.key_levels.support.map(l => l.toFixed(2)).join(', ')
                        : 'N/A'}
                    </div>
                    <div>
                      <span className="text-red-400">Resistance:</span>{' '}
                      {analysis.key_levels.resistance.length > 0 
                        ? analysis.key_levels.resistance.map(l => l.toFixed(2)).join(', ')
                        : 'N/A'}
                    </div>
                  </div>
                </div>

                {/* Patterns */}
                {analysis.patterns && (
                  <div className="p-3 rounded-lg bg-muted/30">
                    <h4 className="text-sm font-medium mb-1">Patterns</h4>
                    <p className="text-sm text-muted-foreground">{analysis.patterns}</p>
                  </div>
                )}

                {/* AI Reasoning */}
                <div className="p-3 rounded-lg bg-primary/10 border border-primary/30">
                  <h4 className="text-sm font-medium mb-1 flex items-center gap-2">
                    🤖 AI Reasoning
                  </h4>
                  <p className="text-sm text-muted-foreground">{analysis.reasoning}</p>
                </div>

                {/* Timestamp */}
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  <Clock className="w-3 h-3" />
                  <span>Analyzed: {new Date(analysis.created_at).toLocaleString()}</span>
                  <span>|</span>
                  <span>Candle: {new Date(analysis.candle_time).toLocaleString()}</span>
                </div>
              </div>
            )}
          </>
        ) : (
          <div className="text-center py-4 text-muted-foreground">
            <p className="text-sm">No analysis available yet</p>
            <p className="text-xs mt-1">Waiting for EA to send data...</p>
          </div>
        )}

        {/* Data Status */}
        <div className="text-xs text-muted-foreground flex items-center justify-between">
          <span>{candles.length} candles loaded</span>
          {hasData && <span>Latest: {new Date(candles[candles.length - 1]?.time).toLocaleString()}</span>}
        </div>
      </CardContent>
    </Card>
  );
};

export default AIAnalysisCard;
