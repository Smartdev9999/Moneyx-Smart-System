import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { 
  ArrowLeft, 
  Search, 
  UserPlus, 
  Eye,
  ChevronRight,
  Users,
  Filter
} from 'lucide-react';

interface Customer {
  id: string;
  customer_id: string;
  name: string;
  email: string;
  phone: string | null;
  broker: string | null;
  status: string;
  created_at: string;
  accounts_count: number;
  active_accounts: number;
  expiring_accounts: number;
}

const Customers = () => {
  const navigate = useNavigate();
  const { user, loading, isAdmin } = useAuth();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [filteredCustomers, setFilteredCustomers] = useState<Customer[]>([]);
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
      fetchCustomers();
    }
  }, [user, isAdmin]);

  useEffect(() => {
    filterCustomers();
  }, [customers, searchQuery, statusFilter]);

  const fetchCustomers = async () => {
    setIsLoading(true);
    try {
      const { data: customersData, error } = await supabase
        .from('customers')
        .select(`
          *,
          mt5_accounts(id, status)
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const processedCustomers = customersData?.map(c => ({
        id: c.id,
        customer_id: c.customer_id,
        name: c.name,
        email: c.email,
        phone: c.phone,
        broker: c.broker,
        status: c.status,
        created_at: c.created_at,
        accounts_count: c.mt5_accounts?.length || 0,
        active_accounts: c.mt5_accounts?.filter((a: any) => a.status === 'active').length || 0,
        expiring_accounts: c.mt5_accounts?.filter((a: any) => a.status === 'expiring_soon').length || 0,
      })) || [];

      setCustomers(processedCustomers);
    } catch (error) {
      console.error('Error fetching customers:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const filterCustomers = () => {
    let filtered = [...customers];

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(c => 
        c.name.toLowerCase().includes(query) ||
        c.email.toLowerCase().includes(query) ||
        c.customer_id.toLowerCase().includes(query) ||
        c.phone?.toLowerCase().includes(query)
      );
    }

    // Status filter
    if (statusFilter !== 'all') {
      if (statusFilter === 'expiring') {
        filtered = filtered.filter(c => c.expiring_accounts > 0);
      } else {
        filtered = filtered.filter(c => c.status === statusFilter);
      }
    }

    setFilteredCustomers(filtered);
  };

  const getStatusBadge = (customer: Customer) => {
    if (customer.expiring_accounts > 0) {
      return <Badge variant="outline" className="text-yellow-600 border-yellow-500">กำลังหมดอายุ</Badge>;
    }
    if (customer.status === 'active') {
      return <Badge variant="outline" className="text-green-600 border-green-500">ใช้งาน</Badge>;
    }
    return <Badge variant="outline" className="text-gray-600 border-gray-500">ไม่ใช้งาน</Badge>;
  };

  if (loading || !isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <Skeleton className="h-8 w-8 rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container flex items-center gap-4 h-16">
          <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
              <Users className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h1 className="font-bold text-lg">จัดการลูกค้า</h1>
              <p className="text-xs text-muted-foreground">{customers.length} ลูกค้า</p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        {/* Filters */}
        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="ค้นหาชื่อ, อีเมล, รหัสลูกค้า..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full md:w-48">
                  <Filter className="w-4 h-4 mr-2" />
                  <SelectValue placeholder="สถานะ" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">ทั้งหมด</SelectItem>
                  <SelectItem value="active">ใช้งาน</SelectItem>
                  <SelectItem value="inactive">ไม่ใช้งาน</SelectItem>
                  <SelectItem value="expiring">กำลังหมดอายุ</SelectItem>
                </SelectContent>
              </Select>
              <Button onClick={() => navigate('/admin/customers/new')}>
                <UserPlus className="w-4 h-4 mr-2" />
                เพิ่มลูกค้าใหม่
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Customers Table */}
        <Card>
          <CardContent className="p-0">
            {isLoading ? (
              <div className="p-8 space-y-4">
                <Skeleton className="h-12 w-full" />
                <Skeleton className="h-12 w-full" />
                <Skeleton className="h-12 w-full" />
              </div>
            ) : filteredCustomers.length === 0 ? (
              <div className="p-16 text-center text-muted-foreground">
                <Users className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <p className="text-lg font-medium">ไม่พบลูกค้า</p>
                <p className="text-sm">ลองเปลี่ยนตัวกรองหรือเพิ่มลูกค้าใหม่</p>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>รหัส/ชื่อลูกค้า</TableHead>
                    <TableHead className="hidden md:table-cell">อีเมล</TableHead>
                    <TableHead className="hidden lg:table-cell">โบรกเกอร์</TableHead>
                    <TableHead className="text-center">MT5 Accounts</TableHead>
                    <TableHead>สถานะ</TableHead>
                    <TableHead className="text-right"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredCustomers.map((customer) => (
                    <TableRow 
                      key={customer.id}
                      className="cursor-pointer hover:bg-muted/50"
                      onClick={() => navigate(`/admin/customers/${customer.id}`)}
                    >
                      <TableCell>
                        <div>
                          <p className="font-medium">{customer.name}</p>
                          <p className="text-sm text-muted-foreground font-mono">{customer.customer_id}</p>
                        </div>
                      </TableCell>
                      <TableCell className="hidden md:table-cell">
                        {customer.email}
                      </TableCell>
                      <TableCell className="hidden lg:table-cell">
                        {customer.broker || '-'}
                      </TableCell>
                      <TableCell className="text-center">
                        <div className="flex items-center justify-center gap-1">
                          <span className="font-medium">{customer.accounts_count}</span>
                          {customer.expiring_accounts > 0 && (
                            <Badge variant="outline" className="text-yellow-600 border-yellow-500 text-xs">
                              {customer.expiring_accounts} หมดอายุ
                            </Badge>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {getStatusBadge(customer)}
                      </TableCell>
                      <TableCell className="text-right">
                        <ChevronRight className="w-4 h-4 text-muted-foreground" />
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

export default Customers;
