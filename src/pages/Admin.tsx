import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import TotalAccountHistoryChart from '@/components/TotalAccountHistoryChart';
import { 
  Users, 
  CreditCard, 
  TrendingUp, 
  TrendingDown, 
  AlertTriangle,
  LogOut,
  Settings,
  UserPlus,
  BarChart3,
  Clock,
  CheckCircle,
  XCircle,
  RefreshCw
} from 'lucide-react';

interface DashboardStats {
  totalCustomers: number;
  activeAccounts: number;
  expiringAccounts: number;
  expiredAccounts: number;
  totalBalance: number;
  totalEquity: number;
  totalProfitLoss: number;
}

interface ExpiringAccount {
  id: string;
  account_number: string;
  expiry_date: string;
  customer_name: string;
  days_remaining: number;
}

type AccountTypeFilter = 'all' | 'real' | 'demo';

interface MT5AccountData {
  id: string;
  account_number: string;
  status: string;
  expiry_date: string | null;
  balance: number;
  equity: number;
  profit_loss: number;
  is_lifetime: boolean;
  account_type: string | null;
  customer: { name: string } | null;
}

const Admin = () => {
  const navigate = useNavigate();
  const { user, loading, signOut, isAdmin, isSuperAdmin, role } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [expiringAccounts, setExpiringAccounts] = useState<ExpiringAccount[]>([]);
  const [isLoadingStats, setIsLoadingStats] = useState(true);
  const [accountTypeFilter, setAccountTypeFilter] = useState<AccountTypeFilter>('all');
  const [allAccounts, setAllAccounts] = useState<MT5AccountData[]>([]);

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isAdmin) {
      fetchDashboardData();
    }
  }, [user, isAdmin]);

  const fetchDashboardData = async () => {
    setIsLoadingStats(true);
    try {
      // Fetch customers count
      const { count: customerCount } = await supabase
        .from('customers')
        .select('*', { count: 'exact', head: true });

      // Fetch MT5 accounts with status counts
      const { data: accounts } = await supabase
        .from('mt5_accounts')
        .select(`
          id,
          account_number,
          status,
          expiry_date,
          balance,
          equity,
          profit_loss,
          is_lifetime,
          account_type,
          customer:customers(name)
        `);

      // Store all accounts for filtering
      setAllAccounts((accounts || []) as MT5AccountData[]);

      const activeCount = accounts?.filter(a => a.status === 'active').length || 0;
      const expiringCount = accounts?.filter(a => a.status === 'expiring_soon').length || 0;
      const expiredCount = accounts?.filter(a => a.status === 'expired').length || 0;
      
      const totalBalance = accounts?.reduce((sum, a) => sum + Number(a.balance || 0), 0) || 0;
      const totalEquity = accounts?.reduce((sum, a) => sum + Number(a.equity || 0), 0) || 0;
      const totalPL = accounts?.reduce((sum, a) => sum + Number(a.profit_loss || 0), 0) || 0;

      setStats({
        totalCustomers: customerCount || 0,
        activeAccounts: activeCount,
        expiringAccounts: expiringCount,
        expiredAccounts: expiredCount,
        totalBalance,
        totalEquity,
        totalProfitLoss: totalPL,
      });

      // Find accounts expiring within 5 days
      const now = new Date();
      const fiveDaysLater = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);
      
      const expiring = accounts
        ?.filter(a => {
          if (a.is_lifetime) return false;
          if (!a.expiry_date) return false;
          const expDate = new Date(a.expiry_date);
          return expDate > now && expDate <= fiveDaysLater;
        })
        .map(a => ({
          id: a.id,
          account_number: a.account_number,
          expiry_date: a.expiry_date!,
          customer_name: (a.customer as any)?.name || 'Unknown',
          days_remaining: Math.ceil((new Date(a.expiry_date!).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)),
        }))
        .sort((a, b) => a.days_remaining - b.days_remaining) || [];

      setExpiringAccounts(expiring);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setIsLoadingStats(false);
    }
  };

  const handleSignOut = async () => {
    await signOut();
    navigate('/auth');
  };

  // Calculate filtered stats based on account type filter
  const getFilteredStats = () => {
    const filtered = accountTypeFilter === 'all' 
      ? allAccounts 
      : allAccounts.filter(a => a.account_type === accountTypeFilter);
    
    return {
      activeAccounts: filtered.filter(a => a.status === 'active').length,
      expiringAccounts: filtered.filter(a => a.status === 'expiring_soon').length,
      expiredAccounts: filtered.filter(a => a.status === 'expired').length,
      totalBalance: filtered.reduce((sum, a) => sum + Number(a.balance || 0), 0),
      totalEquity: filtered.reduce((sum, a) => sum + Number(a.equity || 0), 0),
      totalProfitLoss: filtered.reduce((sum, a) => sum + Number(a.profit_loss || 0), 0),
    };
  };

  const filteredStats = getFilteredStats();
  
  // Get filtered account IDs for chart
  const getFilteredAccountIds = () => {
    if (accountTypeFilter === 'all') return undefined;
    return allAccounts
      .filter(a => a.account_type === accountTypeFilter)
      .map(a => a.id);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto w-16 h-16 rounded-full bg-destructive/20 flex items-center justify-center mb-4">
              <XCircle className="w-8 h-8 text-destructive" />
            </div>
            <CardTitle>ไม่มีสิทธิ์เข้าถึง</CardTitle>
            <CardDescription>
              คุณไม่มีสิทธิ์เข้าถึงหน้านี้ กรุณาติดต่อ Admin
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

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
              <BarChart3 className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h1 className="font-bold text-lg">Moneyx Admin</h1>
              <p className="text-xs text-muted-foreground">ระบบจัดการลูกค้า</p>
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            <Badge variant={isSuperAdmin ? "default" : "secondary"} className="gap-1">
              {isSuperAdmin ? "Super Admin" : "Admin"}
            </Badge>
            <span className="text-sm text-muted-foreground hidden md:block">
              {user?.email}
            </span>
            <Button variant="ghost" size="icon" onClick={handleSignOut}>
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        {/* Account Type Filter Tabs */}
        <div className="mb-6">
          <Tabs value={accountTypeFilter} onValueChange={(v) => setAccountTypeFilter(v as AccountTypeFilter)}>
            <TabsList className="grid w-full max-w-md grid-cols-3">
              <TabsTrigger value="all" className="gap-2">
                ทั้งหมด
                <Badge variant="secondary" className="ml-1 h-5 px-1.5 text-xs">
                  {allAccounts.length}
                </Badge>
              </TabsTrigger>
              <TabsTrigger value="real" className="gap-2">
                🟢 Real
                <Badge variant="secondary" className="ml-1 h-5 px-1.5 text-xs">
                  {allAccounts.filter(a => a.account_type === 'real' || !a.account_type).length}
                </Badge>
              </TabsTrigger>
              <TabsTrigger value="demo" className="gap-2">
                🔵 Demo
                <Badge variant="secondary" className="ml-1 h-5 px-1.5 text-xs">
                  {allAccounts.filter(a => a.account_type === 'demo').length}
                </Badge>
              </TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card 
            className="cursor-pointer hover:border-primary/50 transition-colors"
            onClick={() => navigate('/admin/customers')}
          >
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ลูกค้าทั้งหมด
              </CardTitle>
              <Users className="w-4 h-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-bold">{stats?.totalCustomers || 0}</div>
              )}
            </CardContent>
          </Card>

          <Card 
            className="cursor-pointer hover:border-primary/50 transition-colors"
            onClick={() => navigate('/admin/accounts')}
          >
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                MT5 Accounts (Active)
              </CardTitle>
              <CheckCircle className="w-4 h-4 text-green-500" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-bold text-green-500">{filteredStats.activeAccounts}</div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                กำลังจะหมดอายุ
              </CardTitle>
              <Clock className="w-4 h-4 text-yellow-500" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-bold text-yellow-500">{filteredStats.expiringAccounts}</div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                หมดอายุแล้ว
              </CardTitle>
              <XCircle className="w-4 h-4 text-red-500" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-bold text-red-500">{filteredStats.expiredAccounts}</div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Financial Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ยอด Balance รวม
              </CardTitle>
              <CreditCard className="w-4 h-4 text-primary" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className="text-2xl font-bold">
                  ${filteredStats.totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ยอด Equity รวม
              </CardTitle>
              <TrendingUp className="w-4 h-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className="text-2xl font-bold text-blue-500">
                  ${filteredStats.totalEquity.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                กำไร/ขาดทุน รวม
              </CardTitle>
              {filteredStats.totalProfitLoss >= 0 ? (
                <TrendingUp className="w-4 h-4 text-green-500" />
              ) : (
                <TrendingDown className="w-4 h-4 text-red-500" />
              )}
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className={`text-2xl font-bold ${filteredStats.totalProfitLoss >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                  {filteredStats.totalProfitLoss >= 0 ? '+' : ''}
                  ${filteredStats.totalProfitLoss.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Total Account History Chart */}
        <TotalAccountHistoryChart accountIds={getFilteredAccountIds()} />

        {/* Quick Actions & Expiring Alerts */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Quick Actions */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Settings className="w-5 h-5" />
                การดำเนินการด่วน
              </CardTitle>
              <CardDescription>จัดการลูกค้าและ MT5 Accounts</CardDescription>
            </CardHeader>
            <CardContent className="grid grid-cols-2 gap-4">
              <Button 
                variant="outline" 
                className="h-24 flex flex-col gap-2"
                onClick={() => navigate('/admin/customers')}
              >
                <Users className="w-6 h-6" />
                <span>จัดการลูกค้า</span>
              </Button>
              <Button 
                variant="outline" 
                className="h-24 flex flex-col gap-2"
                onClick={() => navigate('/admin/customers/new')}
              >
                <UserPlus className="w-6 h-6" />
                <span>เพิ่มลูกค้าใหม่</span>
              </Button>
              <Button 
                variant="outline" 
                className="h-24 flex flex-col gap-2"
                onClick={() => navigate('/admin/accounts')}
              >
                <CreditCard className="w-6 h-6" />
                <span>MT5 Accounts</span>
              </Button>
              <Button 
                variant="outline" 
                className="h-24 flex flex-col gap-2"
                onClick={() => navigate('/admin/systems')}
              >
                <BarChart3 className="w-6 h-6" />
                <span>ระบบเทรด</span>
              </Button>
              {isSuperAdmin && (
                <Button 
                  variant="outline" 
                  className="h-24 flex flex-col gap-2 col-span-2 border-yellow-500/30 hover:border-yellow-500"
                  onClick={() => navigate('/admin/users')}
                >
                  <Settings className="w-6 h-6 text-yellow-500" />
                  <span>จัดการผู้ใช้ / Role</span>
                </Button>
              )}
            </CardContent>
          </Card>

          {/* Expiring Accounts Alert */}
          <Card className={expiringAccounts.length > 0 ? 'border-yellow-500/50' : ''}>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <AlertTriangle className={`w-5 h-5 ${expiringAccounts.length > 0 ? 'text-yellow-500' : 'text-muted-foreground'}`} />
                แจ้งเตือนหมดอายุ
              </CardTitle>
              <CardDescription>Accounts ที่จะหมดอายุภายใน 5 วัน</CardDescription>
            </CardHeader>
            <CardContent>
              {isLoadingStats ? (
                <div className="space-y-2">
                  <Skeleton className="h-12 w-full" />
                  <Skeleton className="h-12 w-full" />
                </div>
              ) : expiringAccounts.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <CheckCircle className="w-12 h-12 mx-auto mb-2 text-green-500/50" />
                  <p>ไม่มี Account ที่จะหมดอายุ</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {expiringAccounts.slice(0, 5).map((account) => (
                    <div
                      key={account.id}
                      className="flex items-center justify-between p-3 rounded-lg bg-yellow-500/10 border border-yellow-500/30"
                    >
                      <div>
                        <p className="font-medium">{account.account_number}</p>
                        <p className="text-sm text-muted-foreground">{account.customer_name}</p>
                      </div>
                      <Badge variant="outline" className="text-yellow-600 border-yellow-500">
                        {account.days_remaining} วัน
                      </Badge>
                    </div>
                  ))}
                  {expiringAccounts.length > 5 && (
                    <p className="text-sm text-muted-foreground text-center pt-2">
                      และอีก {expiringAccounts.length - 5} accounts...
                    </p>
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
};

export default Admin;
