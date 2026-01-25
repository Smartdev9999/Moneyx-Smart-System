import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useToast } from '@/hooks/use-toast';
import { 
  Wallet,
  Plus,
  RefreshCw,
  Trash2,
  ArrowDownLeft,
  ArrowUpRight,
  Tag,
  ExternalLink,
  Loader2
} from 'lucide-react';

interface FundWallet {
  id: string;
  wallet_address: string;
  network: string;
  label: string | null;
  is_active: boolean;
  last_sync: string | null;
}

interface WalletTransaction {
  id: string;
  tx_hash: string;
  tx_type: string;
  amount: number;
  token_symbol: string | null;
  from_address: string | null;
  to_address: string | null;
  block_time: string;
  classification: string | null;
  notes: string | null;
  wallet_id: string;
}

interface TradingSystem {
  id: string;
  name: string;
}

interface FundManagementTabProps {
  customerId: string;
}

const classificationOptions = [
  { value: 'fund_deposit', label: 'ฝากเงิน', color: 'bg-green-500/20 text-green-400' },
  { value: 'fund_withdraw', label: 'ถอนเงิน', color: 'bg-red-500/20 text-red-400' },
  { value: 'profit_transfer', label: 'โอนกำไร', color: 'bg-blue-500/20 text-blue-400' },
  { value: 'invest_transfer', label: 'โอนลงทุน', color: 'bg-purple-500/20 text-purple-400' },
  { value: 'dividend', label: 'ปันผล', color: 'bg-yellow-500/20 text-yellow-400' },
];

