import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { 
  ArrowLeft, 
  TrendingUp, 
  TrendingDown, 
  DollarSign, 
  Users, 
  Wallet,
  RefreshCw,
  Calendar,
  BarChart3,
  PieChart
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart as RechartsPie, Pie, Cell, Legend } from 'recharts';

interface ReportData {
  totalDeposits: number;
  totalWithdrawals: number;
  totalProfit: number;
  totalDividends: number;
  customerCount: number;
  walletCount: number;
  transactionCount: number;
  monthlyData: { month: string; deposits: number; withdrawals: number; profit: number }[];
  classificationBreakdown: { name: string; value: number }[];
}

const COLORS = ['#10b981', '#ef4444', '#3b82f6', '#f59e0b', '#8b5cf6', '#ec4899'];

const FundReport = () => {
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const [isLoading, setIsLoading] = useState(true);
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear().toString());
  const [reportData, setReportData] = useState<ReportData>({
    totalDeposits: 0,
    totalWithdrawals: 0,
    totalProfit: 0,
    totalDividends: 0,
    customerCount: 0,
    walletCount: 0,
    transactionCount: 0,
    monthlyData: [],
    classificationBreakdown: [],
  });

  useEffect(() => {
    if (isAdmin) {
      fetchReportData();
    }
  }, [isAdmin, selectedYear]);

  const fetchReportData = async () => {
    setIsLoading(true);
    try {
      const yearStart = `${selectedYear}-01-01T00:00:00.000Z`;
      const yearEnd = `${selectedYear}-12-31T23:59:59.999Z`;

      // Fetch all transactions for the year
      const { data: transactions } = await supabase
        .from('wallet_transactions')
        .select('*')
        .gte('block_time', yearStart)
        .lte('block_time', yearEnd)
        .order('block_time', { ascending: true });

      // Fetch customer count
      const { count: customerCount } = await supabase
        .from('customers')
        .select('*', { count: 'exact', head: true });

      // Fetch wallet count
      const { count: walletCount } = await supabase
        .from('fund_wallets')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true);

      // Calculate totals and breakdown
      let totalDeposits = 0;
      let totalWithdrawals = 0;
      let totalProfit = 0;
      let totalDividends = 0;
      const classificationMap: Record<string, number> = {};
      const monthlyMap: Record<string, { deposits: number; withdrawals: number; profit: number }> = {};

      // Initialize months
      for (let i = 1; i <= 12; i++) {
        const monthKey = `${selectedYear}-${i.toString().padStart(2, '0')}`;
        monthlyMap[monthKey] = { deposits: 0, withdrawals: 0, profit: 0 };
      }

      (transactions || []).forEach((tx) => {
        const amount = Math.abs(tx.amount || 0);
        const monthKey = tx.block_time?.substring(0, 7);
        const classification = tx.classification || 'unclassified';

        // Aggregate by classification
        classificationMap[classification] = (classificationMap[classification] || 0) + amount;

        // Calculate totals based on classification
        if (classification === 'fund_deposit' || tx.tx_type === 'in') {
          totalDeposits += amount;
          if (monthlyMap[monthKey]) monthlyMap[monthKey].deposits += amount;
        }
        if (classification === 'fund_withdraw' || (tx.tx_type === 'out' && !['profit_transfer', 'invest_transfer', 'dividend'].includes(classification))) {
          totalWithdrawals += amount;
          if (monthlyMap[monthKey]) monthlyMap[monthKey].withdrawals += amount;
        }
        if (classification === 'profit_transfer') {
          totalProfit += amount;
          if (monthlyMap[monthKey]) monthlyMap[monthKey].profit += amount;
        }
        if (classification === 'dividend') {
          totalDividends += amount;
        }
      });

      // Convert maps to arrays
      const monthlyData = Object.entries(monthlyMap).map(([month, data]) => ({
        month: new Date(month + '-01').toLocaleDateString('th-TH', { month: 'short' }),
        ...data,
      }));

      const classificationBreakdown = Object.entries(classificationMap)
        .map(([name, value]) => ({
          name: getClassificationLabel(name),
          value,
        }))
        .filter((item) => item.value > 0)
        .sort((a, b) => b.value - a.value);

      setReportData({
        totalDeposits,
        totalWithdrawals,
        totalProfit,
        totalDividends,
        customerCount: customerCount || 0,
        walletCount: walletCount || 0,
        transactionCount: transactions?.length || 0,
        monthlyData,
        classificationBreakdown,
      });
    } catch (error) {
      console.error('Error fetching report data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const getClassificationLabel = (classification: string) => {
    const labels: Record<string, string> = {
      fund_deposit: 'ฝากเงิน',
      fund_withdraw: 'ถอนเงิน',
      profit_transfer: 'โอนกำไร',
      invest_transfer: 'โอนลงทุน',
      dividend: 'ปันผล',
      unclassified: 'ยังไม่จัดหมวด',
    };
    return labels[classification] || classification;
  };

  const years = Array.from({ length: 5 }, (_, i) => (new Date().getFullYear() - i).toString());

  if (!isAdmin) {
    return null;
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center gap-4">
            <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
              <ArrowLeft className="w-4 h-4" />
            </Button>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
                <BarChart3 className="w-5 h-5 text-primary" />
              </div>
              <div>
                <h1 className="font-bold text-lg">Fund Report</h1>
                <p className="text-xs text-muted-foreground">รายงานสรุปกองทุน</p>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Select value={selectedYear} onValueChange={setSelectedYear}>
              <SelectTrigger className="w-32">
                <Calendar className="w-4 h-4 mr-2" />
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {years.map((year) => (
                  <SelectItem key={year} value={year}>
                    {year}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button variant="outline" size="icon" onClick={fetchReportData} disabled={isLoading}>
              <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
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
            {/* Summary Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Card className="bg-green-500/10 border-green-500/30">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-muted-foreground">ฝากเงินรวม</p>
                      <p className="text-2xl font-bold text-green-500">
                        ${reportData.totalDeposits.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                    <TrendingUp className="w-8 h-8 text-green-500" />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-red-500/10 border-red-500/30">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-muted-foreground">ถอนเงินรวม</p>
                      <p className="text-2xl font-bold text-red-500">
                        ${reportData.totalWithdrawals.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                    <TrendingDown className="w-8 h-8 text-red-500" />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-blue-500/10 border-blue-500/30">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-muted-foreground">กำไรโอน</p>
                      <p className="text-2xl font-bold text-blue-500">
                        ${reportData.totalProfit.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                    <DollarSign className="w-8 h-8 text-blue-500" />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-purple-500/10 border-purple-500/30">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-muted-foreground">ปันผลรวม</p>
                      <p className="text-2xl font-bold text-purple-500">
                        ${reportData.totalDividends.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </p>
                    </div>
                    <Wallet className="w-8 h-8 text-purple-500" />
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Secondary Stats */}
            <div className="grid grid-cols-3 gap-4">
              <Card>
                <CardContent className="pt-6">
                  <div className="flex items-center gap-3">
                    <Users className="w-6 h-6 text-muted-foreground" />
                    <div>
                      <p className="text-sm text-muted-foreground">ลูกค้าทั้งหมด</p>
                      <p className="text-xl font-bold">{reportData.customerCount}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardContent className="pt-6">
                  <div className="flex items-center gap-3">
                    <Wallet className="w-6 h-6 text-muted-foreground" />
                    <div>
                      <p className="text-sm text-muted-foreground">Wallet ใช้งาน</p>
                      <p className="text-xl font-bold">{reportData.walletCount}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardContent className="pt-6">
                  <div className="flex items-center gap-3">
                    <BarChart3 className="w-6 h-6 text-muted-foreground" />
                    <div>
                      <p className="text-sm text-muted-foreground">ธุรกรรม {selectedYear}</p>
                      <p className="text-xl font-bold">{reportData.transactionCount}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Charts */}
            <Tabs defaultValue="monthly" className="space-y-4">
              <TabsList>
                <TabsTrigger value="monthly">รายเดือน</TabsTrigger>
                <TabsTrigger value="breakdown">แยกตามประเภท</TabsTrigger>
              </TabsList>

              <TabsContent value="monthly">
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <BarChart3 className="w-5 h-5" />
                      สรุปรายเดือน ปี {selectedYear}
                    </CardTitle>
                    <CardDescription>
                      แสดงยอดฝาก ถอน และกำไรรายเดือน
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="h-[400px]">
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={reportData.monthlyData}>
                          <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                          <XAxis dataKey="month" className="text-muted-foreground" />
                          <YAxis className="text-muted-foreground" />
                          <Tooltip
                            contentStyle={{
                              backgroundColor: 'hsl(var(--card))',
                              border: '1px solid hsl(var(--border))',
                              borderRadius: '8px',
                            }}
                            formatter={(value: number) => `$${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`}
                          />
                          <Legend />
                          <Bar dataKey="deposits" name="ฝากเงิน" fill="#10b981" radius={[4, 4, 0, 0]} />
                          <Bar dataKey="withdrawals" name="ถอนเงิน" fill="#ef4444" radius={[4, 4, 0, 0]} />
                          <Bar dataKey="profit" name="กำไร" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  </CardContent>
                </Card>
              </TabsContent>

              <TabsContent value="breakdown">
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <PieChart className="w-5 h-5" />
                      แยกตามประเภทธุรกรรม
                    </CardTitle>
                    <CardDescription>
                      สัดส่วนธุรกรรมแยกตามหมวดหมู่
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    {reportData.classificationBreakdown.length > 0 ? (
                      <div className="h-[400px]">
                        <ResponsiveContainer width="100%" height="100%">
                          <RechartsPie>
                            <Pie
                              data={reportData.classificationBreakdown}
                              cx="50%"
                              cy="50%"
                              labelLine={false}
                              outerRadius={150}
                              fill="#8884d8"
                              dataKey="value"
                              label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                            >
                              {reportData.classificationBreakdown.map((_, index) => (
                                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                              ))}
                            </Pie>
                            <Tooltip
                              formatter={(value: number) => `$${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`}
                            />
                            <Legend />
                          </RechartsPie>
                        </ResponsiveContainer>
                      </div>
                    ) : (
                      <div className="flex items-center justify-center h-[400px] text-muted-foreground">
                        <div className="text-center">
                          <PieChart className="w-12 h-12 mx-auto mb-2 opacity-50" />
                          <p>ไม่มีข้อมูลธุรกรรมในปีนี้</p>
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              </TabsContent>
            </Tabs>
          </>
        )}
      </main>
    </div>
  );
};

export default FundReport;
