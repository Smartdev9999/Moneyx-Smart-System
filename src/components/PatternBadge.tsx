interface PatternBadgeProps {
  pattern: 'HH' | 'HL' | 'LH' | 'LL';
  description: string;
}

const PatternBadge = ({ pattern, description }: PatternBadgeProps) => {
  const isBullish = pattern === 'HH' || pattern === 'HL';
  
  return (
    <div className={`
      flex items-center gap-4 p-4 rounded-xl border transition-all duration-300 hover:scale-[1.02]
      ${isBullish 
        ? 'bg-bull/5 border-bull/30 hover:border-bull/50' 
        : 'bg-bear/5 border-bear/30 hover:border-bear/50'
      }
    `}>
      <div className={`
        w-14 h-14 rounded-lg flex items-center justify-center font-mono font-bold text-lg
        ${isBullish ? 'bg-bull/20 text-bull' : 'bg-bear/20 text-bear'}
      `}>
        {pattern}
      </div>
      <div>
        <h4 className={`font-semibold ${isBullish ? 'text-bull' : 'text-bear'}`}>
          {pattern === 'HH' && 'Higher High'}
          {pattern === 'HL' && 'Higher Low'}
          {pattern === 'LH' && 'Lower High'}
          {pattern === 'LL' && 'Lower Low'}
        </h4>
        <p className="text-muted-foreground text-sm mt-1">{description}</p>
      </div>
    </div>
  );
};

export default PatternBadge;