export const FundManagementTab = ({ customerId }: FundManagementTabProps) => {
  const { toast } = useToast();
  const [wallets, setWallets] = useState<FundWallet[]>([]);
  const [transactions, setTransactions] = useState<WalletTransaction[]>([]);
  const [tradingSystems, setTradingSystems] = useState<TradingSystem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSyncing, setIsSyncing] = useState(false);
  
  // Add wallet dialog
  const [showAddWallet, setShowAddWallet] = useState(false);
  const [newWallet, setNewWallet] = useState({
    wallet_address: '',
    network: 'tron' as 'bsc' | 'tron',
    label: ''
  });
  const [isAddingWallet, setIsAddingWallet] = useState(false);
  
  // Classify dialog
  const [showClassifyDialog, setShowClassifyDialog] = useState(false);
  const [classifyingTx, setClassifyingTx] = useState<WalletTransaction | null>(null);
  const [classifyForm, setClassifyForm] = useState({
    classification: '',
    target_system_id: '',
    notes: ''
  });
  const [isClassifying, setIsClassifying] = useState(false);

  useEffect(() => {
    fetchData();
    fetchTradingSystems();
  }, [customerId]);

  const fetchData = async () => {
    setIsLoading(true);
    try {
      // Fetch wallets
      const { data: walletsData } = await supabase
        .from('fund_wallets')
        .select('*')
        .eq('customer_id', customerId)
        .order('created_at', { ascending: false });

      setWallets(walletsData || []);

      // Fetch transactions if wallets exist
      if (walletsData && walletsData.length > 0) {
        const walletIds = walletsData.map(w => w.id);
        const { data: txData } = await supabase
          .from('wallet_transactions')
          .select('*')
          .in('wallet_id', walletIds)
          .order('block_time', { ascending: false });

        setTransactions(txData || []);
      } else {
        setTransactions([]);
      }
    } catch (error) {
      console.error('Error fetching fund data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchTradingSystems = async () => {
    const { data } = await supabase
      .from('trading_systems')
      .select('id, name')
      .eq('is_active', true);
    
    setTradingSystems(data || []);
  };

  const handleAddWallet = async () => {
    if (!newWallet.wallet_address) {
      toast({
        variant: "destructive",
        title: "ข้อผิดพลาด",
        description: "กรุณากรอก Wallet Address",
      });
      return;
    }

    setIsAddingWallet(true);
    try {
      const { error } = await supabase
        .from('fund_wallets')
        .insert({
          customer_id: customerId,
          wallet_address: newWallet.wallet_address,
          network: newWallet.network,
          label: newWallet.label || null,
        });

      if (error) {
        if (error.code === '23505') {
          throw new Error('Wallet นี้มีอยู่ในระบบแล้ว');
        }
        throw error;
      }

      toast({
        title: "เพิ่ม Wallet สำเร็จ",
        description: "Wallet ถูกเพิ่มเข้าระบบแล้ว",
      });

      setShowAddWallet(false);
      setNewWallet({ wallet_address: '', network: 'tron', label: '' });
      fetchData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setIsAddingWallet(false);
    }
  };

  const handleDeleteWallet = async (walletId: string) => {
    try {
      const { error } = await supabase
        .from('fund_wallets')
        .delete()
        .eq('id', walletId);

      if (error) throw error;

      toast({
        title: "ลบ Wallet สำเร็จ",
        description: "Wallet และ Transactions ทั้งหมดถูกลบแล้ว",
      });

      fetchData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    }
  };

  const handleSyncWallet = async (wallet: FundWallet) => {
    setIsSyncing(true);
    try {
      const { data, error } = await supabase.functions.invoke('sync-wallet-transactions', {
        body: { wallet_id: wallet.id }
      });

      if (error) throw error;

      toast({
        title: "Sync สำเร็จ",
        description: `พบ ${data?.new_transactions || 0} transactions ใหม่`,
      });

      fetchData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "Sync ล้มเหลว",
        description: error.message,
      });
    } finally {
      setIsSyncing(false);
    }
  };

  const handleOpenClassify = (tx: WalletTransaction) => {
    setClassifyingTx(tx);
    setClassifyForm({
      classification: tx.classification || '',
      target_system_id: '',
      notes: tx.notes || ''
    });
    setShowClassifyDialog(true);
  };

  const handleSaveClassification = async () => {
    if (!classifyingTx) return;
    
    setIsClassifying(true);
    try {
      const { error } = await supabase
        .from('wallet_transactions')
        .update({
          classification: classifyForm.classification || null,
          target_system_id: classifyForm.target_system_id || null,
          notes: classifyForm.notes || null,
          classified_at: new Date().toISOString()
        })
        .eq('id', classifyingTx.id);

      if (error) throw error;

      toast({
        title: "บันทึกสำเร็จ",
        description: "จำแนก Transaction เรียบร้อยแล้ว",
      });

      setShowClassifyDialog(false);
      setClassifyingTx(null);
      fetchData();
    } catch (error: any) {
      toast({
        variant: "destructive",
        title: "เกิดข้อผิดพลาด",
        description: error.message,
      });
    } finally {
      setIsClassifying(false);
    }
  };

  const getClassificationBadge = (classification: string | null) => {
    if (!classification) {
      return <Badge variant="outline" className="text-gray-400">ยังไม่จำแนก</Badge>;
    }
    const option = classificationOptions.find(o => o.value === classification);
    return (
      <Badge className={option?.color || ''}>
        {option?.label || classification}
      </Badge>
    );
  };

  const shortenAddress = (address: string) => {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const getNetworkExplorer = (network: string, txHash: string) => {
    if (network === 'bsc') {
      return `https://bscscan.com/tx/${txHash}`;
    }
    return `https://tronscan.org/#/transaction/${txHash}`;
  };

  // Calculate summary
  const totalIn = transactions
    .filter(t => t.tx_type === 'in')
    .reduce((sum, t) => sum + t.amount, 0);
  const totalOut = transactions
    .filter(t => t.tx_type === 'out')
    .reduce((sum, t) => sum + t.amount, 0);
  const netBalance = totalIn - totalOut;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <RefreshCw className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="bg-green-500/10 border-green-500/30">
          <CardContent className="pt-4">
            <div className="flex items-center gap-2 text-green-400 text-sm mb-1">
              <ArrowDownLeft className="w-4 h-4" />
              Total Deposit
            </div>
            <p className="text-2xl font-bold text-green-400">${totalIn.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
          </CardContent>
        </Card>
        <Card className="bg-red-500/10 border-red-500/30">
          <CardContent className="pt-4">
            <div className="flex items-center gap-2 text-red-400 text-sm mb-1">
              <ArrowUpRight className="w-4 h-4" />
              Total Withdraw
            </div>
            <p className="text-2xl font-bold text-red-400">${totalOut.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
          </CardContent>
        </Card>
        <Card className={netBalance >= 0 ? 'bg-blue-500/10 border-blue-500/30' : 'bg-orange-500/10 border-orange-500/30'}>
          <CardContent className="pt-4">
            <div className={`flex items-center gap-2 ${netBalance >= 0 ? 'text-blue-400' : 'text-orange-400'} text-sm mb-1`}>
              <Wallet className="w-4 h-4" />
              Net Balance
            </div>
            <p className={`text-2xl font-bold ${netBalance >= 0 ? 'text-blue-400' : 'text-orange-400'}`}>
              ${netBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Wallets Section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Wallet className="w-5 h-5" />
              Crypto Wallets
            </CardTitle>
            <CardDescription>
              จัดการ Wallet Address สำหรับติดตาม USDT Transactions
            </CardDescription>
          </div>
          <Dialog open={showAddWallet} onOpenChange={setShowAddWallet}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="w-4 h-4 mr-2" />
                เพิ่ม Wallet
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>เพิ่ม Wallet</DialogTitle>
                <DialogDescription>
                  เพิ่ม Wallet Address เพื่อติดตาม USDT Transactions
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-4">
                <div className="space-y-2">
                  <Label>Wallet Address *</Label>
                  <Input
                    placeholder="0x... หรือ T..."
                    value={newWallet.wallet_address}
                    onChange={(e) => setNewWallet(prev => ({ ...prev, wallet_address: e.target.value }))}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Network *</Label>
                  <Select
                    value={newWallet.network}
                    onValueChange={(value) => setNewWallet(prev => ({ ...prev, network: value as 'bsc' | 'tron' }))}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="tron">TRON (TRC20)</SelectItem>
                      <SelectItem value="bsc">BSC (BEP20)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Label (Optional)</Label>
                  <Input
                    placeholder="e.g. Main Wallet"
                    value={newWallet.label}
                    onChange={(e) => setNewWallet(prev => ({ ...prev, label: e.target.value }))}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setShowAddWallet(false)}>ยกเลิก</Button>
                <Button onClick={handleAddWallet} disabled={isAddingWallet}>
                  {isAddingWallet ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : null}
                  เพิ่ม Wallet
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </CardHeader>
        <CardContent>
          {wallets.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Wallet className="w-12 h-12 mx-auto mb-2 opacity-50" />
              <p>ยังไม่มี Wallet</p>
              <p className="text-sm">คลิก "เพิ่ม Wallet" เพื่อเริ่มติดตาม</p>
            </div>
          ) : (
            <div className="space-y-4">
              {wallets.map((wallet) => (
                <div key={wallet.id} className="flex items-center justify-between p-4 rounded-lg border border-border bg-muted/30">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm">{shortenAddress(wallet.wallet_address)}</span>
                      <Badge variant="outline">{wallet.network.toUpperCase()}</Badge>
                      {wallet.label && <Badge variant="secondary">{wallet.label}</Badge>}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      Last sync: {wallet.last_sync ? new Date(wallet.last_sync).toLocaleString('th-TH') : 'Never'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button 
                      variant="outline" 
                      size="sm" 
                      onClick={() => handleSyncWallet(wallet)}
                      disabled={isSyncing}
                    >
                      <RefreshCw className={`w-3 h-3 mr-1 ${isSyncing ? 'animate-spin' : ''}`} />
                      Sync
                    </Button>
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button variant="outline" size="sm" className="text-red-500 border-red-500 hover:bg-red-500/10">
                          <Trash2 className="w-3 h-3" />
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>ยืนยันการลบ Wallet</AlertDialogTitle>
                          <AlertDialogDescription>
                            ลบ Wallet และ Transactions ทั้งหมด? การกระทำนี้ไม่สามารถยกเลิกได้
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>ยกเลิก</AlertDialogCancel>
                          <AlertDialogAction
                            className="bg-red-600 hover:bg-red-700"
                            onClick={() => handleDeleteWallet(wallet.id)}
                          >
                            ยืนยันลบ
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Transactions Section */}
      {transactions.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Transactions</CardTitle>
            <CardDescription>
              ประวัติ USDT Transactions ทั้งหมด (คลิกที่รายการเพื่อจำแนก)
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>TX Hash</TableHead>
                  <TableHead>เวลา</TableHead>
                  <TableHead>Classification</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {transactions.map((tx) => {
                  const wallet = wallets.find(w => w.id === tx.wallet_id);
                  return (
                    <TableRow key={tx.id} className="cursor-pointer hover:bg-muted/50" onClick={() => handleOpenClassify(tx)}>
                      <TableCell>
                        {tx.tx_type === 'in' ? (
                          <Badge className="bg-green-500/20 text-green-400">
                            <ArrowDownLeft className="w-3 h-3 mr-1" /> IN
                          </Badge>
                        ) : (
                          <Badge className="bg-red-500/20 text-red-400">
                            <ArrowUpRight className="w-3 h-3 mr-1" /> OUT
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell className="font-mono font-bold">
                        {tx.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })} {tx.token_symbol || 'USDT'}
                      </TableCell>
                      <TableCell>
                        <a
                          href={getNetworkExplorer(wallet?.network || 'tron', tx.tx_hash)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1 text-primary hover:underline"
                          onClick={(e) => e.stopPropagation()}
                        >
                          {shortenAddress(tx.tx_hash)}
                          <ExternalLink className="w-3 h-3" />
                        </a>
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {new Date(tx.block_time).toLocaleString('th-TH')}
                      </TableCell>
                      <TableCell>
                        {getClassificationBadge(tx.classification)}
                      </TableCell>
                      <TableCell className="text-right">
                        <Button variant="ghost" size="sm" onClick={(e) => { e.stopPropagation(); handleOpenClassify(tx); }}>
                          <Tag className="w-3 h-3 mr-1" /> จำแนก
                        </Button>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {/* Classify Dialog */}
      <Dialog open={showClassifyDialog} onOpenChange={setShowClassifyDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Tag className="w-5 h-5" />
              จำแนก Transaction
            </DialogTitle>
            <DialogDescription>
              TX: {classifyingTx?.tx_hash ? shortenAddress(classifyingTx.tx_hash) : ''}<br />
              Amount: {classifyingTx?.amount.toLocaleString('en-US', { minimumFractionDigits: 2 })} USDT
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label>Classification</Label>
              <Select
                value={classifyForm.classification}
                onValueChange={(value) => setClassifyForm(prev => ({ ...prev, classification: value }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="เลือกประเภท" />
                </SelectTrigger>
                <SelectContent>
                  {classificationOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            {(classifyForm.classification === 'invest_transfer' || classifyForm.classification === 'profit_transfer') && (
              <div className="space-y-2">
                <Label>Target Trading System</Label>
                <Select
                  value={classifyForm.target_system_id}
                  onValueChange={(value) => setClassifyForm(prev => ({ ...prev, target_system_id: value }))}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="เลือกระบบเทรด" />
                  </SelectTrigger>
                  <SelectContent>
                    {tradingSystems.map((sys) => (
                      <SelectItem key={sys.id} value={sys.id}>{sys.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
            <div className="space-y-2">
              <Label>Notes</Label>
              <Textarea
                placeholder="บันทึกเพิ่มเติม..."
                value={classifyForm.notes}
                onChange={(e) => setClassifyForm(prev => ({ ...prev, notes: e.target.value }))}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowClassifyDialog(false)}>ยกเลิก</Button>
            <Button onClick={handleSaveClassification} disabled={isClassifying}>
              {isClassifying ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : null}
              บันทึก
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default FundManagementTab;
