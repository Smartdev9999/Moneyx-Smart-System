import { useState, useEffect, createContext, useContext, ReactNode } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';

type AppRole = 'super_admin' | 'admin' | 'user';

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
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<AppRole | null>(null);
  const [loading, setLoading] = useState(true);
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

  useEffect(() => {
    // Set up auth state listener FIRST
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        
        // Defer role fetching with setTimeout to prevent deadlock
        if (session?.user) {
          setTimeout(() => {
            fetchUserRole(session.user.id).then(setRole);
          }, 0);
        } else {
          setRole(null);
        }
      }
    );

    // THEN check for existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      
      if (session?.user) {
        fetchUserRole(session.user.id).then(setRole);
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
        description: "คุณคือ Super Admin คนแรกของระบบ!",
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
    toast({
      title: "ออกจากระบบแล้ว",
      description: "ขอบคุณที่ใช้บริการ",
    });
  };

  const isAdmin = role === 'admin' || role === 'super_admin';
  const isSuperAdmin = role === 'super_admin';

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
