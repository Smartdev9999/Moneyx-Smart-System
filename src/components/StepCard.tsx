import { ReactNode } from 'react';

interface StepCardProps {
  step: number;
  title: string;
  description: string;
  icon: ReactNode;
  children: ReactNode;
}

const StepCard = ({ step, title, description, icon, children }: StepCardProps) => {
  return (
    <div className="glass-card rounded-2xl overflow-hidden">
      {/* Header */}
      <div className="p-6 border-b border-border">
        <div className="flex items-start gap-4">
          <div className="flex items-center justify-center w-12 h-12 rounded-xl bg-primary/20 text-primary shrink-0">
            {icon}
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-3 mb-2">
              <span className="px-3 py-1 rounded-full bg-primary text-primary-foreground text-sm font-bold">
                ขั้นตอนที่ {step}
              </span>
            </div>
            <h3 className="text-xl font-bold text-foreground mb-2">{title}</h3>
            <p className="text-muted-foreground">{description}</p>
          </div>
        </div>
      </div>
      
      {/* Content */}
      <div className="p-6">
        {children}
      </div>
    </div>
  );
};

export default StepCard;
