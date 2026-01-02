import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { toast } from 'sonner';
import { 
  ArrowLeft, 
  BarChart3, 
  Plus, 
  Pencil, 
  Trash2, 
  RefreshCw,
  CheckCircle,
  XCircle
} from 'lucide-react';

interface TradingSystem {
  id: string;
  name: string;
  description: string | null;
  version: string | null;
  is_active: boolean;
  created_at: string;
  accounts_count?: number;
}

const TradingSystems = () => {
  const navigate = useNavigate();
  const { user, loading, isAdmin, isSuperAdmin } = useAuth();
  const [systems, setSystems] = useState<TradingSystem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingSystem, setEditingSystem] = useState<TradingSystem | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    version: '',
    is_active: true,
  });

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isAdmin) {
      fetchSystems();
    }
  }, [user, isAdmin]);

  const fetchSystems = async () => {
    setIsLoading(true);
    try {
      const { data: systemsData, error } = await supabase
        .from('trading_systems')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Get account counts for each system
      const systemsWithCounts = await Promise.all(
        (systemsData || []).map(async (system) => {
          const { count } = await supabase
            .from('mt5_accounts')
            .select('*', { count: 'exact', head: true })
            .eq('trading_system_id', system.id);

          return {
            ...system,
            accounts_count: count || 0,
          };
        })
      );

      setSystems(systemsWithCounts);
    } catch (error) {
      console.error('Error fetching systems:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleOpenDialog = (system?: TradingSystem) => {
    if (system) {
      setEditingSystem(system);
      setFormData({
        name: system.name,
        description: system.description || '',
        version: system.version || '',
        is_active: system.is_active,
      });
    } else {
      setEditingSystem(null);
      setFormData({
        name: '',
        description: '',
        version: '',
        is_active: true,
      });
    }
    setIsDialogOpen(true);
  };

  const handleSave = async () => {
    if (!formData.name.trim()) {
      toast.error('กรุณากรอกชื่อระบบ');
      return;
    }

    try {
      if (editingSystem) {
        const { error } = await supabase
          .from('trading_systems')
          .update({
            name: formData.name,
            description: formData.description || null,
            version: formData.version || null,
            is_active: formData.is_active,
            updated_at: new Date().toISOString(),
          })
          .eq('id', editingSystem.id);

        if (error) throw error;
        toast.success('อัปเดตระบบเทรดสำเร็จ');
      } else {
        const { error } = await supabase
          .from('trading_systems')
          .insert({
            name: formData.name,
            description: formData.description || null,
            version: formData.version || null,
            is_active: formData.is_active,
          });

        if (error) throw error;
        toast.success('เพิ่มระบบเทรดสำเร็จ');
      }

      setIsDialogOpen(false);
      fetchSystems();
    } catch (error) {
      console.error('Error saving system:', error);
      toast.error('เกิดข้อผิดพลาด');
    }
  };

  const handleDelete = async (system: TradingSystem) => {
    if (system.accounts_count && system.accounts_count > 0) {
      toast.error(`ไม่สามารถลบได้ มี ${system.accounts_count} accounts ที่ใช้ระบบนี้อยู่`);
      return;
    }

    if (!confirm(`ต้องการลบระบบ "${system.name}" หรือไม่?`)) {
      return;
    }

    try {
      const { error } = await supabase
        .from('trading_systems')
        .delete()
        .eq('id', system.id);

      if (error) throw error;
      toast.success('ลบระบบเทรดสำเร็จ');
      fetchSystems();
    } catch (error) {
      console.error('Error deleting system:', error);
      toast.error('เกิดข้อผิดพลาดในการลบ');
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
        <div className="container flex items-center justify-between h-16">
          <div className="flex items-center">
            <Button variant="ghost" size="icon" onClick={() => navigate('/admin')}>
              <ArrowLeft className="w-5 h-5" />
            </Button>
            <div className="ml-4">
              <h1 className="font-bold text-lg">ระบบเทรด</h1>
              <p className="text-xs text-muted-foreground">
                จัดการ Trading Systems
              </p>
            </div>
          </div>
          {isSuperAdmin && (
            <Button onClick={() => handleOpenDialog()}>
              <Plus className="w-4 h-4 mr-2" />
              เพิ่มระบบใหม่
            </Button>
          )}
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(3)].map((_, i) => (
              <Skeleton key={i} className="h-48 w-full" />
            ))}
          </div>
        ) : systems.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center text-muted-foreground">
              <BarChart3 className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>ยังไม่มีระบบเทรด</p>
              {isSuperAdmin && (
                <Button className="mt-4" onClick={() => handleOpenDialog()}>
                  <Plus className="w-4 h-4 mr-2" />
                  เพิ่มระบบแรก
                </Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {systems.map((system) => (
              <Card key={system.id} className={!system.is_active ? 'opacity-60' : ''}>
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <CardTitle className="flex items-center gap-2">
                        <BarChart3 className="w-5 h-5 text-primary" />
                        {system.name}
                      </CardTitle>
                      {system.version && (
                        <Badge variant="outline" className="mt-2">
                          v{system.version}
                        </Badge>
                      )}
                    </div>
                    {system.is_active ? (
                      <Badge className="bg-green-600">
                        <CheckCircle className="w-3 h-3 mr-1" />
                        Active
                      </Badge>
                    ) : (
                      <Badge variant="secondary">
                        <XCircle className="w-3 h-3 mr-1" />
                        Inactive
                      </Badge>
                    )}
                  </div>
                  {system.description && (
                    <CardDescription className="mt-2">
                      {system.description}
                    </CardDescription>
                  )}
                </CardHeader>
                <CardContent>
                  <div className="flex items-center justify-between">
                    <div className="text-sm text-muted-foreground">
                      <span className="font-medium text-foreground">{system.accounts_count}</span> accounts
                    </div>
                    {isSuperAdmin && (
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleOpenDialog(system)}
                        >
                          <Pencil className="w-4 h-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleDelete(system)}
                          disabled={!!system.accounts_count && system.accounts_count > 0}
                        >
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </main>

      {/* Add/Edit Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editingSystem ? 'แก้ไขระบบเทรด' : 'เพิ่มระบบเทรดใหม่'}
            </DialogTitle>
            <DialogDescription>
              กรอกข้อมูลระบบเทรด
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="name">ชื่อระบบ *</Label>
              <Input
                id="name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="เช่น Moneyx Smart Gold"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="version">เวอร์ชัน</Label>
              <Input
                id="version"
                value={formData.version}
                onChange={(e) => setFormData({ ...formData, version: e.target.value })}
                placeholder="เช่น 5.1"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="description">คำอธิบาย</Label>
              <Textarea
                id="description"
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="รายละเอียดของระบบเทรด..."
                rows={3}
              />
            </div>
            <div className="flex items-center space-x-2">
              <Switch
                id="is_active"
                checked={formData.is_active}
                onCheckedChange={(checked) => setFormData({ ...formData, is_active: checked })}
              />
              <Label htmlFor="is_active">เปิดใช้งาน</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
              ยกเลิก
            </Button>
            <Button onClick={handleSave}>
              {editingSystem ? 'บันทึก' : 'เพิ่ม'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default TradingSystems;
