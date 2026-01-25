import { useState, useEffect, createContext, useContext, ReactNode } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';

type AppRole = 'super_admin' | 'admin' | 'developer' | 'customer' | 'user';

interface CustomerInfo {
  customerId: string | null;
  customerUuid: string | null;
  status: 'pending' | 'approved' | 'rejected' | null;
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  role: AppRole | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signUp: (email: string, password: string, fullName: string) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  isAdmin: boolean;
  isSuperAdmin: boolean;
  isCustomer: boolean;
  isApprovedCustomer: boolean;
  customerInfo: CustomerInfo;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<AppRole | null>(null);
  const [loading, setLoading] = useState(true);
  const [roleLoading, setRoleLoading] = useState(false);
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo>({
    customerId: null,
    customerUuid: null,
    status: null,
  });
  const { toast } = useToast();

  const fetchUserRole = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

      if (error) {
        console.error('Error fetching role:', error);
        return null;
      }

      return data?.role as AppRole | null;
    } catch (err) {
      console.error('Error fetching role:', err);
      return null;
    }
  };

  const fetchCustomerInfo = async (userId: string): Promise<CustomerInfo> => {
    try {
      const { data, error } = await supabase
        .from('customer_users')
        .select(`
          status,
          customer_id,
          customers:customer_id (
            customer_id,
            id
          )
        `)
        .eq('user_id', userId)
        .maybeSingle();

      if (error || !data) {
        return { customerId: null, customerUuid: null, status: null };
      }

      const customer = data.customers as { customer_id: string; id: string } | null;
      return {
        customerId: customer?.customer_id || null,
        customerUuid: customer?.id || null,
        status: data.status as 'pending' | 'approved' | 'rejected',
      };
    } catch (err) {
      console.error('Error fetching customer info:', err);
      return { customerId: null, customerUuid: null, status: null };
    }
  };

  useEffect(() => {
    // Set up auth state listener FIRST
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        
        // Defer role fetching with setTimeout to prevent deadlock
        if (session?.user) {
          setRoleLoading(true);
          setTimeout(async () => {
            const [fetchedRole, fetchedCustomerInfo] = await Promise.all([
              fetchUserRole(session.user.id),
              fetchCustomerInfo(session.user.id),
            ]);
            setRole(fetchedRole);
            setCustomerInfo(fetchedCustomerInfo);
            setRoleLoading(false);
          }, 0);
        } else {
          setRole(null);
          setCustomerInfo({ customerId: null, customerUuid: null, status: null });
          setRoleLoading(false);
        }
      }
    );

    // THEN check for existing session
    supabase.auth.getSession().then(async ({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      
      if (session?.user) {
        const [fetchedRole, fetchedCustomerInfo] = await Promise.all([
          fetchUserRole(session.user.id),
          fetchCustomerInfo(session.user.id),
        ]);
        setRole(fetchedRole);
        setCustomerInfo(fetchedCustomerInfo);
      }
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signIn = async (email: string, password: string) => {
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      
      if (error) {
        toast({
          variant: "destructive",
          title: "เข้าสู่ระบบไม่สำเร็จ",
          description: error.message === "Invalid login credentials" 
            ? "อีเมลหรือรหัสผ่านไม่ถูกต้อง" 
            : error.message,
        });
        return { error };
      }
      
      toast({
        title: "เข้าสู่ระบบสำเร็จ",
        description: "ยินดีต้อนรับเข้าสู่ระบบ Moneyx",
      });
      
      return { error: null };
    } catch (err) {
      const error = err as Error;
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
      return { error };
    }
  };

  const signUp = async (email: string, password: string, fullName: string) => {
    try {
      const redirectUrl = `${window.location.origin}/`;
      
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            full_name: fullName,
          },
        },
      });
      
      if (error) {
        let message = error.message;
        if (error.message.includes("already registered")) {
          message = "อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบ";
        }
        
        toast({
          variant: "destructive",
          title: "สมัครสมาชิกไม่สำเร็จ",
          description: message,
        });
        return { error };
      }
      
      toast({
        title: "สมัครสมาชิกสำเร็จ",
        description: "กรุณารอ Admin อนุมัติบัญชีของคุณ",
      });
      
      return { error: null };
    } catch (err) {
      const error = err as Error;
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
      return { error };
    }
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setRole(null);
    setCustomerInfo({ customerId: null, customerUuid: null, status: null });
    toast({
      title: "ออกจากระบบแล้ว",
      description: "ขอบคุณที่ใช้บริการ",
    });
  };

  const isAdmin = role === 'admin' || role === 'super_admin';
  const isSuperAdmin = role === 'super_admin';
  const isCustomer = role === 'customer';
  const isApprovedCustomer = isCustomer && customerInfo.status === 'approved';

  return (
    <AuthContext.Provider value={{
      user,
      session,
      role,
      loading,
      signIn,
      signUp,
      signOut,
      isAdmin,
      isSuperAdmin,
      isCustomer,
      isApprovedCustomer,
      customerInfo,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
