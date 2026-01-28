import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import PasswordChangeCard from '@/components/customer/PasswordChangeCard';
import { 
  ArrowLeft,
  Settings as SettingsIcon,
  RefreshCw,
  Wallet,
  User,
  Mail,
  Phone,
  Building,
  Calendar,
  Copy,
  ExternalLink
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface CustomerData {
  id: string;
  customer_id: string;
  name: string;
  email: string;
  phone: string | null;
  broker: string | null;
  created_at: string;
}

interface FundWallet {
  id: string;
  wallet_address: string;
  network: string;
  label: string | null;
  is_active: boolean;
  last_sync: string | null;
}

const CustomerSettings = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { user, loading, isApprovedCustomer, customerInfo } = useAuth();
  const [customerData, setCustomerData] = useState<CustomerData | null>(null);
  const [fundWallets, setFundWallets] = useState<FundWallet[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [userEmail, setUserEmail] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isApprovedCustomer && customerInfo.customerUuid) {
      fetchData();
    }
    // Get user email for password change
    if (user?.email) {
      setUserEmail(user.email);
    }
  }, [user, isApprovedCustomer, customerInfo.customerUuid]);

  const fetchData = async () => {
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

      // Fetch fund wallets
      const { data: wallets } = await supabase
        .from('fund_wallets')
        .select('*')
        .eq('customer_id', customerInfo.customerUuid)
        .eq('is_active', true);

      if (wallets) {
        setFundWallets(wallets);
      }
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast({
      title: "คัดลอกแล้ว",
      description: "คัดลอก Wallet Address ลงคลิปบอร์ดแล้ว",
    });
  };

  const getExplorerUrl = (address: string, network: string) => {
    if (network === 'bsc') {
      return `https://bscscan.com/address/${address}`;
    } else if (network === 'tron') {
      return `https://tronscan.org/#/address/${address}`;
    }
    return '#';
  };

  if (loading || isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!isApprovedCustomer) {
    navigate('/customer');
    return null;
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center gap-4">
            <Button variant="ghost" size="icon" onClick={() => navigate('/customer')}>
              <ArrowLeft className="w-4 h-4" />
            </Button>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
                <SettingsIcon className="w-5 h-5 text-primary" />
              </div>
              <div>
                <h1 className="font-bold text-lg">Settings</h1>
                <p className="text-xs text-muted-foreground">ข้อมูลบัญชีและ Wallet</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8 space-y-8">
        {/* Customer Info */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <User className="w-5 h-5" />
              ข้อมูลลูกค้า
            </CardTitle>
            <CardDescription>
              ข้อมูลพื้นฐานของคุณในระบบ (ติดต่อ Admin เพื่อแก้ไข)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <User className="w-5 h-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">ชื่อ</p>
                  <p className="font-medium">{customerData?.name || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <Badge variant="outline" className="text-xs">
                  {customerData?.customer_id}
                </Badge>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <Mail className="w-5 h-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">อีเมล</p>
                  <p className="font-medium">{customerData?.email || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <Phone className="w-5 h-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">โทรศัพท์</p>
                  <p className="font-medium">{customerData?.phone || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <Building className="w-5 h-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">Broker</p>
                  <p className="font-medium">{customerData?.broker || '-'}</p>
                </div>
              </div>
              <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                <Calendar className="w-5 h-5 text-muted-foreground" />
                <div>
                  <p className="text-sm text-muted-foreground">วันที่สมัคร</p>
                  <p className="font-medium">
                    {customerData?.created_at ? new Date(customerData.created_at).toLocaleDateString('th-TH') : '-'}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Password Change */}
        <PasswordChangeCard userEmail={userEmail} />

        {/* Fund Wallets */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Wallet className="w-5 h-5" />
              Wallet Addresses
            </CardTitle>
            <CardDescription>
              กระเป๋า USDT ที่ผูกกับบัญชีของคุณ (ติดต่อ Admin เพื่อเพิ่ม/แก้ไข)
            </CardDescription>
          </CardHeader>
          <CardContent>
            {fundWallets.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Wallet className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>ยังไม่มี Wallet ที่ผูกไว้</p>
                <p className="text-sm">ติดต่อ Admin เพื่อเพิ่ม Wallet Address</p>
              </div>
            ) : (
              <div className="space-y-4">
                {fundWallets.map((wallet) => (
                  <div key={wallet.id} className="p-4 rounded-lg bg-muted/50 space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Badge variant={wallet.network === 'bsc' ? 'default' : 'secondary'}>
                          {wallet.network === 'bsc' ? 'BSC (BEP20)' : 'TRON (TRC20)'}
                        </Badge>
                        {wallet.label && (
                          <span className="text-sm text-muted-foreground">{wallet.label}</span>
                        )}
                      </div>
                      <div className="flex items-center gap-2">
                        <Button 
                          variant="ghost" 
                          size="icon"
                          onClick={() => copyToClipboard(wallet.wallet_address)}
                        >
                          <Copy className="w-4 h-4" />
                        </Button>
                        <Button 
                          variant="ghost" 
                          size="icon"
                          onClick={() => window.open(getExplorerUrl(wallet.wallet_address, wallet.network), '_blank')}
                        >
                          <ExternalLink className="w-4 h-4" />
                        </Button>
                      </div>
                    </div>
                    <p className="font-mono text-sm break-all">{wallet.wallet_address}</p>
                    {wallet.last_sync && (
                      <p className="text-xs text-muted-foreground">
                        Last sync: {new Date(wallet.last_sync).toLocaleString('th-TH')}
                      </p>
                    )}
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

export default CustomerSettings;
