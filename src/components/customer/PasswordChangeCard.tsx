import { useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Lock, Eye, EyeOff, Loader2 } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface PasswordChangeCardProps {
  userEmail: string | null;
}

const PasswordChangeCard = ({ userEmail }: PasswordChangeCardProps) => {
  const { toast } = useToast();
  const [isChanging, setIsChanging] = useState(false);
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  
  const [passwordForm, setPasswordForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  const handleChangePassword = async () => {
    // Validation
    if (!passwordForm.currentPassword || !passwordForm.newPassword || !passwordForm.confirmPassword) {
      toast({
        variant: "destructive",
        title: "ข้อมูลไม่ครบ",
        description: "กรุณากรอกข้อมูลให้ครบทุกช่อง",
      });
      return;
    }

    if (passwordForm.newPassword.length < 6) {
      toast({
        variant: "destructive",
        title: "รหัสผ่านสั้นเกินไป",
        description: "รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร",
      });
      return;
    }

    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      toast({
        variant: "destructive",
        title: "รหัสผ่านไม่ตรงกัน",
        description: "รหัสผ่านใหม่และยืนยันรหัสผ่านไม่ตรงกัน",
      });
      return;
    }

    if (passwordForm.currentPassword === passwordForm.newPassword) {
      toast({
        variant: "destructive",
        title: "รหัสผ่านซ้ำ",
        description: "รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม",
      });
      return;
    }

    setIsChanging(true);
    try {
      // Step 1: Verify current password by re-authenticating
      if (!userEmail) {
        throw new Error('ไม่พบข้อมูลอีเมล');
      }

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: userEmail,
        password: passwordForm.currentPassword,
      });

      if (signInError) {
        throw new Error('รหัสผ่านปัจจุบันไม่ถูกต้อง');
      }

      // Step 2: Update password
      const { error: updateError } = await supabase.auth.updateUser({
        password: passwordForm.newPassword,
      });

      if (updateError) {
        throw updateError;
      }

      toast({
        title: "เปลี่ยนรหัสผ่านสำเร็จ",
        description: "รหัสผ่านของคุณถูกเปลี่ยนแล้ว",
      });

      // Reset form
      setPasswordForm({
        currentPassword: '',
        newPassword: '',
        confirmPassword: '',
      });
    } catch (error: any) {
      console.error('Error changing password:', error);
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message || "ไม่สามารถเปลี่ยนรหัสผ่านได้",
      });
    } finally {
      setIsChanging(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Lock className="w-5 h-5" />
          บัญชี Login
        </CardTitle>
        <CardDescription>
          เปลี่ยนรหัสผ่านของบัญชี Login ของคุณ
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Current Password */}
        <div className="space-y-2">
          <Label htmlFor="currentPassword">รหัสผ่านปัจจุบัน</Label>
          <div className="relative">
            <Input
              id="currentPassword"
              type={showCurrentPassword ? "text" : "password"}
              placeholder="กรอกรหัสผ่านปัจจุบัน"
              value={passwordForm.currentPassword}
              onChange={(e) => setPasswordForm(prev => ({ ...prev, currentPassword: e.target.value }))}
              className="pr-10"
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0 h-full px-3 hover:bg-transparent"
              onClick={() => setShowCurrentPassword(!showCurrentPassword)}
            >
              {showCurrentPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </Button>
          </div>
        </div>

        {/* New Password */}
        <div className="space-y-2">
          <Label htmlFor="newPassword">รหัสผ่านใหม่</Label>
          <div className="relative">
            <Input
              id="newPassword"
              type={showNewPassword ? "text" : "password"}
              placeholder="กรอกรหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)"
              value={passwordForm.newPassword}
              onChange={(e) => setPasswordForm(prev => ({ ...prev, newPassword: e.target.value }))}
              className="pr-10"
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0 h-full px-3 hover:bg-transparent"
              onClick={() => setShowNewPassword(!showNewPassword)}
            >
              {showNewPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </Button>
          </div>
        </div>

        {/* Confirm Password */}
        <div className="space-y-2">
          <Label htmlFor="confirmPassword">ยืนยันรหัสผ่านใหม่</Label>
          <div className="relative">
            <Input
              id="confirmPassword"
              type={showConfirmPassword ? "text" : "password"}
              placeholder="กรอกรหัสผ่านใหม่อีกครั้ง"
              value={passwordForm.confirmPassword}
              onChange={(e) => setPasswordForm(prev => ({ ...prev, confirmPassword: e.target.value }))}
              className="pr-10"
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0 h-full px-3 hover:bg-transparent"
              onClick={() => setShowConfirmPassword(!showConfirmPassword)}
            >
              {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </Button>
          </div>
        </div>

        {/* Submit Button */}
        <div className="pt-2">
          <Button 
            onClick={handleChangePassword} 
            disabled={isChanging}
            className="w-full sm:w-auto"
          >
            {isChanging ? (
              <>
                <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                กำลังเปลี่ยนรหัสผ่าน...
              </>
            ) : (
              <>
                <Lock className="w-4 h-4 mr-2" />
                เปลี่ยนรหัสผ่าน
              </>
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};

export default PasswordChangeCard;
