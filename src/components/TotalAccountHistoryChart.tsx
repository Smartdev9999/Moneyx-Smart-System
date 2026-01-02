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

type TimeFrame = '7d' | '30d' | '60d' | 'all';

const TotalAccountHistoryChart = () => {
  const [data, setData] = useState<ChartDataPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [timeframe, setTimeframe] = useState<TimeFrame>('30d');

  useEffect(() => {
    fetchHistoryData();
  }, [timeframe]);

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

      // Fetch all MT5 accounts current data
      const { data: allAccounts } = await supabase
        .from('mt5_accounts')
        .select('id, balance, equity, profit_loss');

      const totalCurrentBalance = allAccounts?.reduce((sum, a) => sum + Number(a.balance || 0), 0) || 0;
      const totalCurrentEquity = allAccounts?.reduce((sum, a) => sum + Number(a.equity || 0), 0) || 0;
      const allAccountIds = allAccounts?.map(a => a.id) || [];

      if (allAccountIds.length === 0) {
        setData([]);
        setIsLoading(false);
        return;
      }

      // Fetch account_history for all accounts
      let historyQuery = supabase
        .from('account_history')
        .select('recorded_at, balance, equity, profit_loss, mt5_account_id')
        .in('mt5_account_id', allAccountIds)
        .order('recorded_at', { ascending: true });

      if (startDate) {
        historyQuery = historyQuery.gte('recorded_at', startDate.toISOString());
      }

      const { data: historyData } = await historyQuery;

      // Fetch trade history for all accounts
      const { data: tradeData } = await supabase
        .from('trade_history')
        .select('close_time, profit, commission, swap, mt5_account_id')
        .in('mt5_account_id', allAccountIds)
        .eq('entry_type', 'out')
        .not('close_time', 'is', null)
        .order('close_time', { ascending: true });

      // Build aggregated data by date
      const dataMap = new Map<string, { balance: number; equity: number; profit_loss: number }>();

      // Process trade data to build historical totals
      if (tradeData && tradeData.length > 0) {
        // Group trades by account and date
        const accountTradesMap = new Map<string, Map<string, number>>();
        
        tradeData.forEach((trade) => {
          if (!trade.close_time) return;
          const dateKey = new Date(trade.close_time).toISOString().split('T')[0];
          const totalProfit = Number(trade.profit || 0) + Number(trade.commission || 0) + Number(trade.swap || 0);
          
          if (!accountTradesMap.has(trade.mt5_account_id)) {
            accountTradesMap.set(trade.mt5_account_id, new Map());
          }
          const accountMap = accountTradesMap.get(trade.mt5_account_id)!;
          
          if (!accountMap.has(dateKey)) {
            accountMap.set(dateKey, 0);
          }
          accountMap.set(dateKey, accountMap.get(dateKey)! + totalProfit);
        });

        // Calculate per-account starting balances and build running totals
        const accountStartingBalances = new Map<string, number>();
        
        allAccounts?.forEach((account) => {
          const accountTrades = accountTradesMap.get(account.id);
          if (accountTrades) {
            const totalProfit = Array.from(accountTrades.values()).reduce((sum, p) => sum + p, 0);
            accountStartingBalances.set(account.id, Number(account.balance || 0) - totalProfit);
          } else {
            accountStartingBalances.set(account.id, Number(account.balance || 0));
          }
        });

        // Get all dates from all accounts
        const allDates = new Set<string>();
        accountTradesMap.forEach((trades) => {
          trades.forEach((_, date) => allDates.add(date));
        });

        // Build cumulative balances by date
        const sortedDates = Array.from(allDates).sort();
        const accountRunningBalances = new Map<string, number>();
        const accountCumulativePL = new Map<string, number>();
        
        allAccounts?.forEach((account) => {
          accountRunningBalances.set(account.id, accountStartingBalances.get(account.id) || 0);
          accountCumulativePL.set(account.id, 0);
        });

        sortedDates.forEach((dateKey) => {
          let totalBalance = 0;
          let totalPL = 0;

          allAccounts?.forEach((account) => {
            const accountTrades = accountTradesMap.get(account.id);
            const dailyProfit = accountTrades?.get(dateKey) || 0;
            
            let runningBalance = accountRunningBalances.get(account.id) || 0;
            let cumulativePL = accountCumulativePL.get(account.id) || 0;
            
            runningBalance += dailyProfit;
            cumulativePL += dailyProfit;
            
            accountRunningBalances.set(account.id, runningBalance);
            accountCumulativePL.set(account.id, cumulativePL);
            
            totalBalance += runningBalance;
            totalPL += cumulativePL;
          });

          dataMap.set(dateKey, {
            balance: totalBalance,
            equity: totalBalance,
            profit_loss: totalPL,
          });
        });
      }

      // Merge with account_history data (aggregate by date)
      if (historyData && historyData.length > 0) {
        const historyByDate = new Map<string, Map<string, { balance: number; equity: number; profit_loss: number }>>();
        
        historyData.forEach((item) => {
          const dateKey = new Date(item.recorded_at).toISOString().split('T')[0];
          
          if (!historyByDate.has(dateKey)) {
            historyByDate.set(dateKey, new Map());
          }
          const dateMap = historyByDate.get(dateKey)!;
          
          // Use latest value for each account per day
          dateMap.set(item.mt5_account_id, {
            balance: Number(item.balance || 0),
            equity: Number(item.equity || 0),
            profit_loss: Number(item.profit_loss || 0),
          });
        });

        // Sum values across accounts for each date
        historyByDate.forEach((accountsData, dateKey) => {
          let totalBalance = 0;
          let totalEquity = 0;
          let totalPL = 0;
          
          accountsData.forEach((values) => {
            totalBalance += values.balance;
            totalEquity += values.equity;
            totalPL += values.profit_loss;
          });

          const existing = dataMap.get(dateKey);
          // Prefer history data if it's more comprehensive
          if (!existing || totalBalance > existing.balance) {
            dataMap.set(dateKey, {
              balance: totalBalance,
              equity: totalEquity,
              profit_loss: totalPL,
            });
          }
        });
      }

      // Add today's data from current account data
      const todayKey = new Date().toISOString().split('T')[0];
      if (!dataMap.has(todayKey) && allAccounts && allAccounts.length > 0) {
        const totalPL = allAccounts.reduce((sum, a) => sum + Number(a.profit_loss || 0), 0);
        dataMap.set(todayKey, {
          balance: totalCurrentBalance,
          equity: totalCurrentEquity,
          profit_loss: totalPL,
        });
      }

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
          rawDate: dateKey,
          balance: values.balance,
          equity: values.equity,
          profit_loss: values.profit_loss,
        }))
        .sort((a, b) => new Date(a.rawDate).getTime() - new Date(b.rawDate).getTime())
        .map(({ rawDate, ...rest }) => rest);

      setData(chartData);
    } catch (error) {
      console.error('Error fetching total history data:', error);
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

  return (
    <Card className="mb-6">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="flex items-center gap-2">
          <TrendingUp className="w-5 h-5 text-primary" />
          กราฟรวม Balance / Equity / P&L ทุก Account
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
                  <linearGradient id="totalBalanceGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(142 71% 45%)" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="hsl(142 71% 45%)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="totalEquityGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="hsl(187 100% 50%)" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="hsl(187 100% 50%)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="totalPlGradient" x1="0" y1="0" x2="0" y2="1">
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
                  name="Total Balance"
                  stroke="hsl(142 71% 45%)"
                  strokeWidth={2}
                  fill="url(#totalBalanceGradient)"
                />
                <Area
                  type="monotone"
                  dataKey="equity"
                  name="Total Equity"
                  stroke="hsl(187 100% 50%)"
                  strokeWidth={2}
                  fill="url(#totalEquityGradient)"
                />
                <Area
                  type="monotone"
                  dataKey="profit_loss"
                  name="Total P/L"
                  stroke="hsl(38 92% 50%)"
                  strokeWidth={2}
                  fill="url(#totalPlGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default TotalAccountHistoryChart;
