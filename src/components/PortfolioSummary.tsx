import { Card, CardContent } from '@/components/ui/card';
import { 
  Wallet, 
  TrendingUp, 
  TrendingDown, 
  DollarSign,
  PieChart,
  Percent
} from 'lucide-react';

interface FundAllocation {
  id: string;
  trading_system_id: string;
  allocated_amount: number;
  current_value: number;
  profit_loss: number;
  roi_percent: number;
  trading_systems: {
    name: string;
  } | null;
}

interface PortfolioSummaryProps {
  walletBalance: number;
  totalMT5Balance: number;
  totalEquity: number;
  totalProfit: number;
  allocations: FundAllocation[];
}

export const PortfolioSummary = ({
  walletBalance,
  totalMT5Balance,
  totalEquity,
  totalProfit,
  allocations,
}: PortfolioSummaryProps) => {
  // Calculate total invested in systems
  const totalInvested = allocations.reduce((sum, a) => sum + (a.allocated_amount || 0), 0);
  
  // Calculate current value from allocations
  const totalCurrentValue = allocations.reduce((sum, a) => sum + (a.current_value || 0), 0);
  
  // Total portfolio value
  const totalPortfolioValue = walletBalance + totalCurrentValue + totalMT5Balance;
  
  // Total P/L from allocations
  const totalAllocationPL = allocations.reduce((sum, a) => sum + (a.profit_loss || 0), 0);
  
  // Overall ROI
  const overallROI = totalInvested > 0 
    ? ((totalAllocationPL + totalProfit) / totalInvested) * 100 
    : 0;

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      <Card className="bg-gradient-to-br from-primary/10 to-primary/5">
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            <PieChart className="w-4 h-4" />
            Total Portfolio
          </div>
          <p className="text-xl font-bold">
            ${totalPortfolioValue.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            <Wallet className="w-4 h-4" />
            Wallet Balance
          </div>
          <p className="text-xl font-bold">
            ${walletBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            <DollarSign className="w-4 h-4" />
            MT5 Balance
          </div>
          <p className="text-xl font-bold">
            ${totalMT5Balance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            <DollarSign className="w-4 h-4" />
            Total Invested
          </div>
          <p className="text-xl font-bold">
            ${totalInvested.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            {(totalAllocationPL + totalProfit) >= 0 ? (
              <TrendingUp className="w-4 h-4 text-green-500" />
            ) : (
              <TrendingDown className="w-4 h-4 text-red-500" />
            )}
            Total P/L
          </div>
          <p className={`text-xl font-bold ${(totalAllocationPL + totalProfit) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
            ${(totalAllocationPL + totalProfit).toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="pt-4">
          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
            <Percent className="w-4 h-4" />
            ROI
          </div>
          <p className={`text-xl font-bold ${overallROI >= 0 ? 'text-green-500' : 'text-red-500'}`}>
            {overallROI >= 0 ? '+' : ''}{overallROI.toFixed(2)}%
          </p>
        </CardContent>
      </Card>
    </div>
  );
};
