import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { 
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import TotalAccountHistoryChart from '@/components/TotalAccountHistoryChart';
import { 
  ArrowLeft, 
  CreditCard,
  TrendingUp,
  TrendingDown,
  Activity,
  DollarSign,
  BarChart3,
  Calendar,
  Clock,
  Target,
  Percent,
  Wifi,
  WifiOff,
  Pause,
  XCircle
} from 'lucide-react';

interface MT5Account {
  id: string;
  account_number: string;
  package_type: string;
  balance: number;
  equity: number;
  profit_loss: number;
  open_orders: number;
  floating_pl: number;
  total_profit: number;
  initial_balance: number;
  total_deposit: number;
  total_withdrawal: number;
  max_drawdown: number;
  win_trades: number;
  loss_trades: number;
  total_trades: number;
  margin_level: number;
  drawdown: number;
  last_sync: string | null;
  ea_status: string | null;
  currency: string | null;
  trading_system: { name: string } | null;
  customer: { name: string; customer_id: string } | null;
}

interface TradeHistory {
  id: string;
  deal_ticket: number;
  order_ticket: number | null;
  symbol: string;
  deal_type: string;
  entry_type: string;
  volume: number;
  open_price: number;
  close_price: number | null;
  profit: number;
  swap: number;
  commission: number;
  comment: string | null;
  open_time: string | null;
  close_time: string | null;
}

const AccountPortfolio = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user, isAdmin, loading: authLoading } = useAuth();
  
  const [account, setAccount] = useState<MT5Account | null>(null);
  const [tradeHistory, setTradeHistory] = useState<TradeHistory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [historyFilter, setHistoryFilter] = useState<string>('all');

  useEffect(() => {
    if (!authLoading && !isAdmin) {
      navigate('/');
      return;
    }

    if (id && isAdmin) {
      fetchAccountData();
      fetchTradeHistory();
    }
  }, [id, isAdmin, authLoading, historyFilter]);

  const fetchAccountData = async () => {
    try {
      const { data, error } = await supabase
        .from('mt5_accounts')
        .select(`
          *,
          trading_system:trading_systems(name),
          customer:customers(name, customer_id)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;
      setAccount(data as any);
    } catch (error) {
      console.error('Error fetching account:', error);
    }
  };

  const fetchTradeHistory = async () => {
    setIsLoading(true);
    try {
      // Only fetch closed positions (entry_type = 'out') which have actual profit/loss
      let query = supabase
        .from('trade_history')
        .select('*')
        .eq('mt5_account_id', id)
        .eq('entry_type', 'out')  // Only closed positions
        .order('close_time', { ascending: false, nullsFirst: false });

      // Apply time filter
      if (historyFilter !== 'all') {
        const now = new Date();
        let startDate: Date;
        
        switch (historyFilter) {
          case '7d':
            startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            break;
          case '30d':
            startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
            break;
          case '90d':
            startDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
            break;
          default:
            startDate = new Date(0);
        }
        
        query = query.gte('close_time', startDate.toISOString());
      }

      const { data, error } = await query.limit(500);

      if (error) throw error;
      setTradeHistory((data || []) as TradeHistory[]);
    } catch (error) {
      console.error('Error fetching trade history:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Get currency from account (auto-detected from EA)
  const getCurrency = () => account?.currency || 'USD';
  
  // Format currency with proper symbol based on account currency
  const formatCurrency = (value: number, showSign: boolean = false) => {
    const currency = getCurrency();
    const formattedValue = Number(value || 0).toLocaleString('en-US', { minimumFractionDigits: 2 });
    const sign = showSign && value >= 0 ? '+' : '';
    
    // USC = US Cent account - display without $ symbol, add USC suffix
    if (currency === 'USC') {
      return `${sign}${formattedValue} USC`;
    }
    // Default USD or other currencies
    const symbol = currency === 'EUR' ? '€' : '$';
    return `${sign}${symbol}${formattedValue}`;
  };

  const formatPercent = (value: number) => {
    return `${Number(value || 0).toFixed(2)}%`;
  };

  const getWinRate = () => {
    if (!account || account.total_trades === 0) return 0;
    return ((account.win_trades || 0) / account.total_trades) * 100;
  };

  // Net Profit: Use total_profit from EA (correct value excluding withdrawals)
  // Fallback: balance - initial_balance + total_withdrawal
  const getNetProfit = () => {
    if (!account) return 0;
    // Priority 1: Use total_profit from EA (already calculated correctly)
    if (account.total_profit !== null && account.total_profit !== undefined && account.total_profit !== 0) {
      return account.total_profit;
    }
    // Fallback: Add back withdrawals to get actual profit
    return (account.balance || 0) - (account.initial_balance || 0) + (account.total_withdrawal || 0);
  };

  const getROI = () => {
    if (!account || !account.initial_balance || account.initial_balance === 0) return 0;
    return (getNetProfit() / account.initial_balance) * 100;
  };

  // Check if EA is offline (no sync in last 10 minutes)
  const isEAOffline = (): boolean => {
    if (!account?.last_sync) return true;
    const lastSyncTime = new Date(account.last_sync).getTime();
    const now = new Date().getTime();
    const tenMinutes = 10 * 60 * 1000;
    return (now - lastSyncTime) > tenMinutes;
  };

  const getEAStatusBadge = () => {
    // Check for offline first (no sync in 10 minutes)
    if (isEAOffline()) {
      return (
        <Badge variant="outline" className="text-gray-400 border-gray-500 bg-gray-900/20">
          <WifiOff className="w-3 h-3 mr-1" /> Offline
        </Badge>
      );
    }

    // Show EA status from database
    const status = account?.ea_status || 'offline';
    switch (status) {
      case 'working':
        return (
          <Badge variant="outline" className="text-lime-400 border-lime-500 bg-lime-900/20">
            <Wifi className="w-3 h-3 mr-1" /> Working
          </Badge>
        );
      case 'paused':
        return (
          <Badge variant="outline" className="text-orange-400 border-orange-500 bg-orange-900/20">
            <Pause className="w-3 h-3 mr-1" /> Paused
          </Badge>
        );
      case 'suspended':
        return (
          <Badge variant="outline" className="text-red-400 border-red-500 bg-red-900/20">
            <XCircle className="w-3 h-3 mr-1" /> Suspended
          </Badge>
        );
      case 'expired':
        return (
          <Badge variant="outline" className="text-red-400 border-red-500 bg-red-900/20">
            <Clock className="w-3 h-3 mr-1" /> Expired
          </Badge>
        );
      case 'invalid':
        return (
          <Badge variant="outline" className="text-red-400 border-red-500 bg-red-900/20">
            <XCircle className="w-3 h-3 mr-1" /> Invalid
          </Badge>
        );
      default:
        return (
          <Badge variant="outline" className="text-gray-400 border-gray-500 bg-gray-900/20">
            <WifiOff className="w-3 h-3 mr-1" /> Offline
          </Badge>
        );
    }
  };

  if (authLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  if (!isAdmin) return null;

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-4 mb-8">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-bold">Portfolio: {account?.account_number || 'Loading...'}</h1>
              {account?.currency && (
                <Badge variant="outline" className={account.currency === 'USC' ? 'text-amber-400 border-amber-500' : 'text-emerald-400 border-emerald-500'}>
                  {account.currency === 'USC' ? 'Cent Account' : account.currency}
                </Badge>
              )}
            </div>
            <p className="text-muted-foreground">
              {account?.customer?.name} ({account?.customer?.customer_id})
            </p>
          </div>
        </div>

        {/* Portfolio Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4 mb-8">
          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <DollarSign className="w-4 h-4" />
                Balance
              </div>
              <p className="text-xl font-bold">{formatCurrency(account?.balance || 0)}</p>
            </CardContent>
          </Card>
          
          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <Activity className="w-4 h-4" />
                Equity
              </div>
              <p className="text-xl font-bold">{formatCurrency(account?.equity || 0)}</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <TrendingUp className="w-4 h-4" />
                Net Profit
              </div>
              <p className={`text-xl font-bold ${getNetProfit() >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                {formatCurrency(getNetProfit(), true)}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <Percent className="w-4 h-4" />
                ROI
              </div>
              <p className={`text-xl font-bold ${getROI() >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                {getROI() >= 0 ? '+' : ''}{formatPercent(getROI())}
              </p>
            </CardContent>
          </Card>

          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <Target className="w-4 h-4" />
                Win Rate
              </div>
              <p className="text-xl font-bold">{formatPercent(getWinRate())}</p>
            </CardContent>
          </Card>

          <Card className="bg-card/50">
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                <TrendingDown className="w-4 h-4" />
                Max DD
              </div>
              <p className="text-xl font-bold text-red-500">
                {formatPercent(account?.max_drawdown || 0)}
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Trading Stats */}
        <div className="grid md:grid-cols-3 gap-4 mb-8">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Trading Statistics</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total Trades</span>
                  <span className="font-medium">{account?.total_trades || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Win Trades</span>
                  <span className="font-medium text-green-500">{account?.win_trades || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Loss Trades</span>
                  <span className="font-medium text-red-500">{account?.loss_trades || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Open Orders</span>
                  <span className="font-medium">{account?.open_orders || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Floating P/L</span>
                  <span className={`font-medium ${(account?.floating_pl || 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                    {formatCurrency(account?.floating_pl || 0)}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Account Info</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Initial Balance</span>
                  <span className="font-medium">{formatCurrency(account?.initial_balance || 0)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total Deposit</span>
                  <span className="font-medium text-green-500">{formatCurrency(account?.total_deposit || 0)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total Withdrawal</span>
                  <span className="font-medium text-red-500">{formatCurrency(account?.total_withdrawal || 0)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total Profit</span>
                  <span className={`font-medium ${(account?.total_profit || 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                    {formatCurrency(account?.total_profit || 0)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Margin Level</span>
                  <span className="font-medium">{formatPercent(account?.margin_level || 0)}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">System Info</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">EA Status</span>
                  {getEAStatusBadge()}
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Trading System</span>
                  <span className="font-medium">{account?.trading_system?.name || '-'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Package</span>
                  <span className="font-medium">{account?.package_type || '-'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Current DD</span>
                  <span className="font-medium text-red-500">{formatPercent(account?.drawdown || 0)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Last Sync</span>
                  <span className="font-medium text-xs">
                    {account?.last_sync ? new Date(account.last_sync).toLocaleString('th-TH') : '-'}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Performance Chart */}
        {account && (
          <div className="mb-8">
            <TotalAccountHistoryChart accountIds={[account.id]} />
          </div>
        )}

        {/* Trade History */}
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="w-5 h-5" />
                  Trade History
                </CardTitle>
                <CardDescription>
                  ประวัติการเทรดทั้งหมด ({tradeHistory.length} รายการ)
                </CardDescription>
              </div>
              <Select value={historyFilter} onValueChange={setHistoryFilter}>
                <SelectTrigger className="w-32">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="7d">7 วัน</SelectItem>
                  <SelectItem value="30d">30 วัน</SelectItem>
                  <SelectItem value="90d">90 วัน</SelectItem>
                  <SelectItem value="all">ทั้งหมด</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="space-y-2">
                {[...Array(5)].map((_, i) => (
                  <Skeleton key={i} className="h-12 w-full" />
                ))}
              </div>
            ) : tradeHistory.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                <BarChart3 className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <p className="text-lg font-medium">ยังไม่มีประวัติการเทรด</p>
                <p className="text-sm">ข้อมูลจะถูกบันทึกเมื่อมีการปิดออเดอร์</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Time</TableHead>
                      <TableHead>Symbol</TableHead>
                      <TableHead>Type</TableHead>
                      <TableHead className="text-right">Volume</TableHead>
                      <TableHead className="text-right">Price</TableHead>
                      <TableHead className="text-right">Close Price</TableHead>
                      <TableHead className="text-right">Profit</TableHead>
                      <TableHead>Comment</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {tradeHistory.map((trade) => (
                      <TableRow key={trade.id}>
                        <TableCell className="text-xs">
                          {trade.close_time ? new Date(trade.close_time).toLocaleString('th-TH') : '-'}
                        </TableCell>
                        <TableCell className="font-medium">{trade.symbol}</TableCell>
                        <TableCell>
                          {(() => {
                            // For closed positions (entry_type='out'), the original position is opposite of deal_type
                            // e.g., sell deal with entry_type='out' means closing a BUY position
                            const originalPositionType = trade.entry_type === 'out' 
                              ? (trade.deal_type === 'sell' ? 'BUY' : 'SELL')
                              : trade.deal_type.toUpperCase();
                            const isBuy = originalPositionType === 'BUY';
                            return (
                              <Badge variant={isBuy ? 'default' : 'secondary'}>
                                {originalPositionType}
                              </Badge>
                            );
                          })()}
                        </TableCell>
                        <TableCell className="text-right">{Number(trade.volume).toFixed(2)}</TableCell>
                        <TableCell className="text-right">{Number(trade.open_price).toFixed(2)}</TableCell>
                        <TableCell className="text-right">
                          {trade.close_price ? Number(trade.close_price).toFixed(2) : '-'}
                        </TableCell>
                        <TableCell className={`text-right font-medium ${Number(trade.profit) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                          {Number(trade.profit) >= 0 ? '+' : ''}{formatCurrency(trade.profit)}
                        </TableCell>
                        <TableCell className="text-xs text-muted-foreground max-w-32 truncate">
                          {trade.comment || '-'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default AccountPortfolio;