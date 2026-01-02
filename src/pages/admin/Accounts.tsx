import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Input } from '@/components/ui/input';
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
} from '@/components/ui/select';
import { 
  ArrowLeft, 
  CreditCard, 
  Search, 
  Eye,
  RefreshCw 
} from 'lucide-react';

interface MT5Account {
  id: string;
  account_number: string;
  package_type: string;
  status: string;
  balance: number | null;
  equity: number | null;
  expiry_date: string | null;
  is_lifetime: boolean;
  customer: {
    name: string;
    email: string;
  } | null;
}

const Accounts = () => {
  const navigate = useNavigate();
  const { user, loading, isAdmin } = useAuth();
  const [accounts, setAccounts] = useState<MT5Account[]>([]);
  const [filteredAccounts, setFilteredAccounts] = useState<MT5Account[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isAdmin) {
      fetchAccounts();
    }
  }, [user, isAdmin]);

  useEffect(() => {
    filterAccounts();
  }, [accounts, searchQuery, statusFilter]);

  const fetchAccounts = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('mt5_accounts')
        .select(`
          id,
          account_number,
          package_type,
          status,
          balance,
          equity,
          expiry_date,
          is_lifetime,
          customer:customers(name, email)
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAccounts(data || []);
    } catch (error) {
      console.error('Error fetching accounts:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const filterAccounts = () => {
    let filtered = [...accounts];

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (a) =>
          a.account_number.toLowerCase().includes(query) ||
          a.customer?.name?.toLowerCase().includes(query) ||
          a.customer?.email?.toLowerCase().includes(query)
      );
    }

    if (statusFilter !== 'all') {
      filtered = filtered.filter((a) => a.status === statusFilter);
    }

    setFilteredAccounts(filtered);
  };

  const getStatusBadge = (status: string, isLifetime: boolean) => {
    if (isLifetime) {
      return <Badge className="bg-purple-600">Lifetime</Badge>;
    }
    switch (status) {
      case 'active':
        return <Badge className="bg-green-600">Active</Badge>;
      case 'expiring_soon':
        return <Badge className="bg-yellow-600">Expiring Soon</Badge>;
      case 'expired':
        return <Badge variant="destructive">Expired</Badge>;
      case 'suspended':
        return <Badge variant="secondary">Suspended</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  if (loading || !isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center h-16">
          <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="ml-4">
            <h1 className="font-bold text-lg">MT5 Accounts</h1>
            <p className="text-xs text-muted-foreground">
              ทั้งหมด {accounts.length} accounts
            </p>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        {/* Filters */}
        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="ค้นหาด้วย Account Number, ชื่อลูกค้า หรือ Email..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full md:w-48">
                  <SelectValue placeholder="สถานะทั้งหมด" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">สถานะทั้งหมด</SelectItem>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="expiring_soon">Expiring Soon</SelectItem>
                  <SelectItem value="expired">Expired</SelectItem>
                  <SelectItem value="suspended">Suspended</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        {/* Accounts Table */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CreditCard className="w-5 h-5" />
              รายการ MT5 Accounts
            </CardTitle>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="space-y-4">
                {[...Array(5)].map((_, i) => (
                  <Skeleton key={i} className="h-16 w-full" />
                ))}
              </div>
            ) : filteredAccounts.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                ไม่พบ Account ที่ตรงกับเงื่อนไข
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Account Number</TableHead>
                    <TableHead>ลูกค้า</TableHead>
                    <TableHead>Package</TableHead>
                    <TableHead>สถานะ</TableHead>
                    <TableHead className="text-right">Balance</TableHead>
                    <TableHead className="text-right">Equity</TableHead>
                    <TableHead className="text-center">จัดการ</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredAccounts.map((account) => (
                    <TableRow key={account.id}>
                      <TableCell className="font-mono font-bold">
                        {account.account_number}
                      </TableCell>
                      <TableCell>
                        <div>
                          <p className="font-medium">{account.customer?.name || '-'}</p>
                          <p className="text-xs text-muted-foreground">{account.customer?.email || '-'}</p>
                        </div>
                      </TableCell>
                      <TableCell>{account.package_type}</TableCell>
                      <TableCell>
                        {getStatusBadge(account.status, account.is_lifetime)}
                      </TableCell>
                      <TableCell className="text-right font-mono">
                        ${Number(account.balance || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </TableCell>
                      <TableCell className="text-right font-mono">
                        ${Number(account.equity || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                      </TableCell>
                      <TableCell className="text-center">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => navigate(`/admin/accounts/${account.id}/portfolio`)}
                        >
                          <Eye className="w-4 h-4 mr-1" />
                          Portfolio
                        </Button>
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

export default Accounts;
