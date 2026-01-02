import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';
import { TrendingUp, Calendar } from 'lucide-react';

interface ChartDataPoint {
  date: string;
  balance: number;
  equity: number;
  profit_loss: number;
}

interface AccountHistoryChartProps {
  accountIds: string[];
}

type TimeFrame = '7d' | '30d' | '60d' | 'all';

const AccountHistoryChart = ({ accountIds }: AccountHistoryChartProps) => {
  const [data, setData] = useState<ChartDataPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [timeframe, setTimeframe] = useState<TimeFrame>('30d');

  useEffect(() => {
    if (accountIds.length > 0) {
      fetchHistoryData();
    }
  }, [accountIds, timeframe]);

  const fetchHistoryData = async () => {
    setIsLoading(true);
    try {
      // Calculate date range
      let startDate: Date | null = null;
      const now = new Date();
      
      switch (timeframe) {
        case '7d':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case '30d':
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        case '60d':
          startDate = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
          break;
        case 'all':
          startDate = null;
          break;
      }

      // Fetch current balance from mt5_accounts
      const { data: accountData } = await supabase
        .from('mt5_accounts')
        .select('balance, equity, initial_balance')
        .in('id', accountIds)
        .single();

      const currentBalance = Number(accountData?.balance || 0);
      const currentEquity = Number(accountData?.equity || 0);

      // Fetch trade history (closed positions only) to calculate historical balance
      let tradeQuery = supabase
        .from('trade_history')
        .select('close_time, profit, commission, swap')
        .in('mt5_account_id', accountIds)
        .eq('entry_type', 'out')  // Only closed positions
        .not('close_time', 'is', null)
        .order('close_time', { ascending: true });

      const { data: tradeData, error: tradeError } = await tradeQuery;

      if (tradeError) throw tradeError;

      // Also fetch account_history for recent synced data
      let historyQuery = supabase
        .from('account_history')
        .select('recorded_at, balance, equity, profit_loss')
        .in('mt5_account_id', accountIds)
        .order('recorded_at', { ascending: true });

      if (startDate) {
        historyQuery = historyQuery.gte('recorded_at', startDate.toISOString());
      }

      const { data: historyData } = await historyQuery;

      // Build chart data from trade history (calculate balance backwards)
      const dataMap = new Map<string, { balance: number; equity: number; profit_loss: number; count: number }>();

      if (tradeData && tradeData.length > 0) {
        // Calculate cumulative P/L from trades to build historical balance
        let cumulativeProfit = 0;
        const tradesByDate = new Map<string, number>();

        // Sum profits by date
        tradeData.forEach((trade) => {
          if (!trade.close_time) return;
          const dateKey = new Date(trade.close_time).toISOString().split('T')[0];
          const totalProfit = Number(trade.profit || 0) + Number(trade.commission || 0) + Number(trade.swap || 0);
          
          if (!tradesByDate.has(dateKey)) {
            tradesByDate.set(dateKey, 0);
          }
          tradesByDate.set(dateKey, tradesByDate.get(dateKey)! + totalProfit);
        });

        // Calculate total profit from all trades
        const totalAllProfit = Array.from(tradesByDate.values()).reduce((sum, p) => sum + p, 0);

        // Starting balance = current balance - total profit
        const startingBalance = currentBalance - totalAllProfit;

        // Build running balance day by day
        let runningBalance = startingBalance;
        const sortedDates = Array.from(tradesByDate.keys()).sort();

        sortedDates.forEach((dateKey) => {
          const dailyProfit = tradesByDate.get(dateKey) || 0;
          runningBalance += dailyProfit;
          cumulativeProfit += dailyProfit;

          dataMap.set(dateKey, {
            balance: runningBalance,
            equity: runningBalance, // Approximate equity as balance when position is closed
            profit_loss: cumulativeProfit,
            count: 1,
          });
        });

        // Add today's data if we have current account data
        const todayKey = new Date().toISOString().split('T')[0];
        if (!dataMap.has(todayKey) && accountData) {
          dataMap.set(todayKey, {
            balance: currentBalance,
            equity: currentEquity,
            profit_loss: cumulativeProfit,
            count: 1,
          });
        }
      }

      // Merge with account_history data (for more granular/recent data)
      historyData?.forEach((item) => {
        const dateKey = new Date(item.recorded_at).toISOString().split('T')[0];
        // Prefer account_history if it has higher values (more recent sync)
        const existing = dataMap.get(dateKey);
        if (!existing || Number(item.balance || 0) > existing.balance) {
          dataMap.set(dateKey, {
            balance: Number(item.balance || 0),
            equity: Number(item.equity || 0),
            profit_loss: Number(item.profit_loss || 0),
            count: 1,
          });
        }
      });

      // Filter by timeframe
      let filteredEntries = Array.from(dataMap.entries());
      if (startDate) {
        const startMs = startDate.getTime();
        filteredEntries = filteredEntries.filter(([dateKey]) => {
          return new Date(dateKey).getTime() >= startMs;
        });
      }

      // Convert to array and format
      const chartData: ChartDataPoint[] = filteredEntries
        .map(([dateKey, values]) => ({
          date: new Date(dateKey).toLocaleDateString('th-TH', { day: '2-digit', month: 'short' }),
          rawDate: dateKey, // Keep for sorting
          balance: values.balance,
          equity: values.equity,
          profit_loss: values.profit_loss,
        }))
        .sort((a, b) => new Date(a.rawDate).getTime() - new Date(b.rawDate).getTime())
        .map(({ rawDate, ...rest }) => rest); // Remove rawDate from final output

      setData(chartData);
    } catch (error) {
      console.error('Error fetching history data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const formatValue = (value: number) => {
    return `$${value.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-card/95 backdrop-blur-sm border border-border rounded-lg p-3 shadow-xl">
          <p className="text-sm text-muted-foreground mb-2">{label}</p>
          {payload.map((entry: any, index: number) => (
            <p key={index} className="text-sm font-medium" style={{ color: entry.color }}>
              {entry.name}: {formatValue(entry.value)}
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  if (accountIds.length === 0) {
    return null;
  }

  return (
    <Card className="mb-6">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="flex items-center gap-2">
          <TrendingUp className="w-5 h-5 text-primary" />
          กราฟ Balance / Equity
        </CardTitle>
        <div className="flex items-center gap-1">
          <Calendar className="w-4 h-4 text-muted-foreground mr-2" />
          {(['7d', '30d', '60d', 'all'] as TimeFrame[]).map((tf) => (
            <Button
              key={tf}
              variant={timeframe === tf ? 'default' : 'outline'}
              size="sm"
              onClick={() => setTimeframe(tf)}
              className="text-xs px-2 py-1 h-7"
            >
              {tf === 'all' ? 'ทั้งหมด' : tf.replace('d', ' วัน')}
            </Button>
          ))}
        </div>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <Skeleton className="h-[300px] w-full" />
        ) : data.length === 0 ? (
          <div className="h-[300px] flex items-center justify-center text-muted-foreground">
            ยังไม่มีข้อมูลประวัติ
          </div>
        ) : (
          <div className="h-[300px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="balanceGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(142 71% 45%)" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="hsl(142 71% 45%)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="equityGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(187 100% 50%)" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="hsl(187 100% 50%)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="plGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(38 92% 50%)" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="hsl(38 92% 50%)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(222 30% 20%)" />
                <XAxis 
                  dataKey="date" 
                  stroke="hsl(215 20% 55%)" 
                  fontSize={11}
                  tickLine={false}
                />
                <YAxis 
                  stroke="hsl(215 20% 55%)" 
                  fontSize={11}
                  tickLine={false}
                  tickFormatter={formatValue}
                />
                <Tooltip content={<CustomTooltip />} />
                <Legend 
                  wrapperStyle={{ paddingTop: '10px' }}
                  formatter={(value) => <span className="text-sm text-foreground">{value}</span>}
                />
                <Area
                  type="monotone"
                  dataKey="balance"
                  name="Balance"
                  stroke="hsl(142 71% 45%)"
                  strokeWidth={2}
                  fill="url(#balanceGradient)"
                />
                <Area
                  type="monotone"
                  dataKey="equity"
                  name="Equity"
                  stroke="hsl(187 100% 50%)"
                  strokeWidth={2}
                  fill="url(#equityGradient)"
                />
                <Area
                  type="monotone"
                  dataKey="profit_loss"
                  name="P/L"
                  stroke="hsl(38 92% 50%)"
                  strokeWidth={2}
                  fill="url(#plGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default AccountHistoryChart;
