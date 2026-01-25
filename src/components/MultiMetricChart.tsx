import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  ComposedChart,
  Line,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
} from 'recharts';
import { TrendingUp, Calendar } from 'lucide-react';

interface ChartDataPoint {
  date: string;
  rawDate: string;
  value: number;
  dailyPL?: number;
}

type MetricType = 'growth' | 'balance' | 'profit' | 'drawdown' | 'margin';
type TimeFrame = '7d' | '30d' | '60d' | 'all';

interface MultiMetricChartProps {
  accountIds?: string[];
}

const MultiMetricChart = ({ accountIds }: MultiMetricChartProps) => {
  const [data, setData] = useState<ChartDataPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [metric, setMetric] = useState<MetricType>('growth');
  const [timeframe, setTimeframe] = useState<TimeFrame>('30d');
  const [currency, setCurrency] = useState<string>('USD');

  useEffect(() => {
    fetchMetricData();
  }, [metric, timeframe, accountIds]);

  const fetchMetricData = async () => {
    setIsLoading(true);
    try {
      // Early return if accountIds is an empty array (filtered but no matches)
      if (accountIds && accountIds.length === 0) {
        setData([]);
        setIsLoading(false);
        return;
      }
      
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

      // Get account IDs and currency
      let targetAccountIds = accountIds;
      if (!targetAccountIds || targetAccountIds.length === 0) {
        const { data: allAccounts } = await supabase
          .from('mt5_accounts')
          .select('id, balance, equity, initial_balance, currency');
        targetAccountIds = allAccounts?.map(a => a.id) || [];
        // Get currency from first account
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

      // Fetch account history
      let historyQuery = supabase
        .from('account_history')
        .select('recorded_at, balance, equity, drawdown, margin_level, profit_loss, mt5_account_id')
        .in('mt5_account_id', targetAccountIds)
        .order('recorded_at', { ascending: true });

      if (startDate) {
        historyQuery = historyQuery.gte('recorded_at', startDate.toISOString());
      }

      const { data: historyData } = await historyQuery;

      // Fetch trade history for daily P/L overlay
      let tradeQuery = supabase
        .from('trade_history')
        .select('close_time, profit, commission, swap')
        .in('mt5_account_id', targetAccountIds)
        .eq('entry_type', 'out')
        .not('close_time', 'is', null);

      if (startDate) {
        tradeQuery = tradeQuery.gte('close_time', startDate.toISOString());
      }

      const { data: tradeData } = await tradeQuery;

      // Aggregate daily P/L
      const dailyPLMap = new Map<string, number>();
      tradeData?.forEach(trade => {
        if (!trade.close_time) return;
        const dateKey = new Date(trade.close_time).toISOString().split('T')[0];
        const pl = Number(trade.profit || 0) + Number(trade.commission || 0) + Number(trade.swap || 0);
        dailyPLMap.set(dateKey, (dailyPLMap.get(dateKey) || 0) + pl);
      });

      // Get initial balance for growth calculation
      const { data: accountData } = await supabase
        .from('mt5_accounts')
        .select('initial_balance, balance')
        .in('id', targetAccountIds);

      const totalInitialBalance = accountData?.reduce((sum, a) => sum + Number(a.initial_balance || a.balance || 0), 0) || 1;

      // Aggregate history by date
      const dataMap = new Map<string, { balance: number; equity: number; drawdown: number; margin: number; pl: number; count: number }>();

      historyData?.forEach(item => {
        const dateKey = new Date(item.recorded_at).toISOString().split('T')[0];
        const existing = dataMap.get(dateKey) || { balance: 0, equity: 0, drawdown: 0, margin: 0, pl: 0, count: 0 };
        
        dataMap.set(dateKey, {
          balance: existing.balance + Number(item.balance || 0),
          equity: existing.equity + Number(item.equity || 0),
          drawdown: Math.max(existing.drawdown, Number(item.drawdown || 0)),
          margin: existing.margin + Number(item.margin_level || 0),
          pl: existing.pl + Number(item.profit_loss || 0),
          count: existing.count + 1,
        });
      });

      // Calculate metric values
      let chartData: ChartDataPoint[] = [];
      let cumulativeProfit = 0;

      const sortedDates = Array.from(dataMap.keys()).sort();

      sortedDates.forEach(dateKey => {
        const values = dataMap.get(dateKey)!;
        const dailyPL = dailyPLMap.get(dateKey) || 0;
        cumulativeProfit += dailyPL;

        let value: number;
        switch (metric) {
          case 'growth':
            value = ((values.balance - totalInitialBalance) / totalInitialBalance) * 100;
            break;
          case 'balance':
            value = values.balance;
            break;
          case 'profit':
            value = cumulativeProfit;
            break;
          case 'drawdown':
            value = values.drawdown;
            break;
          case 'margin':
            value = values.count > 0 ? values.margin / values.count : 0;
            break;
          default:
            value = 0;
        }

        chartData.push({
          date: new Date(dateKey).toLocaleDateString('th-TH', { day: '2-digit', month: 'short' }),
          rawDate: dateKey,
          value,
          dailyPL,
        });
      });

      // Filter by timeframe
      if (startDate) {
        chartData = chartData.filter(d => new Date(d.rawDate).getTime() >= startDate!.getTime());
      }

      setData(chartData);
    } catch (error) {
      console.error('Error fetching metric data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const formatValue = (value: number) => {
    const currencyLabel = currency === 'USC' ? ' USC' : '';
    if (metric === 'growth' || metric === 'drawdown' || metric === 'margin') {
      return `${value.toFixed(1)}%`;
    }
    if (Math.abs(value) >= 1000) {
      return currency === 'USC' 
        ? `${(value / 1000).toFixed(1)}K${currencyLabel}`
        : `$${(value / 1000).toFixed(1)}K`;
    }
    return currency === 'USC' 
      ? `${value.toFixed(0)}${currencyLabel}`
      : `$${value.toFixed(0)}`;
  };

  const getMetricLabel = (m: MetricType) => {
    switch (m) {
      case 'growth': return 'Growth %';
      case 'balance': return 'Balance';
      case 'profit': return 'Profit';
      case 'drawdown': return 'Drawdown';
      case 'margin': return 'Margin';
    }
  };

  const getLineColor = () => {
    switch (metric) {
      case 'growth': return 'hsl(142 71% 45%)';
      case 'balance': return 'hsl(217 91% 60%)';
      case 'profit': return 'hsl(38 92% 50%)';
      case 'drawdown': return 'hsl(0 84% 60%)';
      case 'margin': return 'hsl(262 83% 58%)';
    }
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const mainValue = payload.find((p: any) => p.dataKey === 'value');
      const dailyPL = payload.find((p: any) => p.dataKey === 'dailyPL');

      return (
        <div className="bg-card/95 backdrop-blur-sm border border-border rounded-lg p-3 shadow-xl">
          <p className="text-sm text-muted-foreground mb-2">{label}</p>
          {mainValue && (
            <p className="text-sm font-bold" style={{ color: getLineColor() }}>
              {getMetricLabel(metric)}: {formatValue(mainValue.value)}
            </p>
          )}
          {dailyPL && dailyPL.value !== 0 && (
            <p className={`text-xs mt-1 ${dailyPL.value >= 0 ? 'text-emerald-500' : 'text-red-500'}`}>
              Daily P/L: {dailyPL.value >= 0 ? '+' : ''}{dailyPL.value.toFixed(0)} {currency === 'USC' ? 'USC' : 'USD'}
            </p>
          )}
        </div>
      );
    }
    return null;
  };

  return (
    <Card className="mb-6">
      <CardHeader className="flex flex-col gap-3 pb-2">
        <div className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-primary" />
            Performance Chart
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
                {tf === 'all' ? 'All' : tf.replace('d', 'D')}
              </Button>
            ))}
          </div>
        </div>
        <Tabs value={metric} onValueChange={(v) => setMetric(v as MetricType)} className="w-full">
          <TabsList className="grid grid-cols-5 w-full max-w-lg">
            <TabsTrigger value="growth" className="text-xs">Growth</TabsTrigger>
            <TabsTrigger value="balance" className="text-xs">Balance</TabsTrigger>
            <TabsTrigger value="profit" className="text-xs">Profit</TabsTrigger>
            <TabsTrigger value="drawdown" className="text-xs">Drawdown</TabsTrigger>
            <TabsTrigger value="margin" className="text-xs">Margin</TabsTrigger>
          </TabsList>
        </Tabs>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <Skeleton className="h-[280px] w-full" />
        ) : data.length === 0 ? (
          <div className="h-[280px] flex items-center justify-center text-muted-foreground">
            ยังไม่มีข้อมูลประวัติ
          </div>
        ) : (
          <div className="h-[280px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <ComposedChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="metricGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={getLineColor()} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={getLineColor()} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                <XAxis
                  dataKey="date"
                  stroke="hsl(var(--muted-foreground))"
                  fontSize={10}
                  tickLine={false}
                  axisLine={false}
                />
                <YAxis
                  stroke="hsl(var(--muted-foreground))"
                  fontSize={10}
                  tickLine={false}
                  axisLine={false}
                  tickFormatter={formatValue}
                />
                <Tooltip content={<CustomTooltip />} />
                {/* Daily P/L overlay bars */}
                <Bar
                  dataKey="dailyPL"
                  fill="hsl(45 93% 47% / 0.3)"
                  radius={[2, 2, 0, 0]}
                  maxBarSize={20}
                />
                {/* Main metric line with area fill */}
                <Area
                  type="monotone"
                  dataKey="value"
                  stroke={getLineColor()}
                  strokeWidth={2}
                  fill="url(#metricGradient)"
                />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke={getLineColor()}
                  strokeWidth={2}
                  dot={false}
                  activeDot={{ r: 4, fill: getLineColor() }}
                />
              </ComposedChart>
            </ResponsiveContainer>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default MultiMetricChart;
