import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { useToast } from '@/hooks/use-toast';
import { 
  ArrowLeft,
  Users,
  Shield,
  RefreshCw,
  XCircle,
  UserCog,
  Crown,
  Code2,
  User
} from 'lucide-react';

interface UserWithRole {
  id: string;
  email: string | null;
  full_name: string | null;
  role: 'super_admin' | 'admin' | 'developer' | 'customer' | 'user' | null;
  created_at: string;
}

const UserManagement = () => {
  const navigate = useNavigate();
  const { user, loading, isSuperAdmin } = useAuth();
  const { toast } = useToast();
  const [users, setUsers] = useState<UserWithRole[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [updatingUserId, setUpdatingUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !user) {
      navigate('/');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isSuperAdmin) {
      fetchUsers();
    }
  }, [user, isSuperAdmin]);

  const fetchUsers = async () => {
    setIsLoading(true);
    try {
      // Fetch all profiles
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, email, full_name, created_at')
        .order('created_at', { ascending: false });

      if (profilesError) throw profilesError;

      // Fetch all user roles
      const { data: roles, error: rolesError } = await supabase
        .from('user_roles')
        .select('user_id, role');

      if (rolesError) throw rolesError;

      // Combine profiles with roles
      const usersWithRoles: UserWithRole[] = (profiles || []).map(profile => {
        const userRole = roles?.find(r => r.user_id === profile.id);
        return {
          ...profile,
          role: userRole?.role || null,
        };
      });

      setUsers(usersWithRoles);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: "ไม่สามารถโหลดข้อมูลผู้ใช้ได้",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleRoleChange = async (userId: string, newRole: string) => {
    if (userId === user?.id) {
      toast({
        variant: "destructive",
        title: "ไม่สามารถทำได้",
        description: "ไม่สามารถเปลี่ยน role ของตัวเองได้",
      });
      return;
    }

    setUpdatingUserId(userId);
    try {
      // First delete existing role
      await supabase
        .from('user_roles')
        .delete()
        .eq('user_id', userId);

      // Then insert new role if not 'none'
      if (newRole !== 'none') {
        const { error } = await supabase
          .from('user_roles')
          .insert({ user_id: userId, role: newRole as any });

        if (error) throw error;
      }

      toast({
        title: "อัพเดทสำเร็จ",
        description: `เปลี่ยน role เป็น ${newRole === 'none' ? 'No Role' : newRole}`,
      });

      // Refresh users list
      fetchUsers();
    } catch (error) {
      console.error('Error updating role:', error);
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: "ไม่สามารถอัพเดท role ได้",
      });
    } finally {
      setUpdatingUserId(null);
    }
  };

  const getRoleIcon = (role: string | null) => {
    switch (role) {
      case 'super_admin':
        return <Crown className="w-4 h-4 text-yellow-500" />;
      case 'admin':
        return <Shield className="w-4 h-4 text-blue-500" />;
      case 'developer':
        return <Code2 className="w-4 h-4 text-green-500" />;
      default:
        return <User className="w-4 h-4 text-muted-foreground" />;
    }
  };

  const getRoleBadge = (role: string | null) => {
    switch (role) {
      case 'super_admin':
        return <Badge className="bg-yellow-500/20 text-yellow-600 border-yellow-500/30">Super Admin</Badge>;
      case 'admin':
        return <Badge className="bg-blue-500/20 text-blue-600 border-blue-500/30">Admin</Badge>;
      case 'developer':
        return <Badge className="bg-green-500/20 text-green-600 border-green-500/30">Developer</Badge>;
      case 'user':
        return <Badge variant="secondary">User</Badge>;
      default:
        return <Badge variant="outline">No Role</Badge>;
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!isSuperAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto w-16 h-16 rounded-full bg-destructive/20 flex items-center justify-center mb-4">
              <XCircle className="w-8 h-8 text-destructive" />
            </div>
            <CardTitle>ไม่มีสิทธิ์เข้าถึง</CardTitle>
            <CardDescription>
              เฉพาะ Super Admin เท่านั้นที่สามารถจัดการผู้ใช้ได้
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Button onClick={() => navigate('/admin')} variant="outline">
              <ArrowLeft className="w-4 h-4 mr-2" />
              กลับไปหน้า Admin
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
            <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
              <ArrowLeft className="w-4 h-4" />
            </Button>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
                <UserCog className="w-5 h-5 text-primary" />
              </div>
              <div>
                <h1 className="font-bold text-lg">จัดการผู้ใช้</h1>
                <p className="text-xs text-muted-foreground">กำหนด Role ให้ผู้ใช้ในระบบ</p>
              </div>
            </div>
          </div>
          
          <Button variant="outline" size="sm" onClick={fetchUsers}>
            <RefreshCw className="w-4 h-4 mr-2" />
            รีเฟรช
          </Button>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="w-5 h-5" />
              รายชื่อผู้ใช้ทั้งหมด
            </CardTitle>
            <CardDescription>
              กำหนด role ให้ผู้ใช้: Super Admin, Admin, Developer, User
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="flex items-center justify-center py-12">
                <RefreshCw className="w-8 h-8 animate-spin text-muted-foreground" />
              </div>
            ) : users.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                <Users className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>ไม่พบผู้ใช้ในระบบ</p>
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>ผู้ใช้</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>Role ปัจจุบัน</TableHead>
                    <TableHead>เปลี่ยน Role</TableHead>
                    <TableHead>วันที่สมัคร</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {users.map((u) => (
                    <TableRow key={u.id}>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          {getRoleIcon(u.role)}
                          <span className="font-medium">{u.full_name || 'ไม่ระบุชื่อ'}</span>
                          {u.id === user?.id && (
                            <Badge variant="outline" className="text-xs">คุณ</Badge>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {u.email}
                      </TableCell>
                      <TableCell>
                        {getRoleBadge(u.role)}
                      </TableCell>
                      <TableCell>
                        <Select
                          value={u.role || 'none'}
                          onValueChange={(value) => handleRoleChange(u.id, value)}
                          disabled={u.id === user?.id || updatingUserId === u.id}
                        >
                          <SelectTrigger className="w-[140px]">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="super_admin">
                              <div className="flex items-center gap-2">
                                <Crown className="w-3 h-3 text-yellow-500" />
                                Super Admin
                              </div>
                            </SelectItem>
                            <SelectItem value="admin">
                              <div className="flex items-center gap-2">
                                <Shield className="w-3 h-3 text-blue-500" />
                                Admin
                              </div>
                            </SelectItem>
                            <SelectItem value="developer">
                              <div className="flex items-center gap-2">
                                <Code2 className="w-3 h-3 text-green-500" />
                                Developer
                              </div>
                            </SelectItem>
                            <SelectItem value="user">
                              <div className="flex items-center gap-2">
                                <User className="w-3 h-3" />
                                User
                              </div>
                            </SelectItem>
                            <SelectItem value="none">
                              No Role
                            </SelectItem>
                          </SelectContent>
                        </Select>
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {new Date(u.created_at).toLocaleDateString('th-TH')}
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

export default UserManagement;
