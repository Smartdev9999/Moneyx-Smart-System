import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { useToast } from '@/hooks/use-toast';
import { 
  ArrowLeft, 
  User,
  Mail,
  Phone,
  Building,
  CreditCard,
  Plus,
  Clock,
  CheckCircle,
  XCircle,
  Infinity,
  Loader2,
  Calendar,
  TrendingUp,
  TrendingDown
} from 'lucide-react';

interface Customer {
  id: string;
  customer_id: string;
  name: string;
  email: string;
  phone: string | null;
  broker: string | null;
  notes: string | null;
  status: string;
  created_at: string;
}

interface MT5Account {
  id: string;
  account_number: string;
  package_type: string;
  start_date: string;
  expiry_date: string | null;
  is_lifetime: boolean;
  status: string;
  balance: number;
  equity: number;
  profit_loss: number;
  trading_system: { name: string } | null;
  days_remaining: number | null;
}

interface TradingSystem {
  id: string;
  name: string;
}

const CustomerDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const { toast } = useToast();
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [accounts, setAccounts] = useState<MT5Account[]>([]);
  const [tradingSystems, setTradingSystems] = useState<TradingSystem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isAddingAccount, setIsAddingAccount] = useState(false);
  const [showAddDialog, setShowAddDialog] = useState(false);
  
  // New account form
  const [newAccount, setNewAccount] = useState({
    account_number: '',
    package_type: '1month',
    trading_system_id: '',
  });

  useEffect(() => {
    if (id && isAdmin) {
      fetchCustomerData();
      fetchTradingSystems();
    }
  }, [id, isAdmin]);

  const fetchCustomerData = async () => {
    setIsLoading(true);
    try {
      // Fetch customer
      const { data: customerData, error: customerError } = await supabase
        .from('customers')
        .select('*')
        .eq('id', id)
        .single();

      if (customerError) throw customerError;
      setCustomer(customerData);

      // Fetch MT5 accounts
      const { data: accountsData, error: accountsError } = await supabase
        .from('mt5_accounts')
        .select(`
          *,
          trading_system:trading_systems(name)
        `)
        .eq('customer_id', id)
        .order('created_at', { ascending: false });

      if (accountsError) throw accountsError;

      const now = new Date();
      const processedAccounts = accountsData?.map(a => ({
        ...a,
        days_remaining: a.is_lifetime ? null : 
          a.expiry_date ? Math.ceil((new Date(a.expiry_date).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)) : null,
      })) || [];

      setAccounts(processedAccounts);
    } catch (error) {
      console.error('Error fetching customer:', error);
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: "ไม่พบข้อมูลลูกค้า",
      });
      navigate('/admin/customers');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchTradingSystems = async () => {
    const { data } = await supabase
      .from('trading_systems')
      .select('id, name')
      .eq('is_active', true);
    
    setTradingSystems(data || []);
  };

  const calculateExpiryDate = (packageType: string): string => {
    const now = new Date();
    switch (packageType) {
      case '1month':
        now.setMonth(now.getMonth() + 1);
        break;
      case '3months':
        now.setMonth(now.getMonth() + 3);
        break;
      case '6months':
        now.setMonth(now.getMonth() + 6);
        break;
      case '1year':
        now.setFullYear(now.getFullYear() + 1);
        break;
      default:
        break;
    }
    return now.toISOString();
  };

  const handleAddAccount = async () => {
    if (!newAccount.account_number || !newAccount.trading_system_id) {
      toast({
        variant: "destructive",
        title: "ข้อมูลไม่ครบ",
        description: "กรุณากรอกเลข MT5 และเลือกระบบเทรด",
      });
      return;
    }

    setIsAddingAccount(true);
    try {
      const isLifetime = newAccount.package_type === 'lifetime';
      const expiryDate = isLifetime ? null : calculateExpiryDate(newAccount.package_type);

      const { error } = await supabase
        .from('mt5_accounts')
        .insert({
          customer_id: id,
          account_number: newAccount.account_number,
          package_type: newAccount.package_type,
          trading_system_id: newAccount.trading_system_id,
          is_lifetime: isLifetime,
          expiry_date: expiryDate,
          status: 'active',
        });

      if (error) {
        if (error.code === '23505') {
          throw new Error('เลข MT5 นี้มีอยู่ในระบบแล้ว');
        }
        throw error;
      }

      toast({
        title: "เพิ่ม MT5 Account สำเร็จ",
        description: `Account ${newAccount.account_number} ถูกเพิ่มแล้ว`,
      });

      setShowAddDialog(false);
      setNewAccount({ account_number: '', package_type: '1month', trading_system_id: '' });
      fetchCustomerData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message || "ไม่สามารถเพิ่ม Account ได้",
      });
    } finally {
      setIsAddingAccount(false);
    }
  };

  const getPackageLabel = (type: string) => {
    switch (type) {
      case '1month': return '1 เดือน';
      case '3months': return '3 เดือน';
      case '6months': return '6 เดือน';
      case '1year': return '1 ปี';
      case 'lifetime': return 'Lifetime';
      default: return type;
    }
  };

  const getStatusBadge = (account: MT5Account) => {
    if (account.is_lifetime) {
      return <Badge className="bg-purple-500/20 text-purple-400 border-purple-500/50"><Infinity className="w-3 h-3 mr-1" /> Lifetime</Badge>;
    }
    if (account.status === 'active' && account.days_remaining && account.days_remaining <= 5) {
      return <Badge variant="outline" className="text-yellow-600 border-yellow-500"><Clock className="w-3 h-3 mr-1" /> {account.days_remaining} วัน</Badge>;
    }
    if (account.status === 'active') {
      return <Badge variant="outline" className="text-green-600 border-green-500"><CheckCircle className="w-3 h-3 mr-1" /> Active</Badge>;
    }
    if (account.status === 'expired') {
      return <Badge variant="outline" className="text-red-600 border-red-500"><XCircle className="w-3 h-3 mr-1" /> หมดอายุ</Badge>;
    }
    return <Badge variant="outline">{account.status}</Badge>;
  };

  const totalBalance = accounts.reduce((sum, a) => sum + Number(a.balance || 0), 0);
  const totalEquity = accounts.reduce((sum, a) => sum + Number(a.equity || 0), 0);
  const totalPL = accounts.reduce((sum, a) => sum + Number(a.profit_loss || 0), 0);

  if (!isAdmin) {
    return null;
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background">
        <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
          <div className="container flex items-center gap-4 h-16">
            <Skeleton className="h-8 w-8" />
            <Skeleton className="h-6 w-48" />
          </div>
        </header>
        <main className="container py-8">
          <Skeleton className="h-48 w-full mb-6" />
          <Skeleton className="h-96 w-full" />
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center gap-4 h-16">
          <Button variant="ghost" size="icon" onClick={() => navigate('/admin/customers')}>
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
              <User className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h1 className="font-bold text-lg">{customer?.name}</h1>
              <p className="text-xs text-muted-foreground font-mono">{customer?.customer_id}</p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        {/* Customer Info */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <Card className="lg:col-span-2">
            <CardHeader>
              <CardTitle>ข้อมูลลูกค้า</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="flex items-center gap-3">
                <Mail className="w-4 h-4 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">อีเมล</p>
                  <p>{customer?.email}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <Phone className="w-4 h-4 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">เบอร์โทร</p>
                  <p>{customer?.phone || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <Building className="w-4 h-4 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">โบรกเกอร์</p>
                  <p>{customer?.broker || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <Calendar className="w-4 h-4 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">วันที่ลงทะเบียน</p>
                  <p>{customer?.created_at ? new Date(customer.created_at).toLocaleDateString('th-TH') : '-'}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>สรุปยอด</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">MT5 Accounts</span>
                <span className="font-bold">{accounts.length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Balance รวม</span>
                <span className="font-bold">${totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Equity รวม</span>
                <span className="font-bold text-blue-500">${totalEquity.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">กำไร/ขาดทุน</span>
                <span className={`font-bold flex items-center gap-1 ${totalPL >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                  {totalPL >= 0 ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                  {totalPL >= 0 ? '+' : ''}${totalPL.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* MT5 Accounts */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle className="flex items-center gap-2">
                <CreditCard className="w-5 h-5" />
                MT5 Accounts
              </CardTitle>
              <CardDescription>รายการ MT5 Account ทั้งหมดของลูกค้า</CardDescription>
            </div>
            <Dialog open={showAddDialog} onOpenChange={setShowAddDialog}>
              <DialogTrigger asChild>
                <Button>
                  <Plus className="w-4 h-4 mr-2" />
                  เพิ่ม Account
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>เพิ่ม MT5 Account</DialogTitle>
                  <DialogDescription>
                    เพิ่ม MT5 Account ใหม่สำหรับลูกค้า {customer?.name}
                  </DialogDescription>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  <div className="space-y-2">
                    <Label>เลข MT5 Account *</Label>
                    <Input
                      placeholder="12345678"
                      value={newAccount.account_number}
                      onChange={(e) => setNewAccount(prev => ({ ...prev, account_number: e.target.value }))}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>ระบบเทรด *</Label>
                    <Select
                      value={newAccount.trading_system_id}
                      onValueChange={(value) => setNewAccount(prev => ({ ...prev, trading_system_id: value }))}
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="เลือกระบบเทรด" />
                      </SelectTrigger>
                      <SelectContent>
                        {tradingSystems.map((sys) => (
                          <SelectItem key={sys.id} value={sys.id}>{sys.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label>แพ็คเกจ *</Label>
                    <Select
                      value={newAccount.package_type}
                      onValueChange={(value) => setNewAccount(prev => ({ ...prev, package_type: value }))}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="1month">1 เดือน</SelectItem>
                        <SelectItem value="3months">3 เดือน</SelectItem>
                        <SelectItem value="6months">6 เดือน</SelectItem>
                        <SelectItem value="1year">1 ปี</SelectItem>
                        <SelectItem value="lifetime">Lifetime (ตลอดชีพ)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setShowAddDialog(false)}>ยกเลิก</Button>
                  <Button onClick={handleAddAccount} disabled={isAddingAccount}>
                    {isAddingAccount ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        กำลังบันทึก...
                      </>
                    ) : (
                      'เพิ่ม Account'
                    )}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </CardHeader>
          <CardContent>
            {accounts.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                <CreditCard className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <p className="text-lg font-medium">ยังไม่มี MT5 Account</p>
                <p className="text-sm">คลิก "เพิ่ม Account" เพื่อเริ่มต้น</p>
              </div>
            ) : (
              <div className="grid gap-4">
                {accounts.map((account) => (
                  <div
                    key={account.id}
                    className="flex flex-col md:flex-row md:items-center justify-between p-4 rounded-xl border border-border bg-card/50 hover:bg-card transition-colors"
                  >
                    <div className="flex items-center gap-4 mb-4 md:mb-0">
                      <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                        <CreditCard className="w-6 h-6 text-primary" />
                      </div>
                      <div>
                        <p className="font-bold font-mono text-lg">{account.account_number}</p>
                        <p className="text-sm text-muted-foreground">
                          {account.trading_system?.name || 'ไม่ระบุระบบ'} • {getPackageLabel(account.package_type)}
                        </p>
                      </div>
                    </div>
                    
                    <div className="flex flex-wrap items-center gap-4">
                      <div className="text-right">
                        <p className="text-sm text-muted-foreground">Balance</p>
                        <p className="font-medium">${Number(account.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm text-muted-foreground">P/L</p>
                        <p className={`font-medium ${Number(account.profit_loss) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                          {Number(account.profit_loss) >= 0 ? '+' : ''}${Number(account.profit_loss).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </p>
                      </div>
                      {getStatusBadge(account)}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </main>
    </div>
  );
};

export default CustomerDetail;
