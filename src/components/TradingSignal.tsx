import { TrendingUp, TrendingDown, AlertCircle } from 'lucide-react';

interface TradingSignalProps {
  type: 'bullish' | 'bearish' | 'neutral';
  title: string;
  conditions: string[];
}

const TradingSignal = ({ type, title, conditions }: TradingSignalProps) => {
  const config = {
    bullish: {
      icon: TrendingUp,
      bgClass: 'bg-bull/10',
      borderClass: 'border-bull/30',
      textClass: 'text-bull',
      glowClass: 'glow-bull',
    },
    bearish: {
      icon: TrendingDown,
      bgClass: 'bg-bear/10',
      borderClass: 'border-bear/30',
      textClass: 'text-bear',
      glowClass: 'glow-bear',
    },
    neutral: {
      icon: AlertCircle,
      bgClass: 'bg-muted',
      borderClass: 'border-border',
      textClass: 'text-muted-foreground',
      glowClass: '',
    },
  };

  const { icon: Icon, bgClass, borderClass, textClass, glowClass } = config[type];

  return (
    <div className={`
      rounded-xl border p-6 transition-all duration-300 hover:scale-[1.02]
      ${bgClass} ${borderClass}
    `}>
      <div className="flex items-center gap-3 mb-4">
        <div className={`p-2 rounded-lg ${bgClass} ${glowClass}`}>
          <Icon className={`w-6 h-6 ${textClass}`} />
        </div>
        <h3 className={`font-semibold text-lg ${textClass}`}>{title}</h3>
      </div>
      <ul className="space-y-2">
        {conditions.map((condition, index) => (
          <li key={index} className="flex items-start gap-2 text-sm text-muted-foreground">
            <span className={`mt-1.5 w-1.5 h-1.5 rounded-full ${type === 'bullish' ? 'bg-bull' : type === 'bearish' ? 'bg-bear' : 'bg-muted-foreground'}`} />
            {condition}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default TradingSignal;
