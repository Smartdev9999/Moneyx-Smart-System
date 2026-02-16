import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import {
  Collapsible, CollapsibleContent, CollapsibleTrigger,
} from '@/components/ui/collapsible';
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import {
  Plus, RefreshCw, Download, Brain, Sparkles, FileCode, ChevronDown,
  ChevronRight, Activity, Clock, Target, TrendingUp, TrendingDown,
  Trash2, Eye, Zap, Copy, Check,
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface Session {
  id: string;
  session_name: string;
  ea_magic_number: number;
  broker: string | null;
  account_number: string | null;
  symbols: string[] | null;
  timeframe: string | null;
  start_time: string | null;
  end_time: string | null;
  total_orders: number;
  strategy_summary: string | null;
  strategy_prompt: string | null;
  generated_ea_code: string | null;
  status: string;
  notes: string | null;
  created_at: string;
}

interface TrackedOrder {
  id: string;
  ticket: number;
  magic_number: number;
  symbol: string;
  order_type: string;
  volume: number;
  open_price: number;
  close_price: number | null;
  sl: number | null;
  tp: number | null;
  profit: number;
  swap: number;
  commission: number;
  open_time: string | null;
  close_time: string | null;
  holding_time_seconds: number;
  event_type: string;
  market_data: any;
}

const statusColors: Record<string, string> = {
  tracking: 'bg-blue-500/20 text-blue-400 border-blue-500',
  analyzing: 'bg-yellow-500/20 text-yellow-400 border-yellow-500',
  summarized: 'bg-purple-500/20 text-purple-400 border-purple-500',
  prompted: 'bg-orange-500/20 text-orange-400 border-orange-500',
  generated: 'bg-green-500/20 text-green-400 border-green-500',
};

const StrategyLab = () => {
  const { toast } = useToast();
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedSession, setSelectedSession] = useState<Session | null>(null);
  const [orders, setOrders] = useState<TrackedOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [analyzing, setAnalyzing] = useState(false);
  const [currentAction, setCurrentAction] = useState('');
  const [isNewSessionOpen, setIsNewSessionOpen] = useState(false);
  const [newSessionName, setNewSessionName] = useState('');
  const [newMagicNumber, setNewMagicNumber] = useState('0');
  const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({});
  const [editablePrompt, setEditablePrompt] = useState('');
  const [copied, setCopied] = useState(false);

  const fetchSessions = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('tracked_ea_sessions' as any)
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setSessions((data as any[]) || []);
      if (data && data.length > 0 && !selectedSession) {
        setSelectedSession(data[0] as any);
      }
    } catch (err: any) {
      console.error('Error fetching sessions:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchOrders = useCallback(async (sessionId: string) => {
    try {
      const { data, error } = await supabase
        .from('tracked_orders' as any)
        .select('*')
        .eq('session_id', sessionId)
        .order('open_time', { ascending: false });
      if (error) throw error;
      setOrders((data as any[]) || []);
    } catch (err: any) {
      console.error('Error fetching orders:', err);
    }
  }, []);

  useEffect(() => { fetchSessions(); }, [fetchSessions]);
  useEffect(() => {
    if (selectedSession) {
      fetchOrders(selectedSession.id);
      setEditablePrompt(selectedSession.strategy_prompt || '');
    }
  }, [selectedSession, fetchOrders]);

  const handleCreateSession = async () => {
    if (!newSessionName.trim()) return;
    try {
      const { data, error } = await supabase
        .from('tracked_ea_sessions' as any)
        .insert({
          session_name: newSessionName,
          ea_magic_number: parseInt(newMagicNumber) || 0,
        } as any)
        .select()
        .single();
      if (error) throw error;
      toast({ title: 'สร้าง Session สำเร็จ' });
      setIsNewSessionOpen(false);
      setNewSessionName('');
      setNewMagicNumber('0');
      fetchSessions();
      if (data) setSelectedSession(data as any);
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' });
    }
  };

  const handleDeleteSession = async (id: string) => {
    if (!confirm('ต้องการลบ Session นี้?')) return;
    try {
      const { error } = await supabase.from('tracked_ea_sessions' as any).delete().eq('id', id);
      if (error) throw error;
      toast({ title: 'ลบ Session สำเร็จ' });
      if (selectedSession?.id === id) setSelectedSession(null);
      fetchSessions();
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' });
    }
  };

  const handleAnalyze = async (action: string) => {
    if (!selectedSession) return;
    setAnalyzing(true);
    setCurrentAction(action);
    
    const actionLabels: Record<string, string> = {
      summarize: 'กำลังสรุปกลยุทธ์...',
      generate_prompt: 'กำลังสร้าง Prompt...',
      generate_ea: 'กำลังสร้าง EA Code...',
    };
    
    toast({ title: actionLabels[action] || 'Processing...' });
    
    try {
      const { data, error } = await supabase.functions.invoke('analyze-ea-strategy', {
        body: { session_id: selectedSession.id, action },
      });
      
      if (error) throw error;
      if (data?.error) throw new Error(data.error);

      toast({ title: 'สำเร็จ!', description: `${action} เสร็จสิ้น` });
      
      // Refresh session data
      const { data: updated } = await supabase
        .from('tracked_ea_sessions' as any)
        .select('*')
        .eq('id', selectedSession.id)
        .single();
      if (updated) {
        setSelectedSession(updated as any);
        setEditablePrompt((updated as any).strategy_prompt || '');
      }
      fetchSessions();
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' });
    } finally {
      setAnalyzing(false);
      setCurrentAction('');
    }
  };

  const handleSavePrompt = async () => {
    if (!selectedSession) return;
    try {
      const { error } = await supabase
        .from('tracked_ea_sessions' as any)
        .update({ strategy_prompt: editablePrompt } as any)
        .eq('id', selectedSession.id);
      if (error) throw error;
      toast({ title: 'บันทึก Prompt สำเร็จ' });
      setSelectedSession({ ...selectedSession, strategy_prompt: editablePrompt });
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' });
    }
  };

  const handleDownloadEA = () => {
    if (!selectedSession?.generated_ea_code) return;
    const blob = new Blob([selectedSession.generated_ea_code], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${selectedSession.session_name.replace(/\s+/g, '_')}_EA.mq5`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleCopyCode = async (code: string) => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const toggleSection = (key: string) => {
    setExpandedSections(prev => ({ ...prev, [key]: !prev[key] }));
  };

  // Calculate statistics
  const closedOrders = orders.filter(o => o.event_type === 'close');
  const wins = closedOrders.filter(o => o.profit > 0);
  const losses = closedOrders.filter(o => o.profit <= 0);
  const winRate = closedOrders.length > 0 ? (wins.length / closedOrders.length * 100) : 0;
  const avgProfit = wins.length > 0 ? wins.reduce((s, o) => s + o.profit, 0) / wins.length : 0;
  const avgLoss = losses.length > 0 ? losses.reduce((s, o) => s + o.profit, 0) / losses.length : 0;
  const avgHoldTime = closedOrders.length > 0 
    ? closedOrders.reduce((s, o) => s + o.holding_time_seconds, 0) / closedOrders.length 
    : 0;
  const totalProfit = closedOrders.reduce((s, o) => s + o.profit, 0);

  const formatDuration = (seconds: number) => {
    if (seconds < 60) return `${Math.round(seconds)}s`;
    if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
    if (seconds < 86400) return `${(seconds / 3600).toFixed(1)}h`;
    return `${(seconds / 86400).toFixed(1)}d`;
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Left Panel - Session List */}
      <div className="lg:col-span-1 space-y-4">
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg flex items-center gap-2">
                <Brain className="w-5 h-5" />
                Sessions
              </CardTitle>
              <div className="flex gap-2">
                <Button size="sm" variant="outline" onClick={() => fetchSessions()}>
                  <RefreshCw className="w-4 h-4" />
                </Button>
                <Button size="sm" onClick={() => setIsNewSessionOpen(true)}>
                  <Plus className="w-4 h-4 mr-1" /> New
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-2">
            {loading ? (
              <div className="flex justify-center py-8">
                <RefreshCw className="w-6 h-6 animate-spin text-muted-foreground" />
              </div>
            ) : sessions.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Brain className="w-10 h-10 mx-auto mb-2 opacity-50" />
                <p className="text-sm">ยังไม่มี Session</p>
                <p className="text-xs mt-1">ติดตั้ง EA Tracker บน MT5 เพื่อเริ่มเก็บข้อมูล</p>
              </div>
            ) : (
              sessions.map((s) => (
                <div
                  key={s.id}
                  onClick={() => setSelectedSession(s)}
                  className={`p-3 rounded-lg border cursor-pointer transition-colors ${
                    selectedSession?.id === s.id
                      ? 'bg-primary/10 border-primary'
                      : 'hover:bg-muted/50'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-sm truncate">{s.session_name}</p>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge variant="outline" className={`text-xs ${statusColors[s.status] || ''}`}>
                          {s.status}
                        </Badge>
                        <span className="text-xs text-muted-foreground">
                          Magic: {s.ea_magic_number || 'All'}
                        </span>
                      </div>
                      <p className="text-xs text-muted-foreground mt-1">
                        {s.total_orders} orders • {(s.symbols || []).join(', ') || 'N/A'}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 shrink-0"
                      onClick={(e) => { e.stopPropagation(); handleDeleteSession(s.id); }}
                    >
                      <Trash2 className="w-3.5 h-3.5 text-muted-foreground" />
                    </Button>
                  </div>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      {/* Right Panel - Session Detail */}
      <div className="lg:col-span-2 space-y-4">
        {!selectedSession ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-16 text-muted-foreground">
              <Brain className="w-16 h-16 mb-4 opacity-30" />
              <p className="text-lg font-medium">เลือก Session เพื่อดูรายละเอียด</p>
              <p className="text-sm mt-1">หรือสร้าง Session ใหม่เพื่อเริ่มต้น</p>
            </CardContent>
          </Card>
        ) : (
          <>
            {/* Session Info */}
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Activity className="w-5 h-5" />
                      {selectedSession.session_name}
                    </CardTitle>
                    <CardDescription className="mt-1">
                      Magic: {selectedSession.ea_magic_number || 'All'} 
                      {selectedSession.broker && ` • ${selectedSession.broker}`}
                      {selectedSession.account_number && ` • #${selectedSession.account_number}`}
                    </CardDescription>
                  </div>
                  <Badge variant="outline" className={`${statusColors[selectedSession.status] || ''}`}>
                    {selectedSession.status}
                  </Badge>
                </div>
              </CardHeader>
            </Card>

            {/* Statistics */}
            {closedOrders.length > 0 && (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                <Card className="p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                    <Target className="w-4 h-4" /> Win Rate
                  </div>
                  <p className={`text-xl font-bold ${winRate >= 50 ? 'text-green-400' : 'text-red-400'}`}>
                    {winRate.toFixed(1)}%
                  </p>
                  <p className="text-xs text-muted-foreground">{wins.length}W / {losses.length}L</p>
                </Card>
                <Card className="p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                    <TrendingUp className="w-4 h-4" /> Total P/L
                  </div>
                  <p className={`text-xl font-bold ${totalProfit >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                    ${totalProfit.toFixed(2)}
                  </p>
                </Card>
                <Card className="p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                    <Clock className="w-4 h-4" /> Avg Hold
                  </div>
                  <p className="text-xl font-bold">{formatDuration(avgHoldTime)}</p>
                </Card>
                <Card className="p-3">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground mb-1">
                    <Activity className="w-4 h-4" /> Avg W/L
                  </div>
                  <p className="text-sm">
                    <span className="text-green-400">${avgProfit.toFixed(2)}</span>
                    {' / '}
                    <span className="text-red-400">${avgLoss.toFixed(2)}</span>
                  </p>
                </Card>
              </div>
            )}

            {/* Action Buttons */}
            <Card>
              <CardContent className="pt-4 pb-4">
                <div className="flex flex-wrap gap-3">
                  <Button
                    onClick={() => handleAnalyze('summarize')}
                    disabled={analyzing || orders.length === 0}
                    className="gap-2"
                  >
                    {analyzing && currentAction === 'summarize' ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      <Brain className="w-4 h-4" />
                    )}
                    1. สรุปกลยุทธ์
                  </Button>
                  <Button
                    onClick={() => handleAnalyze('generate_prompt')}
                    disabled={analyzing || !selectedSession.strategy_summary}
                    variant="secondary"
                    className="gap-2"
                  >
                    {analyzing && currentAction === 'generate_prompt' ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      <Sparkles className="w-4 h-4" />
                    )}
                    2. สร้าง Prompt
                  </Button>
                  <Button
                    onClick={() => handleAnalyze('generate_ea')}
                    disabled={analyzing || !selectedSession.strategy_prompt}
                    variant="secondary"
                    className="gap-2"
                  >
                    {analyzing && currentAction === 'generate_ea' ? (
                      <RefreshCw className="w-4 h-4 animate-spin" />
                    ) : (
                      <FileCode className="w-4 h-4" />
                    )}
                    3. สร้าง EA
                  </Button>
                  {selectedSession.generated_ea_code && (
                    <Button onClick={handleDownloadEA} variant="outline" className="gap-2">
                      <Download className="w-4 h-4" />
                      Download .mq5
                    </Button>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Strategy Summary */}
            {selectedSession.strategy_summary && (
              <Collapsible open={expandedSections['summary']} onOpenChange={() => toggleSection('summary')}>
                <Card>
                  <CollapsibleTrigger asChild>
                    <CardHeader className="cursor-pointer hover:bg-muted/30 transition-colors pb-3">
                      <CardTitle className="text-base flex items-center gap-2">
                        {expandedSections['summary'] ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                        <Brain className="w-4 h-4" />
                        Strategy Summary
                      </CardTitle>
                    </CardHeader>
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <CardContent>
                      <pre className="whitespace-pre-wrap text-sm leading-relaxed font-mono bg-muted/30 p-4 rounded-lg max-h-96 overflow-y-auto">
                        {selectedSession.strategy_summary}
                      </pre>
                    </CardContent>
                  </CollapsibleContent>
                </Card>
              </Collapsible>
            )}

            {/* Editable Prompt */}
            {selectedSession.strategy_prompt && (
              <Collapsible open={expandedSections['prompt']} onOpenChange={() => toggleSection('prompt')}>
                <Card>
                  <CollapsibleTrigger asChild>
                    <CardHeader className="cursor-pointer hover:bg-muted/30 transition-colors pb-3">
                      <CardTitle className="text-base flex items-center gap-2">
                        {expandedSections['prompt'] ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                        <Sparkles className="w-4 h-4" />
                        Generated Prompt
                        <Badge variant="outline" className="text-xs ml-2">แก้ไขได้</Badge>
                      </CardTitle>
                    </CardHeader>
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <CardContent className="space-y-3">
                      <Textarea
                        value={editablePrompt}
                        onChange={(e) => setEditablePrompt(e.target.value)}
                        className="min-h-[300px] font-mono text-sm"
                      />
                      <div className="flex justify-end gap-2">
                        <Button variant="outline" size="sm" onClick={() => setEditablePrompt(selectedSession.strategy_prompt || '')}>
                          Reset
                        </Button>
                        <Button size="sm" onClick={handleSavePrompt}>
                          บันทึก Prompt
                        </Button>
                      </div>
                    </CardContent>
                  </CollapsibleContent>
                </Card>
              </Collapsible>
            )}

            {/* EA Code Preview */}
            {selectedSession.generated_ea_code && (
              <Collapsible open={expandedSections['code']} onOpenChange={() => toggleSection('code')}>
                <Card>
                  <CollapsibleTrigger asChild>
                    <CardHeader className="cursor-pointer hover:bg-muted/30 transition-colors pb-3">
                      <CardTitle className="text-base flex items-center justify-between">
                        <span className="flex items-center gap-2">
                          {expandedSections['code'] ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                          <FileCode className="w-4 h-4" />
                          Generated EA Code
                        </span>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => { e.stopPropagation(); handleCopyCode(selectedSession.generated_ea_code!); }}
                        >
                          {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                        </Button>
                      </CardTitle>
                    </CardHeader>
                  </CollapsibleTrigger>
                  <CollapsibleContent>
                    <CardContent>
                      <pre className="whitespace-pre-wrap text-xs leading-relaxed font-mono bg-muted/30 p-4 rounded-lg max-h-[500px] overflow-y-auto">
                        {selectedSession.generated_ea_code}
                      </pre>
                    </CardContent>
                  </CollapsibleContent>
                </Card>
              </Collapsible>
            )}

            {/* Orders Table */}
            <Card>
              <CardHeader className="pb-3">
                <CardTitle className="text-base flex items-center justify-between">
                  <span className="flex items-center gap-2">
                    <Eye className="w-4 h-4" />
                    Orders ({orders.length})
                  </span>
                  <Button size="sm" variant="outline" onClick={() => fetchOrders(selectedSession.id)}>
                    <RefreshCw className="w-4 h-4" />
                  </Button>
                </CardTitle>
              </CardHeader>
              <CardContent>
                {orders.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground text-sm">
                    <p>ยังไม่มีข้อมูล Orders</p>
                    <p className="text-xs mt-1">รอ EA Tracker ส่งข้อมูลเข้ามา</p>
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="text-xs">Ticket</TableHead>
                          <TableHead className="text-xs">Symbol</TableHead>
                          <TableHead className="text-xs">Type</TableHead>
                          <TableHead className="text-xs">Vol</TableHead>
                          <TableHead className="text-xs">Open</TableHead>
                          <TableHead className="text-xs">Close</TableHead>
                          <TableHead className="text-xs">P/L</TableHead>
                          <TableHead className="text-xs">Hold</TableHead>
                          <TableHead className="text-xs">Event</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {orders.slice(0, 50).map((o) => (
                          <TableRow key={o.id}>
                            <TableCell className="text-xs font-mono">{o.ticket}</TableCell>
                            <TableCell className="text-xs">{o.symbol}</TableCell>
                            <TableCell className="text-xs">
                              <Badge variant="outline" className={`text-xs ${
                                o.order_type === 'buy' ? 'text-green-400' : 'text-red-400'
                              }`}>
                                {o.order_type.toUpperCase()}
                              </Badge>
                            </TableCell>
                            <TableCell className="text-xs">{o.volume}</TableCell>
                            <TableCell className="text-xs font-mono">{o.open_price?.toFixed(5)}</TableCell>
                            <TableCell className="text-xs font-mono">{o.close_price?.toFixed(5) || '-'}</TableCell>
                            <TableCell className={`text-xs font-mono ${
                              o.profit > 0 ? 'text-green-400' : o.profit < 0 ? 'text-red-400' : ''
                            }`}>
                              {o.profit?.toFixed(2)}
                            </TableCell>
                            <TableCell className="text-xs">{formatDuration(o.holding_time_seconds)}</TableCell>
                            <TableCell className="text-xs">
                              <Badge variant="outline" className="text-xs">{o.event_type}</Badge>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                    {orders.length > 50 && (
                      <p className="text-xs text-muted-foreground text-center mt-2">
                        แสดง 50 จาก {orders.length} orders
                      </p>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          </>
        )}
      </div>

      {/* New Session Dialog */}
      <Dialog open={isNewSessionOpen} onOpenChange={setIsNewSessionOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>สร้าง Session ใหม่</DialogTitle>
            <DialogDescription>
              สร้าง Session สำหรับ track EA ตัวใหม่ จากนั้นตั้งค่าชื่อ Session นี้ใน EA Tracker
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Session Name</Label>
              <Input
                value={newSessionName}
                onChange={(e) => setNewSessionName(e.target.value)}
                placeholder="เช่น Gold EA Test #1"
              />
            </div>
            <div>
              <Label>Magic Number (0 = Track All)</Label>
              <Input
                value={newMagicNumber}
                onChange={(e) => setNewMagicNumber(e.target.value)}
                placeholder="0"
                type="number"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsNewSessionOpen(false)}>ยกเลิก</Button>
            <Button onClick={handleCreateSession}>สร้าง Session</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default StrategyLab;
