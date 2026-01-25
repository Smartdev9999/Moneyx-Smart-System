import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  LogOut,
  Settings,
  RefreshCw,
  XCircle,
  Clock,
  Wallet,
  TrendingUp,
  TrendingDown,
  BarChart3,
  PieChart,
  DollarSign,
  Percent,
  Activity
} from 'lucide-react';
import { FundPieChart } from '@/components/FundPieChart';
import { PortfolioSummary } from '@/components/PortfolioSummary';

interface CustomerData {
  id: string;
  customer_id: string;
  name: string;
  email: string;
  phone: string | null;
  broker: string | null;
  created_at: string;
}

interface MT5Account {
  id: string;
  account_number: string;
  balance: number;
  equity: number;
  profit_loss: number;
  total_profit: number;
  floating_pl: number;
  open_orders: number;
  drawdown: number;
  margin_level: number;
  account_type: string;
  currency: string;
  status: string;
  trading_system_id: string | null;
  last_sync: string | null;
}

interface FundWallet {
  id: string;
  wallet_address: string;
  network: string;
  label: string | null;
  is_active: boolean;
  last_sync: string | null;
}

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

interface WalletTransaction {
  id: string;
  tx_hash: string;
  tx_type: string;
  amount: number;
  block_time: string;
  classification: string | null;
}

type AccountTypeFilter = 'all' | 'real' | 'demo';

