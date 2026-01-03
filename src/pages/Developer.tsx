import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
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
} from '@/components/ui/dialog';
import CodeBlock from '@/components/CodeBlock';
import MQL5CodeTemplate from '@/components/MQL5CodeTemplate';
import EconomicCalendar from '@/components/EconomicCalendar';
import { 
  LogOut,
  Code2,
  TrendingUp,
  FileCode,
  RefreshCw,
  Download,
  XCircle,
  Copy,
  Check,
  Plus,
  Pencil,
  Trash2,
  Settings,
  Link as LinkIcon,
  Newspaper,
  Brain,
  Sparkles,
  Activity,
  Radio,
  Zap
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface TradingSystem {
  id: string;
  name: string;
  description: string | null;
  version: string | null;
  is_active: boolean;
  created_at: string;
  accounts_count?: number;
}

const Developer = () => {
  const navigate = useNavigate();
  const { user, loading, signOut, role } = useAuth();
  const { toast } = useToast();
  const [systems, setSystems] = useState<TradingSystem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [selectedSystem, setSelectedSystem] = useState<TradingSystem | null>(null);
  
  // Dialog states
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingSystem, setEditingSystem] = useState<TradingSystem | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    version: '1.0',
    is_active: true,
  });

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
      
      // Auto-select first system if none selected
      if (systemsWithCounts.length > 0 && !selectedSystem) {
        setSelectedSystem(systemsWithCounts[0]);
      }
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

  const handleOpenDialog = (system?: TradingSystem) => {
    if (system) {
      setEditingSystem(system);
      setFormData({
        name: system.name,
        description: system.description || '',
        version: system.version || '1.0',
        is_active: system.is_active,
      });
    } else {
      setEditingSystem(null);
      setFormData({
        name: '',
        description: '',
        version: '1.0',
        is_active: true,
      });
    }
    setIsDialogOpen(true);
  };

  const handleSave = async () => {
    if (!formData.name.trim()) {
      toast({
        title: "ข้อผิดพลาด",
        description: "กรุณากรอกชื่อระบบ",
        variant: "destructive",
      });
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
        toast({
          title: "สำเร็จ",
          description: "อัปเดตระบบเทรดสำเร็จ",
        });
      } else {
        const { data, error } = await supabase
          .from('trading_systems')
          .insert({
            name: formData.name,
            description: formData.description || null,
            version: formData.version || null,
            is_active: formData.is_active,
          })
          .select()
          .single();

        if (error) throw error;
        
        toast({
          title: "สำเร็จ",
          description: "เพิ่มระบบเทรดสำเร็จ - ดู Code Template ด้านล่าง",
        });
        
        // Select the newly created system
        if (data) {
          setSelectedSystem({ ...data, accounts_count: 0 });
        }
      }

      setIsDialogOpen(false);
      fetchSystems();
    } catch (error) {
      console.error('Error saving system:', error);
      toast({
        title: "ข้อผิดพลาด",
        description: "เกิดข้อผิดพลาดในการบันทึก",
        variant: "destructive",
      });
    }
  };

  const handleDelete = async (system: TradingSystem) => {
    if (system.accounts_count && system.accounts_count > 0) {
      toast({
        title: "ไม่สามารถลบได้",
        description: `มี ${system.accounts_count} accounts ที่ใช้ระบบนี้อยู่`,
        variant: "destructive",
      });
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
      
      toast({
        title: "สำเร็จ",
        description: "ลบระบบเทรดสำเร็จ",
      });
      
      if (selectedSystem?.id === system.id) {
        setSelectedSystem(null);
      }
      
      fetchSystems();
    } catch (error) {
      console.error('Error deleting system:', error);
      toast({
        title: "ข้อผิดพลาด",
        description: "เกิดข้อผิดพลาดในการลบ",
        variant: "destructive",
      });
    }
  };

  // Indicator Code Sample
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
          <TabsList className="grid w-full max-w-2xl grid-cols-4">
            <TabsTrigger value="ea" className="gap-2">
              <FileCode className="w-4 h-4" />
              Expert Advisors
            </TabsTrigger>
            <TabsTrigger value="indicators" className="gap-2">
              <TrendingUp className="w-4 h-4" />
              Indicators
            </TabsTrigger>
            <TabsTrigger value="ai" className="gap-2">
              <Brain className="w-4 h-4" />
              AI Analysis
            </TabsTrigger>
            <TabsTrigger value="news" className="gap-2">
              <Newspaper className="w-4 h-4" />
              News
            </TabsTrigger>
          </TabsList>

          {/* EA Tab */}
          <TabsContent value="ea" className="space-y-6">
            {/* Trading Systems Management */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Settings className="w-5 h-5" />
                      จัดการระบบเทรด
                    </CardTitle>
                    <CardDescription>
                      เพิ่ม แก้ไข หรือลบระบบเทรด - เชื่อมต่อกับระบบบริหารลูกค้า
                    </CardDescription>
                  </div>
                  <Button onClick={() => handleOpenDialog()}>
                    <Plus className="w-4 h-4 mr-2" />
                    เพิ่มระบบใหม่
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                {isLoading ? (
                  <div className="flex items-center justify-center py-8">
                    <RefreshCw className="w-6 h-6 animate-spin text-muted-foreground" />
                  </div>
                ) : systems.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground">
                    <Code2 className="w-12 h-12 mx-auto mb-2 opacity-50" />
                    <p>ยังไม่มีระบบเทรด</p>
                    <Button className="mt-4" onClick={() => handleOpenDialog()}>
                      <Plus className="w-4 h-4 mr-2" />
                      เพิ่มระบบแรก
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {systems.map((system) => (
                      <div
                        key={system.id}
                        className={`flex items-center justify-between p-4 rounded-lg border transition-colors cursor-pointer ${
                          selectedSystem?.id === system.id 
                            ? 'bg-primary/10 border-primary' 
                            : 'bg-card hover:bg-muted/50'
                        }`}
                        onClick={() => setSelectedSystem(system)}
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
                          <div className="flex items-center gap-1 text-sm text-muted-foreground mr-2">
                            <LinkIcon className="w-3 h-3" />
                            <span>{system.accounts_count || 0} accounts</span>
                          </div>
                          {system.version && (
                            <Badge variant="outline">v{system.version}</Badge>
                          )}
                          <Badge variant={system.is_active ? "default" : "secondary"}>
                            {system.is_active ? 'Active' : 'Inactive'}
                          </Badge>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleOpenDialog(system);
                            }}
                          >
                            <Pencil className="w-4 h-4" />
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Code Template for Selected System */}
            {selectedSystem && (
              selectedSystem.name === 'Moneyx Smart Gold System' ? (
                <Card>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="p-3 rounded-xl bg-primary/20">
                          <FileCode className="w-6 h-6 text-primary" />
                        </div>
                        <div>
                          <CardTitle>{selectedSystem.name}</CardTitle>
                          <CardDescription>{selectedSystem.description}</CardDescription>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-cyan-500/20 text-cyan-400 border-cyan-500">
                        v{selectedSystem.version}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <p className="text-sm text-muted-foreground">
                      ระบบนี้มี Code เต็มมากกว่า 9,600 บรรทัด รวมถึง License Manager, Data Sync, WebRequest API, Account Metrics และ Trading Logic ทั้งหมด
                    </p>
                    <Button 
                      onClick={() => navigate('/mt5-ea-guide')}
                      className="w-full"
                    >
                      <Code2 className="w-4 h-4 mr-2" />
                      ดู/แก้ไข Code เต็ม (9,600+ บรรทัด)
                    </Button>
                  </CardContent>
                </Card>
              ) : (
                <MQL5CodeTemplate
                  systemName={selectedSystem.name}
                  version={selectedSystem.version || '1.0'}
                  description={selectedSystem.description || undefined}
                />
              )
            )}
            
            {!selectedSystem && systems.length > 0 && (
              <Card>
                <CardContent className="py-8 text-center text-muted-foreground">
                  <FileCode className="w-12 h-12 mx-auto mb-2 opacity-50" />
                  <p>เลือกระบบเทรดเพื่อดู Code Template</p>
                </CardContent>
              </Card>
            )}
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

          {/* AI Analysis Tab */}
          <TabsContent value="ai" className="space-y-6">
            {/* AI Overview */}
            <Card className="border-primary/30 bg-gradient-to-br from-primary/5 to-background">
              <CardHeader>
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-xl bg-primary/20">
                    <Brain className="w-6 h-6 text-primary" />
                  </div>
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      AI-Powered Trading Analysis
                      <Badge variant="outline" className="bg-green-500/20 text-green-400 border-green-500">
                        Active
                      </Badge>
                    </CardTitle>
                    <CardDescription>
                      ระบบ AI วิเคราะห์ตลาดและสร้าง Signal แบบ Real-time ด้วย Lovable AI
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid gap-4 md:grid-cols-2">
                  <div className="p-4 rounded-lg bg-muted/50 border">
                    <h4 className="font-medium mb-2 flex items-center gap-2">
                      <Activity className="w-4 h-4 text-primary" />
                      System Configuration
                    </h4>
                    <ul className="text-sm text-muted-foreground space-y-1">
                      <li>• <strong>Pairs:</strong> EURUSD, GBPUSD, XAUUSD, USDJPY, AUDUSD</li>
                      <li>• <strong>Timeframe:</strong> H1 / H4</li>
                      <li>• <strong>Trigger:</strong> เมื่อ Candle ปิดใหม่</li>
                      <li>• <strong>Model:</strong> gemini-2.5-flash-lite (ประหยัดที่สุด)</li>
                    </ul>
                  </div>
                  <div className="p-4 rounded-lg bg-muted/50 border">
                    <h4 className="font-medium mb-2 flex items-center gap-2">
                      <Zap className="w-4 h-4 text-yellow-400" />
                      Credit Usage (ประมาณ)
                    </h4>
                    <ul className="text-sm text-muted-foreground space-y-1">
                      <li>• H1: ~24 requests/day (5 pairs รวม)</li>
                      <li>• H4: ~6 requests/day (5 pairs รวม)</li>
                      <li>• Cache: 1 ชั่วโมง (ลด requests ซ้ำ)</li>
                      <li>• ประมาณ: 180-720 requests/เดือน</li>
                    </ul>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* How It Works */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Sparkles className="w-5 h-5" />
                  วิธีการทำงาน
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-4 md:grid-cols-4">
                  <div className="text-center p-4 rounded-lg bg-blue-500/10 border border-blue-500/30">
                    <div className="w-10 h-10 mx-auto mb-2 rounded-full bg-blue-500/20 flex items-center justify-center">
                      <span className="font-bold text-blue-400">1</span>
                    </div>
                    <p className="text-sm font-medium">New Candle Close</p>
                    <p className="text-xs text-muted-foreground mt-1">EA ตรวจจับ candle ใหม่</p>
                  </div>
                  <div className="text-center p-4 rounded-lg bg-green-500/10 border border-green-500/30">
                    <div className="w-10 h-10 mx-auto mb-2 rounded-full bg-green-500/20 flex items-center justify-center">
                      <span className="font-bold text-green-400">2</span>
                    </div>
                    <p className="text-sm font-medium">Collect Data</p>
                    <p className="text-xs text-muted-foreground mt-1">รวม OHLC + Indicators</p>
                  </div>
                  <div className="text-center p-4 rounded-lg bg-purple-500/10 border border-purple-500/30">
                    <div className="w-10 h-10 mx-auto mb-2 rounded-full bg-purple-500/20 flex items-center justify-center">
                      <span className="font-bold text-purple-400">3</span>
                    </div>
                    <p className="text-sm font-medium">AI Analysis</p>
                    <p className="text-xs text-muted-foreground mt-1">Lovable AI วิเคราะห์</p>
                  </div>
                  <div className="text-center p-4 rounded-lg bg-yellow-500/10 border border-yellow-500/30">
                    <div className="w-10 h-10 mx-auto mb-2 rounded-full bg-yellow-500/20 flex items-center justify-center">
                      <span className="font-bold text-yellow-400">4</span>
                    </div>
                    <p className="text-sm font-medium">Signal to EA</p>
                    <p className="text-xs text-muted-foreground mt-1">ส่ง Entry/TP/SL</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* API Response Format */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Code2 className="w-5 h-5" />
                  API Response Format
                </CardTitle>
                <CardDescription>
                  รูปแบบ JSON ที่ AI จะส่งกลับมายัง EA
                </CardDescription>
              </CardHeader>
              <CardContent>
                <CodeBlock 
                  language="json" 
                  filename="ai-analysis-response.json"
                  code={`{
  "success": true,
  "timestamp": "2026-01-03T12:00:00Z",
  "analysis": [
    {
      "symbol": "XAUUSD",
      "trend": "bullish",
      "signal": "buy",
      "confidence": 75,
      "entry_price": 2650.50,
      "stop_loss": 2640.00,
      "take_profit": 2680.00,
      "reasoning": "EMA crossover bullish, RSI not overbought, MACD positive"
    },
    {
      "symbol": "EURUSD",
      "trend": "bearish",
      "signal": "sell",
      "confidence": 60,
      "entry_price": 1.0855,
      "stop_loss": 1.0880,
      "take_profit": 1.0800,
      "reasoning": "Below EMA50, RSI declining, bearish momentum"
    }
  ],
  "market_sentiment": "cautiously_bullish",
  "cached_count": 2,
  "analyzed_count": 3
}`} 
                />
              </CardContent>
            </Card>

            {/* EA Usage Example */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <FileCode className="w-5 h-5" />
                  การใช้งานใน EA
                </CardTitle>
                <CardDescription>
                  ตัวอย่างโค้ดสำหรับใช้ AI Signal ใน EA
                </CardDescription>
              </CardHeader>
              <CardContent>
                <CodeBlock 
                  language="mql5" 
                  filename="ea-ai-usage.mq5"
                  code={`// ใน OnTick() หลังจาก CheckAIAnalysis()
void OnTick()
{
   // ... license, news checks ...
   
   // Get AI signal for current symbol
   SAISignal signal = GetAISignal(_Symbol);
   
   // Check if signal is valid and has high confidence
   if(signal.signal == "buy" && signal.confidence >= 70)
   {
      // Execute buy order with AI-suggested levels
      double lots = InpLotSize;
      double sl = signal.stopLoss;
      double tp = signal.takeProfit;
      
      trade.Buy(lots, _Symbol, 0, sl, tp, "AI Signal Buy");
      Print("[AI Trade] BUY ", _Symbol, " Confidence: ", signal.confidence);
   }
   else if(signal.signal == "sell" && signal.confidence >= 70)
   {
      trade.Sell(lots, _Symbol, 0, sl, tp, "AI Signal Sell");
      Print("[AI Trade] SELL ", _Symbol, " Confidence: ", signal.confidence);
   }
   
   // Show AI status in comment
   string status = GetAIStatusString();
   Comment("AI Status: ", status, "\\n",
           "Signal: ", signal.signal, " (", signal.confidence, "%)");
}`} 
                />
              </CardContent>
            </Card>

            {/* Edge Function Link */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Radio className="w-5 h-5" />
                  Edge Function Endpoint
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="p-4 rounded-lg bg-muted font-mono text-sm break-all">
                  POST https://lkbhomsulgycxawwlnfh.supabase.co/functions/v1/ai-market-analysis
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="outline">x-api-key: EA_API_SECRET</Badge>
                  <Badge variant="outline">Content-Type: application/json</Badge>
                </div>
                <p className="text-sm text-muted-foreground">
                  Edge Function นี้จะ cache ผลลัพธ์ไว้ 1 ชั่วโมง ถ้า candle_time เดิมจะ return cached result โดยไม่เรียก AI ใหม่
                </p>
              </CardContent>
            </Card>
          </TabsContent>

          {/* News Tab */}
          <TabsContent value="news" className="space-y-6">
            <EconomicCalendar />
          </TabsContent>
        </Tabs>
      </main>

      {/* Add/Edit Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editingSystem ? 'แก้ไขระบบเทรด' : 'เพิ่มระบบเทรดใหม่'}
            </DialogTitle>
            <DialogDescription>
              {editingSystem 
                ? 'แก้ไขข้อมูลระบบเทรด' 
                : 'สร้างระบบเทรดใหม่พร้อม Code Template สำหรับ License และ Sync ข้อมูล'
              }
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
              <p className="text-xs text-muted-foreground">
                ชื่อนี้จะถูกใช้สร้างชื่อไฟล์ EA อัตโนมัติ
              </p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="version">เวอร์ชัน</Label>
              <Input
                id="version"
                value={formData.version}
                onChange={(e) => setFormData({ ...formData, version: e.target.value })}
                placeholder="เช่น 1.0"
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
            
            {!editingSystem && (
              <div className="p-4 rounded-lg bg-muted/50 border">
                <h4 className="font-medium mb-2 flex items-center gap-2">
                  <Code2 className="w-4 h-4" />
                  Code Template ที่จะสร้าง
                </h4>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>• License Manager - เช็ค License กับระบบ</li>
                  <li>• Data Sync - ส่งข้อมูล MT5 เข้าระบบบริหารลูกค้า</li>
                  <li>• Helper Functions - ฟังก์ชันช่วยเหลือ</li>
                  <li>• EA Template - โครงสร้าง EA พร้อมใช้งาน</li>
                </ul>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
              ยกเลิก
            </Button>
            <Button onClick={handleSave}>
              {editingSystem ? 'บันทึก' : 'สร้างระบบ'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default Developer;
