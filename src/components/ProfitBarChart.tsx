import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
  ReferenceLine,
} from 'recharts';
import { BarChart3 } from 'lucide-react';

interface ChartDataPoint {
  label: string;
  profit: number;
  rawDate?: string;
}

type PeriodType = 'daily' | 'weekly' | 'monthly';

interface ProfitBarChartProps {
  accountIds?: string[];
}

const ProfitBarChart = ({ accountIds }: ProfitBarChartProps) => {
  const [data, setData] = useState<ChartDataPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [period, setPeriod] = useState<PeriodType>('monthly');
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [availableYears, setAvailableYears] = useState<number[]>([new Date().getFullYear()]);
  const [currency, setCurrency] = useState<string>('USD');

  useEffect(() => {
    fetchProfitData();
  }, [period, selectedYear, accountIds]);

  const fetchProfitData = async () => {
    setIsLoading(true);
    try {
      // Early return if accountIds is an empty array (filtered but no matches)
      if (accountIds && accountIds.length === 0) {
        setData([]);
        setIsLoading(false);
        return;
      }
      
      // Get account IDs and currency
      let targetAccountIds = accountIds;
      if (!targetAccountIds || targetAccountIds.length === 0) {
        const { data: allAccounts } = await supabase
          .from('mt5_accounts')
          .select('id, currency');
        targetAccountIds = allAccounts?.map(a => a.id) || [];
        // Get currency from first account (assume all accounts have same currency)
        if (allAccounts && allAccounts.length > 0) {
          setCurrency(allAccounts[0].currency || 'USD');
        }
      } else {
        // Fetch currency for provided account IDs
        const { data: accountData } = await supabase
          .from('mt5_accounts')
          .select('currency')
          .in('id', targetAccountIds)
          .limit(1);
        if (accountData && accountData.length > 0) {
          setCurrency(accountData[0].currency || 'USD');
        }
      }

      if (targetAccountIds.length === 0) {
        setData([]);
        setIsLoading(false);
        return;
      }

      // Fetch trade history
      const { data: tradeData } = await supabase
        .from('trade_history')
        .select('close_time, profit, commission, swap')
        .in('mt5_account_id', targetAccountIds)
        .eq('entry_type', 'out')
        .not('close_time', 'is', null)
        .order('close_time', { ascending: true });

      if (!tradeData || tradeData.length === 0) {
        setData([]);
        setIsLoading(false);
        return;
      }

      // Find available years
      const years = new Set<number>();
      tradeData.forEach(trade => {
        if (trade.close_time) {
          years.add(new Date(trade.close_time).getFullYear());
        }
      });
      const sortedYears = Array.from(years).sort((a, b) => b - a);
      setAvailableYears(sortedYears.length > 0 ? sortedYears : [new Date().getFullYear()]);

      // Filter by selected year
      const yearFilteredTrades = tradeData.filter(trade => {
        if (!trade.close_time) return false;
        return new Date(trade.close_time).getFullYear() === selectedYear;
      });

      // Aggregate by period
      const aggregatedData = new Map<string, number>();

      yearFilteredTrades.forEach(trade => {
        if (!trade.close_time) return;
        const date = new Date(trade.close_time);
        const totalProfit = Number(trade.profit || 0) + Number(trade.commission || 0) + Number(trade.swap || 0);

        let key: string;
        if (period === 'daily') {
          key = date.toISOString().split('T')[0];
        } else if (period === 'weekly') {
          const week = getWeekNumber(date);
          key = `W${week}`;
        } else {
          key = date.toLocaleString('en-US', { month: 'short' });
        }

        aggregatedData.set(key, (aggregatedData.get(key) || 0) + totalProfit);
      });

      // Format data for chart
      let chartData: ChartDataPoint[];

      if (period === 'monthly') {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        chartData = months.map(month => ({
          label: month,
          profit: aggregatedData.get(month) || 0,
        }));
      } else if (period === 'weekly') {
        chartData = [];
        for (let i = 1; i <= 52; i++) {
          const key = `W${i}`;
          chartData.push({
            label: key,
            profit: aggregatedData.get(key) || 0,
          });
        }
      } else {
        // Daily - sort by date
        chartData = Array.from(aggregatedData.entries())
          .map(([key, profit]) => ({
            label: new Date(key).toLocaleDateString('th-TH', { day: '2-digit', month: 'short' }),
            profit,
            rawDate: key,
          }))
          .sort((a, b) => new Date(a.rawDate!).getTime() - new Date(b.rawDate!).getTime());
      }

      setData(chartData);
    } catch (error) {
      console.error('Error fetching profit data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const getWeekNumber = (date: Date): number => {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
  };

  const formatValue = (value: number) => {
    if (Math.abs(value) >= 1000) {
      return `${(value / 1000).toFixed(1)}K`;
    }
    return value.toFixed(0);
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const value = payload[0].value;
      const isProfit = value >= 0;
      const currencyLabel = currency === 'USC' ? 'USC' : 'USD';
      return (
        <div className="bg-card/95 backdrop-blur-sm border border-border rounded-lg p-3 shadow-xl">
          <p className="text-sm text-muted-foreground mb-1">{label}</p>
          <p className={`text-sm font-bold ${isProfit ? 'text-emerald-500' : 'text-red-500'}`}>
            {isProfit ? '+' : ''}{formatValue(value)} {currencyLabel}
          </p>
        </div>
      );
    }
    return null;
  };

  const getBarColor = (value: number) => {
    return value >= 0 ? 'hsl(142 71% 45%)' : 'hsl(0 84% 60%)';
  };

  return (
    <Card className="mb-6">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="flex items-center gap-2">
          <BarChart3 className="w-5 h-5 text-primary" />
          Profit Analytics
        </CardTitle>
        <div className="flex items-center gap-2 flex-wrap">
          {/* Year Tabs */}
          <div className="flex items-center gap-1 mr-2">
            {availableYears.map((year) => (
              <Button
                key={year}
                variant={selectedYear === year ? 'default' : 'outline'}
                size="sm"
                onClick={() => setSelectedYear(year)}
                className="text-xs px-2 py-1 h-7"
              >
                {year}
              </Button>
            ))}
          </div>
          {/* Period Selector */}
          <div className="flex items-center gap-1">
            {(['daily', 'weekly', 'monthly'] as PeriodType[]).map((p) => (
              <Button
                key={p}
                variant={period === p ? 'secondary' : 'ghost'}
                size="sm"
                onClick={() => setPeriod(p)}
                className="text-xs px-2 py-1 h-7"
              >
                {p === 'daily' ? 'Daily' : p === 'weekly' ? 'Weekly' : 'Monthly'}
              </Button>
            ))}
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <Skeleton className="h-[250px] w-full" />
        ) : data.length === 0 ? (
          <div className="h-[250px] flex items-center justify-center text-muted-foreground">
            ยังไม่มีข้อมูล Trade
          </div>
        ) : (
          <div className="h-[250px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data} margin={{ top: 20, right: 10, left: 0, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                <XAxis
                  dataKey="label"
                  stroke="hsl(var(--muted-foreground))"
                  fontSize={10}
                  tickLine={false}
                  axisLine={false}
                  interval={period === 'weekly' ? 3 : 0}
                />
                <YAxis
                  stroke="hsl(var(--muted-foreground))"
                  fontSize={10}
                  tickLine={false}
                  axisLine={false}
                  tickFormatter={formatValue}
                />
                <Tooltip content={<CustomTooltip />} cursor={{ fill: 'hsl(var(--muted) / 0.3)' }} />
                <ReferenceLine y={0} stroke="hsl(var(--muted-foreground))" strokeWidth={1} />
                <Bar dataKey="profit" radius={[4, 4, 0, 0]} maxBarSize={40}>
                  {data.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={getBarColor(entry.profit)} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default ProfitBarChart;