const Customer = () => {
  const navigate = useNavigate();
  const { user, loading, isCustomer, isApprovedCustomer, customerInfo, signOut } = useAuth();
  const [customerData, setCustomerData] = useState<CustomerData | null>(null);
  const [mt5Accounts, setMT5Accounts] = useState<MT5Account[]>([]);
  const [fundWallets, setFundWallets] = useState<FundWallet[]>([]);
  const [fundAllocations, setFundAllocations] = useState<FundAllocation[]>([]);
  const [walletTransactions, setWalletTransactions] = useState<WalletTransaction[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [accountTypeFilter, setAccountTypeFilter] = useState<AccountTypeFilter>('all');

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isApprovedCustomer && customerInfo.customerUuid) {
      fetchAllData();
    }
  }, [user, isApprovedCustomer, customerInfo.customerUuid]);

  const fetchAllData = async () => {
    if (!customerInfo.customerUuid) return;
    
    setIsLoading(true);
    try {
      // Fetch customer data
      const { data: customer } = await supabase
        .from('customers')
        .select('*')
        .eq('id', customerInfo.customerUuid)
        .single();

      if (customer) {
        setCustomerData(customer);
      }

      // Fetch MT5 accounts
      const { data: accounts } = await supabase
        .from('mt5_accounts')
        .select('*')
        .eq('customer_id', customerInfo.customerUuid)
        .order('created_at', { ascending: false });

      if (accounts) {
        setMT5Accounts(accounts);
      }

      // Fetch fund wallets
      const { data: wallets } = await supabase
        .from('fund_wallets')
        .select('*')
        .eq('customer_id', customerInfo.customerUuid)
        .eq('is_active', true);

      if (wallets) {
        setFundWallets(wallets);
      }

      // Fetch fund allocations
      const { data: allocations } = await supabase
        .from('fund_allocations')
        .select(`
          *,
          trading_systems:trading_system_id (name)
        `)
        .eq('customer_id', customerInfo.customerUuid);

      if (allocations) {
        setFundAllocations(allocations as FundAllocation[]);
      }

      // Fetch recent transactions
      if (wallets && wallets.length > 0) {
        const walletIds = wallets.map(w => w.id);
        const { data: transactions } = await supabase
          .from('wallet_transactions')
          .select('*')
          .in('wallet_id', walletIds)
          .order('block_time', { ascending: false })
          .limit(20);

        if (transactions) {
          setWalletTransactions(transactions);
        }
      }
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSignOut = async () => {
    await signOut();
    navigate('/auth');
  };

  // Filter accounts by type
  const filteredAccounts = mt5Accounts.filter(account => {
    if (accountTypeFilter === 'all') return true;
    if (accountTypeFilter === 'real') return account.account_type === 'real';
    if (accountTypeFilter === 'demo') return account.account_type === 'demo' || account.account_type === 'contest';
    return true;
  });

  // Calculate totals
  const totalBalance = filteredAccounts.reduce((sum, acc) => sum + (acc.balance || 0), 0);
  const totalEquity = filteredAccounts.reduce((sum, acc) => sum + (acc.equity || 0), 0);
  const totalProfit = filteredAccounts.reduce((sum, acc) => sum + (acc.total_profit || 0), 0);
  const totalFloatingPL = filteredAccounts.reduce((sum, acc) => sum + (acc.floating_pl || 0), 0);
  const totalOpenOrders = filteredAccounts.reduce((sum, acc) => sum + (acc.open_orders || 0), 0);

  // Calculate wallet balance from transactions
  const walletBalance = walletTransactions.reduce((sum, tx) => {
    if (tx.tx_type === 'in') return sum + tx.amount;
    if (tx.tx_type === 'out') return sum - tx.amount;
    return sum;
  }, 0);

  // Loading state
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  // Pending approval state
  if (isCustomer && customerInfo.status === 'pending') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto w-16 h-16 rounded-full bg-warning/20 flex items-center justify-center mb-4">
              <Clock className="w-8 h-8 text-warning" />
            </div>
            <CardTitle>รอการอนุมัติ</CardTitle>
            <CardDescription>
              บัญชีของคุณกำลังรอการอนุมัติจาก Admin<br />
              กรุณารอสักครู่ ระบบจะแจ้งเตือนเมื่อบัญชีถูกอนุมัติ
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Button onClick={handleSignOut} variant="outline">
              <LogOut className="w-4 h-4 mr-2" />
              ออกจากระบบ
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Access denied state
  if (!isCustomer) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto w-16 h-16 rounded-full bg-destructive/20 flex items-center justify-center mb-4">
              <XCircle className="w-8 h-8 text-destructive" />
            </div>
            <CardTitle>ไม่มีสิทธิ์เข้าถึง</CardTitle>
            <CardDescription>
              คุณไม่มีสิทธิ์เข้าถึงหน้านี้
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center gap-2">
            <Button onClick={() => navigate('/auth')} variant="outline">
              กลับไปหน้า Login
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
                <PieChart className="w-5 h-5 text-primary" />
              </div>
              <div>
                <h1 className="font-bold text-lg">Customer Dashboard</h1>
                <p className="text-xs text-muted-foreground">{customerData?.name || 'Loading...'}</p>
              </div>
            </div>
          </div>
          
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="icon" onClick={() => navigate('/customer/settings')}>
              <Settings className="w-4 h-4" />
            </Button>
            <Button variant="ghost" size="sm" onClick={handleSignOut}>
              <LogOut className="w-4 h-4 mr-2" />
              ออกจากระบบ
            </Button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8 space-y-8">
        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <RefreshCw className="w-8 h-8 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <>
            {/* Portfolio Overview */}
            <PortfolioSummary 
              walletBalance={walletBalance}
              totalMT5Balance={totalBalance}
              totalEquity={totalEquity}
              totalProfit={totalProfit}
              allocations={fundAllocations}
            />

            {/* Fund Allocation Chart */}
            {(fundAllocations.length > 0 || walletBalance > 0) && (
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <PieChart className="w-5 h-5" />
                    การกระจายเงินลงทุน
                  </CardTitle>
                  <CardDescription>
                    แสดงสัดส่วนเงินใน Wallet และระบบเทรดต่างๆ
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <FundPieChart 
                    walletBalance={walletBalance}
                    allocations={fundAllocations}
                  />
                </CardContent>
              </Card>
            )}

            {/* MT5 Accounts Section */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="w-5 h-5" />
                  MT5 Accounts
                </CardTitle>
                <CardDescription>
                  รายการบัญชี MT5 ของคุณ
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Tabs value={accountTypeFilter} onValueChange={(v) => setAccountTypeFilter(v as AccountTypeFilter)}>
                  <TabsList className="mb-4">
                    <TabsTrigger value="all">ทั้งหมด ({mt5Accounts.length})</TabsTrigger>
                    <TabsTrigger value="real">
                      Real ({mt5Accounts.filter(a => a.account_type === 'real').length})
                    </TabsTrigger>
                    <TabsTrigger value="demo">
                      Demo ({mt5Accounts.filter(a => a.account_type === 'demo' || a.account_type === 'contest').length})
                    </TabsTrigger>
                  </TabsList>

                  <TabsContent value={accountTypeFilter}>
                    {/* Summary Cards */}
                    <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
                      <Card className="bg-muted/50">
                        <CardContent className="pt-4">
                          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                            <DollarSign className="w-4 h-4" />
                            Balance
                          </div>
                          <p className="text-xl font-bold">${totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
                        </CardContent>
                      </Card>
                      <Card className="bg-muted/50">
                        <CardContent className="pt-4">
                          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                            <Wallet className="w-4 h-4" />
                            Equity
                          </div>
                          <p className="text-xl font-bold">${totalEquity.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
                        </CardContent>
                      </Card>
                      <Card className="bg-muted/50">
                        <CardContent className="pt-4">
                          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                            {totalProfit >= 0 ? <TrendingUp className="w-4 h-4 text-green-500" /> : <TrendingDown className="w-4 h-4 text-red-500" />}
                            Total Profit
                          </div>
                          <p className={`text-xl font-bold ${totalProfit >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                            ${totalProfit.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                          </p>
                        </CardContent>
                      </Card>
                      <Card className="bg-muted/50">
                        <CardContent className="pt-4">
                          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                            <Activity className="w-4 h-4" />
                            Floating P/L
                          </div>
                          <p className={`text-xl font-bold ${totalFloatingPL >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                            ${totalFloatingPL.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                          </p>
                        </CardContent>
                      </Card>
                      <Card className="bg-muted/50">
                        <CardContent className="pt-4">
                          <div className="flex items-center gap-2 text-muted-foreground text-sm mb-1">
                            <Percent className="w-4 h-4" />
                            Open Orders
                          </div>
                          <p className="text-xl font-bold">{totalOpenOrders}</p>
                        </CardContent>
                      </Card>
                    </div>

                    {/* Account List */}
                    <div className="space-y-4">
                      {filteredAccounts.length === 0 ? (
                        <div className="text-center py-8 text-muted-foreground">
                          <BarChart3 className="w-12 h-12 mx-auto mb-2 opacity-50" />
                          <p>ไม่พบบัญชี MT5</p>
                        </div>
                      ) : (
                        filteredAccounts.map((account) => (
                          <Card key={account.id} className="bg-muted/30">
                            <CardContent className="py-4">
                              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                                <div className="flex items-center gap-4">
                                  <div>
                                    <div className="flex items-center gap-2">
                                      <span className="font-mono font-bold">{account.account_number}</span>
                                      <Badge variant={account.account_type === 'real' ? 'default' : 'secondary'}>
                                        {account.account_type}
                                      </Badge>
                                      <Badge variant={account.status === 'active' ? 'outline' : 'destructive'}>
                                        {account.status}
                                      </Badge>
                                    </div>
                                    <p className="text-sm text-muted-foreground">
                                      Last sync: {account.last_sync ? new Date(account.last_sync).toLocaleString('th-TH') : 'Never'}
                                    </p>
                                  </div>
                                </div>
                                <div className="grid grid-cols-3 gap-4 text-right">
                                  <div>
                                    <p className="text-xs text-muted-foreground">Balance</p>
                                    <p className="font-mono font-bold">
                                      {account.currency === 'USC' ? '' : '$'}{account.balance?.toLocaleString('en-US', { minimumFractionDigits: 2 })} {account.currency === 'USC' ? 'USC' : ''}
                                    </p>
                                  </div>
                                  <div>
                                    <p className="text-xs text-muted-foreground">Equity</p>
                                    <p className="font-mono font-bold">
                                      {account.currency === 'USC' ? '' : '$'}{account.equity?.toLocaleString('en-US', { minimumFractionDigits: 2 })} {account.currency === 'USC' ? 'USC' : ''}
                                    </p>
                                  </div>
                                  <div>
                                    <p className="text-xs text-muted-foreground">Profit</p>
                                    <p className={`font-mono font-bold ${(account.total_profit || 0) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                                      {(account.total_profit || 0) >= 0 ? '+' : ''}{account.total_profit?.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                                    </p>
                                  </div>
                                </div>
                              </div>
                            </CardContent>
                          </Card>
                        ))
                      )}
                    </div>
                  </TabsContent>
                </Tabs>
              </CardContent>
            </Card>

            {/* Recent Transactions */}
            {walletTransactions.length > 0 && (
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Wallet className="w-5 h-5" />
                    Recent Wallet Transactions
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    {walletTransactions.slice(0, 10).map((tx) => (
                      <div key={tx.id} className="flex items-center justify-between py-2 border-b border-border last:border-0">
                        <div className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-full flex items-center justify-center ${tx.tx_type === 'in' ? 'bg-green-500/20' : 'bg-red-500/20'}`}>
                            {tx.tx_type === 'in' ? (
                              <TrendingUp className="w-4 h-4 text-green-500" />
                            ) : (
                              <TrendingDown className="w-4 h-4 text-red-500" />
                            )}
                          </div>
                          <div>
                            <p className="font-medium">
                              {tx.classification || (tx.tx_type === 'in' ? 'เงินเข้า' : 'เงินออก')}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {new Date(tx.block_time).toLocaleString('th-TH')}
                            </p>
                          </div>
                        </div>
                        <p className={`font-mono font-bold ${tx.tx_type === 'in' ? 'text-green-500' : 'text-red-500'}`}>
                          {tx.tx_type === 'in' ? '+' : '-'}{tx.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })} USDT
                        </p>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            )}
          </>
        )}
      </main>
    </div>
  );
};

export default Customer;
