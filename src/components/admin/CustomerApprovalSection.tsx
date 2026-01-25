import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useToast } from '@/hooks/use-toast';
import { 
  Users,
  UserCheck,
  UserX,
  CheckCircle,
  XCircle,
  RefreshCw,
  Clock,
  Link2
} from 'lucide-react';

interface PendingCustomerUser {
  id: string;
  user_id: string;
  customer_id: string;
  status: string;
  created_at: string;
  profile: {
    email: string | null;
    full_name: string | null;
  } | null;
}

interface Customer {
  id: string;
  customer_id: string;
  name: string;
  email: string;
}

interface CustomerApprovalSectionProps {
  onApprovalComplete?: () => void;
}

export const CustomerApprovalSection = ({ onApprovalComplete }: CustomerApprovalSectionProps) => {
  const { toast } = useToast();
  const [pendingUsers, setPendingUsers] = useState<PendingCustomerUser[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [processingId, setProcessingId] = useState<string | null>(null);
  
  // Link dialog state
  const [showLinkDialog, setShowLinkDialog] = useState(false);
  const [selectedUser, setSelectedUser] = useState<PendingCustomerUser | null>(null);
  const [selectedCustomerId, setSelectedCustomerId] = useState<string>('');

  useEffect(() => {
    fetchPendingUsers();
    fetchCustomers();
  }, []);

  const fetchPendingUsers = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('customer_users')
        .select(`
          *
        `)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (error) throw error;
      
      // Fetch profiles for pending users
      if (data && data.length > 0) {
        const userIds = data.map(cu => cu.user_id);
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, email, full_name')
          .in('id', userIds);
        
        const usersWithProfiles = data.map(cu => ({
          ...cu,
          profile: profiles?.find(p => p.id === cu.user_id) || null
        }));
        
        setPendingUsers(usersWithProfiles);
      } else {
        setPendingUsers([]);
      }
    } catch (error) {
      console.error('Error fetching pending users:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchCustomers = async () => {
    try {
      // Fetch customers that are NOT already linked to any user
      const { data: linkedCustomerIds } = await supabase
        .from('customer_users')
        .select('customer_id')
        .eq('status', 'approved');

      const linkedIds = linkedCustomerIds?.map(c => c.customer_id) || [];

      let query = supabase
        .from('customers')
        .select('id, customer_id, name, email')
        .eq('status', 'active')
        .order('customer_id', { ascending: true });
      
      if (linkedIds.length > 0) {
        query = query.not('id', 'in', `(${linkedIds.join(',')})`);
      }

      const { data, error } = await query;

      if (error) throw error;
      setCustomers(data || []);
    } catch (error) {
      console.error('Error fetching customers:', error);
    }
  };

  const handleApprove = async (userRequest: PendingCustomerUser) => {
    // Check if customer is already linked
    const existingCustomer = customers.find(c => c.id === userRequest.customer_id);
    if (!existingCustomer) {
      // Show dialog to select customer
      setSelectedUser(userRequest);
      setShowLinkDialog(true);
      return;
    }
    
    await processApproval(userRequest.id, userRequest.user_id);
  };

  const handleLinkAndApprove = async () => {
    if (!selectedUser || !selectedCustomerId) return;
    
    setProcessingId(selectedUser.id);
    try {
      // Update the customer_id in customer_users
      const { error: updateError } = await supabase
        .from('customer_users')
        .update({ 
          customer_id: selectedCustomerId,
          status: 'approved',
          approved_at: new Date().toISOString()
        })
        .eq('id', selectedUser.id);

      if (updateError) throw updateError;

      toast({
        title: "อนุมัติสำเร็จ",
        description: "ผู้ใช้ถูกเชื่อมโยงกับ Customer และอนุมัติแล้ว",
      });

      setShowLinkDialog(false);
      setSelectedUser(null);
      setSelectedCustomerId('');
      fetchPendingUsers();
      fetchCustomers();
      onApprovalComplete?.();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setProcessingId(null);
    }
  };

  const processApproval = async (recordId: string, userId: string) => {
    setProcessingId(recordId);
    try {
      const { error } = await supabase
        .from('customer_users')
        .update({ 
          status: 'approved',
          approved_at: new Date().toISOString()
        })
        .eq('id', recordId);

      if (error) throw error;

      toast({
        title: "อนุมัติสำเร็จ",
        description: "ผู้ใช้สามารถเข้าถึง Customer Dashboard ได้แล้ว",
      });

      fetchPendingUsers();
      fetchCustomers();
      onApprovalComplete?.();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setProcessingId(null);
    }
  };

  const handleReject = async (recordId: string) => {
    setProcessingId(recordId);
    try {
      const { error } = await supabase
        .from('customer_users')
        .update({ status: 'rejected' })
        .eq('id', recordId);

      if (error) throw error;

      toast({
        title: "ปฏิเสธสำเร็จ",
        description: "คำขอถูกปฏิเสธแล้ว",
      });

      fetchPendingUsers();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setProcessingId(null);
    }
  };

  if (isLoading) {
    return (
      <Card className="mb-6">
        <CardContent className="flex items-center justify-center py-8">
          <RefreshCw className="w-6 h-6 animate-spin text-muted-foreground" />
        </CardContent>
      </Card>
    );
  }

  if (pendingUsers.length === 0) {
    return null;
  }

  return (
    <>
      <Card className="mb-6 border-warning/50 bg-warning/5">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-warning">
            <Clock className="w-5 h-5" />
            Customer รอการอนุมัติ
            <Badge variant="secondary" className="ml-2">{pendingUsers.length}</Badge>
          </CardTitle>
          <CardDescription>
            อนุมัติหรือปฏิเสธคำขอเข้าถึงของ Customer
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ผู้ใช้</TableHead>
                <TableHead>Email</TableHead>
                <TableHead>สถานะ</TableHead>
                <TableHead>วันที่ขอ</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {pendingUsers.map((pu) => (
                <TableRow key={pu.id}>
                  <TableCell className="font-medium">
                    {pu.profile?.full_name || 'ไม่ระบุชื่อ'}
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {pu.profile?.email}
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className="text-yellow-600 border-yellow-500">
                      <Clock className="w-3 h-3 mr-1" /> Pending
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground text-sm">
                    {new Date(pu.created_at).toLocaleDateString('th-TH')}
                  </TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="outline"
                        className="text-green-600 border-green-500 hover:bg-green-500/10"
                        onClick={() => handleApprove(pu)}
                        disabled={processingId === pu.id}
                      >
                        <CheckCircle className="w-3 h-3 mr-1" />
                        อนุมัติ
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        className="text-red-600 border-red-500 hover:bg-red-500/10"
                        onClick={() => handleReject(pu.id)}
                        disabled={processingId === pu.id}
                      >
                        <XCircle className="w-3 h-3 mr-1" />
                        ปฏิเสธ
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Link Customer Dialog */}
      <Dialog open={showLinkDialog} onOpenChange={setShowLinkDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Link2 className="w-5 h-5" />
              เชื่อมโยง Customer
            </DialogTitle>
            <DialogDescription>
              เลือก Customer ที่ต้องการเชื่อมโยงกับผู้ใช้ <strong>{selectedUser?.profile?.email}</strong>
            </DialogDescription>
          </DialogHeader>
          <div className="py-4">
            <Select value={selectedCustomerId} onValueChange={setSelectedCustomerId}>
              <SelectTrigger>
                <SelectValue placeholder="เลือก Customer" />
              </SelectTrigger>
              <SelectContent>
                {customers.map((customer) => (
                  <SelectItem key={customer.id} value={customer.id}>
                    {customer.customer_id} - {customer.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {customers.length === 0 && (
              <p className="text-sm text-muted-foreground mt-2">
                ไม่พบ Customer ที่ยังไม่ได้เชื่อมโยง กรุณาสร้าง Customer ก่อน
              </p>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowLinkDialog(false)}>
              ยกเลิก
            </Button>
            <Button onClick={handleLinkAndApprove} disabled={!selectedCustomerId || processingId !== null}>
              {processingId ? <RefreshCw className="w-4 h-4 mr-2 animate-spin" /> : <UserCheck className="w-4 h-4 mr-2" />}
              เชื่อมโยงและอนุมัติ
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default CustomerApprovalSection;
