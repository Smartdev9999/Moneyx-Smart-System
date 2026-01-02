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
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { useToast } from '@/hooks/use-toast';
import AccountHistoryChart from '@/components/AccountHistoryChart';
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
  TrendingDown,
  Edit,
  Pause,
  Play,
  CalendarPlus,
  Trash2,
  Activity,
  DollarSign
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
  open_orders: number;
  floating_pl: number;
  total_profit: number;
  last_sync: string | null;
  trading_system: { name: string; id: string } | null;
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
  
  // Edit dialog state
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [editingAccount, setEditingAccount] = useState<MT5Account | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [editForm, setEditForm] = useState({
    account_number: '',
    package_type: '',
    trading_system_id: '',
    expiry_date: '',
  });
  
  // Extend dialog state
  const [showExtendDialog, setShowExtendDialog] = useState(false);
  const [extendingAccount, setExtendingAccount] = useState<MT5Account | null>(null);
  const [isExtending, setIsExtending] = useState(false);
  const [extendPeriod, setExtendPeriod] = useState('1month');
  
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

      // Fetch MT5 accounts with new fields
      const { data: accountsData, error: accountsError } = await supabase
        .from('mt5_accounts')
        .select(`
          *,
          trading_system:trading_systems(id, name)
        `)
        .eq('customer_id', id)
        .order('created_at', { ascending: false });

      if (accountsError) throw accountsError;

      const now = new Date();
      const processedAccounts = accountsData?.map(a => ({
        ...a,
        open_orders: a.open_orders || 0,
        floating_pl: a.floating_pl || 0,
        total_profit: a.total_profit || 0,
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

  const calculateExpiryDate = (packageType: string, fromDate?: Date): string => {
    // Clone the date to avoid mutating the original
    const date = fromDate ? new Date(fromDate.getTime()) : new Date();
    switch (packageType) {
      case '1month':
        date.setMonth(date.getMonth() + 1);
        break;
      case '3months':
        date.setMonth(date.getMonth() + 3);
        break;
      case '6months':
        date.setMonth(date.getMonth() + 6);
        break;
      case '1year':
        date.setFullYear(date.getFullYear() + 1);
        break;
      default:
        break;
    }
    return date.toISOString();
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

  const handleEditAccount = (account: MT5Account) => {
    setEditingAccount(account);
    setEditForm({
      account_number: account.account_number,
      package_type: account.package_type,
      trading_system_id: account.trading_system?.id || '',
      expiry_date: account.expiry_date ? account.expiry_date.split('T')[0] : '',
    });
    setShowEditDialog(true);
  };

  const handleSaveEdit = async () => {
    if (!editingAccount) return;
    
    setIsEditing(true);
    try {
      const isLifetime = editForm.package_type === 'lifetime';
      
      const { error } = await supabase
        .from('mt5_accounts')
        .update({
          account_number: editForm.account_number,
          package_type: editForm.package_type,
          trading_system_id: editForm.trading_system_id || null,
          is_lifetime: isLifetime,
          expiry_date: isLifetime ? null : (editForm.expiry_date ? new Date(editForm.expiry_date).toISOString() : null),
        })
        .eq('id', editingAccount.id);

      if (error) throw error;

      toast({
        title: "บันทึกสำเร็จ",
        description: "อัพเดทข้อมูล Account เรียบร้อยแล้ว",
      });

      setShowEditDialog(false);
      setEditingAccount(null);
      fetchCustomerData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message || "ไม่สามารถบันทึกข้อมูลได้",
      });
    } finally {
      setIsEditing(false);
    }
  };

  const handleTogglePause = async (account: MT5Account) => {
    const newStatus = account.status === 'suspended' ? 'active' : 'suspended';
    
    try {
      const { error } = await supabase
        .from('mt5_accounts')
        .update({ status: newStatus })
        .eq('id', account.id);

      if (error) throw error;

      toast({
        title: newStatus === 'suspended' ? "หยุดชั่วคราว" : "เปิดใช้งาน",
        description: `Account ${account.account_number} ${newStatus === 'suspended' ? 'ถูกหยุดชั่วคราว' : 'เปิดใช้งานแล้ว'}`,
      });

      fetchCustomerData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    }
  };

  const handleExtendAccount = (account: MT5Account) => {
    setExtendingAccount(account);
    setExtendPeriod('1month');
    setShowExtendDialog(true);
  };

  const handleSaveExtend = async () => {
    if (!extendingAccount) return;
    
    setIsExtending(true);
    try {
      const isLifetime = extendPeriod === 'lifetime';
      let newExpiryDate: string | null = null;
      
      if (!isLifetime) {
        // Extend from current expiry date or now
        const baseDate = extendingAccount.expiry_date 
          ? new Date(extendingAccount.expiry_date) 
          : new Date();
        newExpiryDate = calculateExpiryDate(extendPeriod, baseDate);
      }

      const { error } = await supabase
        .from('mt5_accounts')
        .update({
          is_lifetime: isLifetime,
          expiry_date: newExpiryDate,
          package_type: extendPeriod,
          status: 'active', // Reactivate if expired
        })
        .eq('id', extendingAccount.id);

      if (error) throw error;

      toast({
        title: "ต่ออายุสำเร็จ",
        description: isLifetime 
          ? `Account ${extendingAccount.account_number} เป็น Lifetime แล้ว`
          : `Account ${extendingAccount.account_number} ต่ออายุเรียบร้อย`,
      });

      setShowExtendDialog(false);
      setExtendingAccount(null);
      fetchCustomerData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setIsExtending(false);
    }
  };

  const handleDeleteAccount = async (account: MT5Account) => {
    try {
      // CASCADE will delete account_history and account_summary automatically
      const { error } = await supabase
        .from('mt5_accounts')
        .delete()
        .eq('id', account.id);

      if (error) throw error;

      toast({
        title: "ลบ Account สำเร็จ",
        description: `Account ${account.account_number} และประวัติทั้งหมดถูกลบแล้ว`,
      });

      fetchCustomerData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
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
    if (account.status === 'suspended') {
      return <Badge variant="outline" className="text-yellow-600 border-yellow-500"><Pause className="w-3 h-3 mr-1" /> หยุดชั่วคราว</Badge>;
    }
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
  const totalFloatingPL = accounts.reduce((sum, a) => sum + Number(a.floating_pl || 0), 0);
  const totalOpenOrders = accounts.reduce((sum, a) => sum + Number(a.open_orders || 0), 0);

  const accountIds = accounts.map(a => a.id);

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
              <div className="border-t border-border pt-4">
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground flex items-center gap-1">
                    <Activity className="w-3 h-3" /> Open Orders
                  </span>
                  <span className="font-bold">{totalOpenOrders}</span>
                </div>
                <div className="flex justify-between items-center mt-2">
                  <span className="text-muted-foreground flex items-center gap-1">
                    <DollarSign className="w-3 h-3" /> Floating P/L
                  </span>
                  <span className={`font-bold ${totalFloatingPL >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                    {totalFloatingPL >= 0 ? '+' : ''}${totalFloatingPL.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* P/L Chart */}
        <AccountHistoryChart accountIds={accountIds} />

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
                    className="flex flex-col p-4 rounded-xl border border-border bg-card/50 hover:bg-card transition-colors"
                  >
                    <div className="flex flex-col md:flex-row md:items-center justify-between mb-4">
                      <div className="flex items-center gap-4 mb-4 md:mb-0">
                        <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                          <CreditCard className="w-6 h-6 text-primary" />
                        </div>
                        <div>
                          <p className="font-bold font-mono text-lg">{account.account_number}</p>
                          <p className="text-sm text-muted-foreground">
                            {account.trading_system?.name || 'ไม่ระบุระบบ'} • {getPackageLabel(account.package_type)}
                          </p>
                          {account.last_sync && (
                            <p className="text-xs text-muted-foreground">
                              Sync: {new Date(account.last_sync).toLocaleString('th-TH')}
                            </p>
                          )}
                        </div>
                      </div>
                      
                      <div className="flex flex-wrap items-center gap-3">
                        <div className="text-right">
                          <p className="text-xs text-muted-foreground">Balance</p>
                          <p className="font-medium">${Number(account.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
                        </div>
                        <div className="text-right">
                          <p className="text-xs text-muted-foreground">Floating P/L</p>
                          <p className={`font-medium ${Number(account.floating_pl) >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                            {Number(account.floating_pl) >= 0 ? '+' : ''}${Number(account.floating_pl).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="text-xs text-muted-foreground">Orders</p>
                          <p className="font-medium">{account.open_orders}</p>
                        </div>
                        {getStatusBadge(account)}
                      </div>
                    </div>
                    
                    {/* Action Buttons */}
                    <div className="flex flex-wrap gap-2 pt-3 border-t border-border">
                      <Button variant="outline" size="sm" onClick={() => handleEditAccount(account)}>
                        <Edit className="w-3 h-3 mr-1" /> แก้ไข
                      </Button>
                      <Button 
                        variant="outline" 
                        size="sm" 
                        onClick={() => handleTogglePause(account)}
                        className={account.status === 'suspended' ? 'text-green-600 border-green-600' : 'text-yellow-600 border-yellow-600'}
                      >
                        {account.status === 'suspended' ? (
                          <><Play className="w-3 h-3 mr-1" /> เปิดใช้งาน</>
                        ) : (
                          <><Pause className="w-3 h-3 mr-1" /> หยุดชั่วคราว</>
                        )}
                      </Button>
                      <Button variant="outline" size="sm" onClick={() => handleExtendAccount(account)}>
                        <CalendarPlus className="w-3 h-3 mr-1" /> ต่ออายุ
                      </Button>
                      <AlertDialog>
                        <AlertDialogTrigger asChild>
                          <Button variant="outline" size="sm" className="text-red-600 border-red-600 hover:bg-red-600/10">
                            <Trash2 className="w-3 h-3 mr-1" /> ลบ
                          </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                          <AlertDialogHeader>
                            <AlertDialogTitle>ยืนยันการลบ Account</AlertDialogTitle>
                            <AlertDialogDescription>
                              คุณต้องการลบ Account <strong>{account.account_number}</strong> หรือไม่?<br />
                              <span className="text-red-500">ประวัติการ sync ทั้งหมดจะถูกลบไปด้วย และไม่สามารถกู้คืนได้</span>
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>ยกเลิก</AlertDialogCancel>
                            <AlertDialogAction 
                              className="bg-red-600 hover:bg-red-700"
                              onClick={() => handleDeleteAccount(account)}
                            >
                              ยืนยันลบ
                            </AlertDialogAction>
                          </AlertDialogFooter>
                        </AlertDialogContent>
                      </AlertDialog>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Edit Dialog */}
        <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>แก้ไข MT5 Account</DialogTitle>
              <DialogDescription>
                แก้ไขข้อมูล Account {editingAccount?.account_number}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label>เลข MT5 Account</Label>
                <Input
                  value={editForm.account_number}
                  onChange={(e) => setEditForm(prev => ({ ...prev, account_number: e.target.value }))}
                />
              </div>
              <div className="space-y-2">
                <Label>ระบบเทรด</Label>
                <Select
                  value={editForm.trading_system_id}
                  onValueChange={(value) => setEditForm(prev => ({ ...prev, trading_system_id: value }))}
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
                <Label>แพ็คเกจ</Label>
                <Select
                  value={editForm.package_type}
                  onValueChange={(value) => setEditForm(prev => ({ ...prev, package_type: value }))}
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
              {editForm.package_type !== 'lifetime' && (
                <div className="space-y-2">
                  <Label>วันหมดอายุ</Label>
                  <Input
                    type="date"
                    value={editForm.expiry_date}
                    onChange={(e) => setEditForm(prev => ({ ...prev, expiry_date: e.target.value }))}
                  />
                </div>
              )}
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowEditDialog(false)}>ยกเลิก</Button>
              <Button onClick={handleSaveEdit} disabled={isEditing}>
                {isEditing ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    กำลังบันทึก...
                  </>
                ) : (
                  'บันทึก'
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Extend Dialog */}
        <Dialog open={showExtendDialog} onOpenChange={setShowExtendDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>ต่ออายุ License</DialogTitle>
              <DialogDescription>
                ต่ออายุ Account {extendingAccount?.account_number}
                {extendingAccount?.expiry_date && !extendingAccount?.is_lifetime && (
                  <><br />วันหมดอายุปัจจุบัน: {new Date(extendingAccount.expiry_date).toLocaleDateString('th-TH')}</>
                )}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label>ระยะเวลาที่ต้องการเพิ่ม</Label>
                <Select value={extendPeriod} onValueChange={setExtendPeriod}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1month">+ 1 เดือน</SelectItem>
                    <SelectItem value="3months">+ 3 เดือน</SelectItem>
                    <SelectItem value="6months">+ 6 เดือน</SelectItem>
                    <SelectItem value="1year">+ 1 ปี</SelectItem>
                    <SelectItem value="lifetime">Lifetime (ตลอดชีพ)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowExtendDialog(false)}>ยกเลิก</Button>
              <Button onClick={handleSaveExtend} disabled={isExtending}>
                {isExtending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    กำลังบันทึก...
                  </>
                ) : (
                  'ยืนยันต่ออายุ'
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </main>
    </div>
  );
};

export default CustomerDetail;
