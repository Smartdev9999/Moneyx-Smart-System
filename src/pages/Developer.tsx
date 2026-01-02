import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import CodeBlock from '@/components/CodeBlock';
import { 
  LogOut,
  Code2,
  TrendingUp,
  FileCode,
  RefreshCw,
  Download,
  XCircle,
  Copy,
  Check
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface TradingSystem {
  id: string;
  name: string;
  description: string | null;
  version: string | null;
  is_active: boolean;
}

const Developer = () => {
  const navigate = useNavigate();
  const { user, loading, signOut, role } = useAuth();
  const { toast } = useToast();
  const [systems, setSystems] = useState<TradingSystem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const isDeveloper = role === 'developer' || role === 'super_admin' || role === 'admin';

  useEffect(() => {
    if (!loading && !user) {
      navigate('/');
    }
  }, [user, loading, navigate]);

  useEffect(() => {
    if (user && isDeveloper) {
      fetchSystems();
    }
  }, [user, isDeveloper]);

  const fetchSystems = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('trading_systems')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setSystems(data || []);
    } catch (error) {
      console.error('Error fetching systems:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSignOut = async () => {
    await signOut();
    navigate('/');
  };

  const handleCopy = async (text: string, id: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedId(id);
    toast({
      title: "คัดลอกแล้ว",
      description: "โค้ดถูกคัดลอกไปยัง clipboard",
    });
    setTimeout(() => setCopiedId(null), 2000);
  };

  // EA Code (simplified for display)
  const eaCodeSample = `//+------------------------------------------------------------------+
//|                   Moneyx Smart Gold System v5.1                    |
//|           Smart Money Trading System with CDC Action Zone          |
//|           + Grid Trading + Auto Scaling + Dashboard Panel          |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "5.10"
#property strict

// *** Include CTrade ***
#include <Trade/Trade.mqh>

// Signal Strategy Selection
enum ENUM_SIGNAL_STRATEGY
{
   STRATEGY_ZIGZAG = 0,      // ZigZag++ Structure
   STRATEGY_EMA_CHANNEL = 1, // EMA Channel (High/Low)
   STRATEGY_BOLLINGER = 2,   // Bollinger Bands
   STRATEGY_SMC = 3          // Smart Money Concepts (Order Block)
};

// ... Full EA code available in MT5EAGuide page`;

  const indicatorCodeSample = `//+------------------------------------------------------------------+
//|                   Moneyx Smart Indicator v2.0                    |
//|         Combined: EMA, Bollinger, ZigZag, PA, CDC, SMC           |
//|         + EA Integration via Global Variables                     |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   12

// Bollinger Bands MA Type
enum ENUM_BB_MA_TYPE
{
   BB_MA_SMA = 0,    // SMA
   BB_MA_EMA = 1,    // EMA
   BB_MA_SMMA = 2,   // SMMA (RMA)
   BB_MA_WMA = 3     // WMA
};

// ... Full Indicator code available in MT5IndicatorGuide page`;

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <RefreshCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (!isDeveloper) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto w-16 h-16 rounded-full bg-destructive/20 flex items-center justify-center mb-4">
              <XCircle className="w-8 h-8 text-destructive" />
            </div>
            <CardTitle>ไม่มีสิทธิ์เข้าถึง</CardTitle>
            <CardDescription>
              คุณไม่มีสิทธิ์เข้าถึงหน้า Developer Dashboard กรุณาติดต่อ Admin
            </CardDescription>
          </CardHeader>
          <CardContent className="flex justify-center">
            <Button onClick={handleSignOut} variant="outline">
              <LogOut className="w-4 h-4 mr-2" />
              ออกจากระบบ
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
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center">
              <Code2 className="w-5 h-5 text-primary" />
            </div>
            <div>
              <h1 className="font-bold text-lg">Developer Dashboard</h1>
              <p className="text-xs text-muted-foreground">Moneyx Trading Systems</p>
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            <Badge variant="secondary" className="gap-1">
              Developer
            </Badge>
            <span className="text-sm text-muted-foreground hidden md:block">
              {user?.email}
            </span>
            <Button variant="ghost" size="icon" onClick={handleSignOut}>
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container py-8">
        <Tabs defaultValue="ea" className="space-y-6">
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="ea" className="gap-2">
              <FileCode className="w-4 h-4" />
              Expert Advisors
            </TabsTrigger>
            <TabsTrigger value="indicators" className="gap-2">
              <TrendingUp className="w-4 h-4" />
              Indicators
            </TabsTrigger>
          </TabsList>

          {/* EA Tab */}
          <TabsContent value="ea" className="space-y-6">
            <div className="grid gap-6">
              {/* Moneyx Smart Gold System */}
              <Card>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="p-3 rounded-xl bg-cyan-500/20">
                        <FileCode className="w-6 h-6 text-cyan-400" />
                      </div>
                      <div>
                        <CardTitle>Moneyx Smart Gold System</CardTitle>
                        <CardDescription>EA v5.1 - Grid Trading + CDC Action Zone</CardDescription>
                      </div>
                    </div>
                    <Badge>v5.10</Badge>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex flex-wrap gap-2">
                    <Badge variant="outline">ZigZag++</Badge>
                    <Badge variant="outline">EMA Channel</Badge>
                    <Badge variant="outline">Bollinger Bands</Badge>
                    <Badge variant="outline">SMC Order Block</Badge>
                    <Badge variant="outline">Grid Trading</Badge>
                    <Badge variant="outline">Auto Scaling</Badge>
                  </div>
                  
                  <div className="relative">
                    <CodeBlock language="mql5" code={eaCodeSample} filename="Moneyx_Smart_Gold_EA.mq5" />
                  </div>
                  
                  <div className="flex gap-2">
                    <Button 
                      onClick={() => navigate('/mt5-ea-guide')}
                      className="flex-1"
                    >
                      <Download className="w-4 h-4 mr-2" />
                      ดูโค้ดฉบับเต็ม
                    </Button>
                    <Button 
                      variant="outline"
                      onClick={() => handleCopy(eaCodeSample, 'ea')}
                    >
                      {copiedId === 'ea' ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                    </Button>
                  </div>
                </CardContent>
              </Card>

              {/* Registered Trading Systems */}
              <Card>
                <CardHeader>
                  <CardTitle>ระบบเทรดที่ลงทะเบียน</CardTitle>
                  <CardDescription>รายการ EA ที่เชื่อมต่อกับระบบ Monitoring</CardDescription>
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <div className="flex items-center justify-center py-8">
                      <RefreshCw className="w-6 h-6 animate-spin text-muted-foreground" />
                    </div>
                  ) : systems.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Code2 className="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p>ยังไม่มีระบบเทรดที่ลงทะเบียน</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {systems.map((system) => (
                        <div
                          key={system.id}
                          className="flex items-center justify-between p-4 rounded-lg border bg-card"
                        >
                          <div className="flex items-center gap-3">
                            <div className={`p-2 rounded-lg ${system.is_active ? 'bg-green-500/20' : 'bg-muted'}`}>
                              <FileCode className={`w-5 h-5 ${system.is_active ? 'text-green-500' : 'text-muted-foreground'}`} />
                            </div>
                            <div>
                              <p className="font-medium">{system.name}</p>
                              <p className="text-sm text-muted-foreground">{system.description || 'ไม่มีคำอธิบาย'}</p>
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            {system.version && (
                              <Badge variant="outline">{system.version}</Badge>
                            )}
                            <Badge variant={system.is_active ? "default" : "secondary"}>
                              {system.is_active ? 'Active' : 'Inactive'}
                            </Badge>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* Indicators Tab */}
          <TabsContent value="indicators" className="space-y-6">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-3 rounded-xl bg-green-500/20">
                      <TrendingUp className="w-6 h-6 text-green-400" />
                    </div>
                    <div>
                      <CardTitle>Moneyx Smart Indicator</CardTitle>
                      <CardDescription>Combined Indicator v2.0 - EMA, BB, ZigZag, PA, CDC, SMC</CardDescription>
                    </div>
                  </div>
                  <Badge>v2.00</Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-wrap gap-2">
                  <Badge variant="outline">EMA Lines</Badge>
                  <Badge variant="outline">Bollinger Bands</Badge>
                  <Badge variant="outline">ZigZag</Badge>
                  <Badge variant="outline">Price Action</Badge>
                  <Badge variant="outline">CDC Action Zone</Badge>
                  <Badge variant="outline">SMC Order Blocks</Badge>
                </div>
                
                <div className="relative">
                  <CodeBlock language="mql5" code={indicatorCodeSample} filename="MoneyxSmartIndicator.mq5" />
                </div>
                
                <div className="flex gap-2">
                  <Button 
                    onClick={() => navigate('/mt5-indicator-guide')}
                    className="flex-1"
                  >
                    <Download className="w-4 h-4 mr-2" />
                    ดูโค้ดฉบับเต็ม
                  </Button>
                  <Button 
                    variant="outline"
                    onClick={() => handleCopy(indicatorCodeSample, 'indicator')}
                  >
                    {copiedId === 'indicator' ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  );
};

export default Developer;
