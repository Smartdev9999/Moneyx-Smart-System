import { ReactNode } from 'react';

interface ParameterCardProps {
  name: string;
  value: string | number;
  description: string;
  icon: ReactNode;
}

const ParameterCard = ({ name, value, description, icon }: ParameterCardProps) => {
  return (
    <div className="glass-card rounded-xl p-5 hover:border-primary/50 transition-all duration-300 group">
      <div className="flex items-start gap-4">
        <div className="p-3 rounded-lg bg-secondary text-primary group-hover:glow-bull transition-all duration-300">
          {icon}
        </div>
        <div className="flex-1">
          <div className="flex items-center justify-between mb-2">
            <h3 className="font-mono font-semibold text-foreground">{name}</h3>
            <span className="font-mono text-primary bg-primary/10 px-3 py-1 rounded-full text-sm">
              {value}
            </span>
          </div>
          <p className="text-muted-foreground text-sm leading-relaxed">
            {description}
          </p>
        </div>
      </div>
    </div>
  );
};

export default ParameterCard;
