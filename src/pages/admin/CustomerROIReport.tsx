import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
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
  TableRow 
} from '@/components/ui/table';
import { 
  ArrowLeft, 
  TrendingUp, 
  TrendingDown, 
  Users, 
  DollarSign,
  Percent,
  Award,
  RefreshCw,
  ChevronUp,
  ChevronDown,
  Minus
} from 'lucide-react';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  Cell 
} from 'recharts';

interface CustomerROI {
  id: string;
  customer_id: string;
  name: string;
  email: string;
  totalInvested: number;
  currentValue: number;
  totalProfit: number;
  roiPercent: number;
  accountCount: number;
  status: string;
}

const CustomerROIReport = () => {
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const [customers, setCustomers] = useState<CustomerROI[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [sortField, setSortField] = useState<'roiPercent' | 'totalProfit' | 'totalInvested'>('roiPercent');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');

  useEffect(() => {
    if (isAdmin) {
      fetchCustomerROI();
    }
  }, [isAdmin]);

  const fetchCustomerROI = async () => {
    setIsLoading(true);
    try {
      // Fetch customers with their MT5 accounts
      const { data: customersData, error: customersError } = await supabase
        .from('customers')
        .select(`
          id,
          customer_id,
          name,
          email,
          status,
          mt5_accounts (
            id,
            balance,
            equity,
            initial_balance,
            total_profit,
            total_deposit,
            total_withdrawal,
            account_type
          )
        `);

      if (customersError) throw customersError;

      // Also fetch fund allocations
      const { data: allocationsData } = await supabase
        .from('fund_allocations')
        .select('customer_id, allocated_amount, current_value, profit_loss, roi_percent');

      // Calculate ROI for each customer
      const customerROIs: CustomerROI[] = (customersData || []).map(customer => {
        const accounts = customer.mt5_accounts || [];
        const allocations = (allocationsData || []).filter(a => a.customer_id === customer.id);
        
        // Calculate from MT5 accounts (Real accounts only for accurate ROI)
        const realAccounts = accounts.filter((a: any) => a.account_type === 'real' || !a.account_type);
        
        const totalDeposit = realAccounts.reduce((sum: number, a: any) => sum + Number(a.total_deposit || a.initial_balance || 0), 0);
        const totalBalance = realAccounts.reduce((sum: number, a: any) => sum + Number(a.balance || 0), 0);
        const totalProfit = realAccounts.reduce((sum: number, a: any) => sum + Number(a.total_profit || 0), 0);
        
        // Also consider fund allocations
        const allocatedAmount = allocations.reduce((sum, a) => sum + Number(a.allocated_amount || 0), 0);
        const allocationValue = allocations.reduce((sum, a) => sum + Number(a.current_value || 0), 0);
        
        const totalInvested = totalDeposit + allocatedAmount;
        const currentValue = totalBalance + allocationValue;
        
        // Calculate ROI
        const roiPercent = totalInvested > 0 
          ? ((currentValue - totalInvested) / totalInvested) * 100 
          : 0;

        return {
          id: customer.id,
          customer_id: customer.customer_id,
          name: customer.name,
          email: customer.email,
          totalInvested,
          currentValue,
          totalProfit,
          roiPercent,
          accountCount: accounts.length,
          status: customer.status,
        };
      });

      setCustomers(customerROIs);
    } catch (error) {
      console.error('Error fetching customer ROI:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSort = (field: typeof sortField) => {
    if (sortField === field) {
      setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('desc');
    }
  };

  const sortedCustomers = [...customers].sort((a, b) => {
    const multiplier = sortDirection === 'asc' ? 1 : -1;
    return (a[sortField] - b[sortField]) * multiplier;
  });

  // Summary stats
  const totalCustomers = customers.length;
  const profitableCustomers = customers.filter(c => c.roiPercent > 0).length;
  const avgROI = customers.length > 0 
    ? customers.reduce((sum, c) => sum + c.roiPercent, 0) / customers.length 
    : 0;
  const totalAUM = customers.reduce((sum, c) => sum + c.currentValue, 0);

  // Top performers for chart
  const topPerformers = [...customers]
    .sort((a, b) => b.roiPercent - a.roiPercent)
    .slice(0, 10);

  const SortIcon = ({ field }: { field: typeof sortField }) => {
    if (sortField !== field) return <Minus className="w-3 h-3 opacity-30" />;
    return sortDirection === 'desc' 
      ? <ChevronDown className="w-3 h-3" /> 
      : <ChevronUp className="w-3 h-3" />;
  };

  if (!isAdmin) {
    navigate('/admin');
    return null;
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
              <ArrowLeft className="w-4 h-4" />
            </Button>
            <div>
              <h1 className="font-bold text-lg">Customer ROI Report</h1>
              <p className="text-xs text-muted-foreground">สรุปผลตอบแทนรายลูกค้า</p>
            </div>
          </div>
          <Button variant="outline" size="sm" onClick={fetchCustomerROI} disabled={isLoading}>
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
            รีเฟรช
          </Button>
        </div>
      </header>

      <main className="container py-8 space-y-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ลูกค้าทั้งหมด
              </CardTitle>
              <Users className="w-4 h-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-bold">{totalCustomers}</div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ลูกค้าที่กำไร
              </CardTitle>
              <TrendingUp className="w-4 h-4 text-green-500" />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="flex items-baseline gap-2">
                  <span className="text-2xl font-bold text-green-500">{profitableCustomers}</span>
                  <span className="text-sm text-muted-foreground">
                    ({totalCustomers > 0 ? ((profitableCustomers / totalCustomers) * 100).toFixed(0) : 0}%)
                  </span>
                </div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                ROI เฉลี่ย
              </CardTitle>
              <Percent className="w-4 h-4 text-primary" />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className={`text-2xl font-bold ${avgROI >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                  {avgROI >= 0 ? '+' : ''}{avgROI.toFixed(2)}%
                </div>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                AUM รวม
              </CardTitle>
              <DollarSign className="w-4 h-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className="text-2xl font-bold text-blue-500">
                  ${totalAUM.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Top Performers Chart */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Award className="w-5 h-5 text-yellow-500" />
              Top 10 ผลตอบแทนสูงสุด
            </CardTitle>
            <CardDescription>ลูกค้าที่มี ROI สูงสุด</CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-[300px] w-full" />
            ) : topPerformers.length === 0 ? (
              <div className="h-[300px] flex items-center justify-center text-muted-foreground">
                ไม่มีข้อมูล
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={topPerformers} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                  <XAxis type="number" tickFormatter={(v) => `${v.toFixed(0)}%`} />
                  <YAxis 
                    dataKey="name" 
                    type="category" 
                    width={120}
                    tick={{ fontSize: 12 }}
                  />
                  <Tooltip 
                    formatter={(value: number) => [`${value.toFixed(2)}%`, 'ROI']}
                    contentStyle={{ 
                      backgroundColor: 'hsl(var(--card))', 
                      border: '1px solid hsl(var(--border))',
                      borderRadius: '8px'
                    }}
                  />
                  <Bar dataKey="roiPercent" radius={[0, 4, 4, 0]}>
                    {topPerformers.map((entry, index) => (
                      <Cell 
                        key={`cell-${index}`} 
                        fill={entry.roiPercent >= 0 ? 'hsl(var(--chart-2))' : 'hsl(var(--destructive))'} 
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        {/* Customer Table */}
        <Card>
          <CardHeader>
            <CardTitle>รายละเอียดลูกค้าทั้งหมด</CardTitle>
            <CardDescription>คลิกที่หัวตารางเพื่อเรียงลำดับ</CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="space-y-2">
                {[...Array(5)].map((_, i) => (
                  <Skeleton key={i} className="h-12 w-full" />
                ))}
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[60px]">อันดับ</TableHead>
                    <TableHead>ลูกค้า</TableHead>
                    <TableHead>Accounts</TableHead>
                    <TableHead 
                      className="cursor-pointer hover:text-foreground"
                      onClick={() => handleSort('totalInvested')}
                    >
                      <div className="flex items-center gap-1">
                        เงินลงทุน <SortIcon field="totalInvested" />
                      </div>
                    </TableHead>
                    <TableHead>มูลค่าปัจจุบัน</TableHead>
                    <TableHead 
                      className="cursor-pointer hover:text-foreground"
                      onClick={() => handleSort('totalProfit')}
                    >
                      <div className="flex items-center gap-1">
                        กำไรสุทธิ <SortIcon field="totalProfit" />
                      </div>
                    </TableHead>
                    <TableHead 
                      className="cursor-pointer hover:text-foreground"
                      onClick={() => handleSort('roiPercent')}
                    >
                      <div className="flex items-center gap-1">
                        ROI <SortIcon field="roiPercent" />
                      </div>
                    </TableHead>
                    <TableHead>สถานะ</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {sortedCustomers.map((customer, index) => (
                    <TableRow 
                      key={customer.id}
                      className="cursor-pointer hover:bg-muted/50"
                      onClick={() => navigate(`/admin/customers/${customer.id}`)}
                    >
                      <TableCell>
                        <div className="flex items-center justify-center">
                          {index < 3 ? (
                            <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                              index === 0 ? 'bg-chart-4 text-chart-4-foreground' :
                              index === 1 ? 'bg-muted text-muted-foreground' :
                              'bg-chart-3 text-chart-3-foreground'
                            }`}>
                              {index + 1}
                            </div>
                          ) : (
                            <span className="text-muted-foreground">{index + 1}</span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="font-medium">{customer.name}</p>
                          <p className="text-xs text-muted-foreground">{customer.customer_id}</p>
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">{customer.accountCount}</Badge>
                      </TableCell>
                      <TableCell>
                        ${customer.totalInvested.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </TableCell>
                      <TableCell>
                        ${customer.currentValue.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </TableCell>
                      <TableCell>
                        <span className={customer.totalProfit >= 0 ? 'text-chart-2' : 'text-destructive'}>
                          {customer.totalProfit >= 0 ? '+' : ''}
                          ${customer.totalProfit.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </span>
                      </TableCell>
                      <TableCell>
                        <div className={`flex items-center gap-1 font-medium ${
                          customer.roiPercent >= 0 ? 'text-chart-2' : 'text-destructive'
                        }`}>
                          {customer.roiPercent >= 0 ? (
                            <TrendingUp className="w-4 h-4" />
                          ) : (
                            <TrendingDown className="w-4 h-4" />
                          )}
                          {customer.roiPercent >= 0 ? '+' : ''}{customer.roiPercent.toFixed(2)}%
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={customer.status === 'active' ? 'default' : 'secondary'}>
                          {customer.status}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </main>
    </div>
  );
};

export default CustomerROIReport;
