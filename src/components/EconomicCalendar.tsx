import { useState, useMemo, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { 
  Calendar, 
  Clock, 
  Globe, 
  AlertTriangle, 
  TrendingUp,
  RefreshCw,
  Search,
  Filter,
  Copy,
  Check,
  ExternalLink,
  Upload,
  FileJson,
  FileCode,
  Database
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { format, parseISO, isToday, isTomorrow } from 'date-fns';
import { th } from 'date-fns/locale';
import { supabase } from '@/integrations/supabase/client';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@/components/ui/tabs';

interface NewsEvent {
  title: string;
  country: string;
  date: string;
  impact: 'Low' | 'Medium' | 'High' | 'Holiday';
  forecast: string;
  previous: string;
}

interface EconomicCalendarProps {
  initialData?: NewsEvent[];
}

const COUNTRY_FLAGS: Record<string, string> = {
  USD: '🇺🇸',
  EUR: '🇪🇺',
  GBP: '🇬🇧',
  JPY: '🇯🇵',
  CHF: '🇨🇭',
  CAD: '🇨🇦',
  AUD: '🇦🇺',
  NZD: '🇳🇿',
  CNY: '🇨🇳',
};

const IMPACT_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  High: { bg: 'bg-red-500/20', text: 'text-red-400', border: 'border-red-500/50' },
  Medium: { bg: 'bg-orange-500/20', text: 'text-orange-400', border: 'border-orange-500/50' },
  Low: { bg: 'bg-yellow-500/20', text: 'text-yellow-400', border: 'border-yellow-500/50' },
  Holiday: { bg: 'bg-blue-500/20', text: 'text-blue-400', border: 'border-blue-500/50' },
};

const EconomicCalendar = ({ initialData }: EconomicCalendarProps) => {
  const { toast } = useToast();
  const [newsData, setNewsData] = useState<NewsEvent[]>(initialData || []);
  const [isLoading, setIsLoading] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCountries, setSelectedCountries] = useState<string[]>([]);
  const [selectedImpact, setSelectedImpact] = useState<string[]>(['High', 'Medium', 'Low', 'Holiday']);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<string | null>(null);
  const [dataSource, setDataSource] = useState<string>('loading');
  const [totalInCache, setTotalInCache] = useState<number>(0);
  const [importDialogOpen, setImportDialogOpen] = useState(false);
  const [importData, setImportData] = useState('');
  const [importFormat, setImportFormat] = useState<'json' | 'xml'>('xml');

  const countries = useMemo(() => {
    const uniqueCountries = [...new Set(newsData.map(n => n.country))];
    return uniqueCountries.sort();
  }, [newsData]);

  const filteredNews = useMemo(() => {
    return newsData.filter(news => {
      const matchesSearch = searchTerm === '' || 
        news.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        news.country.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesCountry = selectedCountries.length === 0 || 
        selectedCountries.includes(news.country);
      
      const matchesImpact = selectedImpact.includes(news.impact);
      
      return matchesSearch && matchesCountry && matchesImpact;
    });
  }, [newsData, searchTerm, selectedCountries, selectedImpact]);

  const groupedByDate = useMemo(() => {
    const groups: Record<string, NewsEvent[]> = {};
    
    filteredNews.forEach(news => {
      const dateKey = format(parseISO(news.date), 'yyyy-MM-dd');
      if (!groups[dateKey]) {
        groups[dateKey] = [];
      }
      groups[dateKey].push(news);
    });
    
    Object.keys(groups).forEach(key => {
      groups[key].sort((a, b) => 
        new Date(a.date).getTime() - new Date(b.date).getTime()
      );
    });
    
    return groups;
  }, [filteredNews]);

  // Fetch news from edge function
  const fetchNewsFromAPI = async (forceRefresh = false) => {
    setIsLoading(true);
    try {
      const refreshParam = forceRefresh ? '&refresh=true' : '';
      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/economic-news?format=raw&days=14${refreshParam}`;
      
      const res = await fetch(apiUrl, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      
      const data = await res.json();
      
      if (data.success && data.data && data.data.length > 0) {
        setNewsData(data.data);
        setLastUpdated(data.last_updated);
        setDataSource(data.source || 'api');
        setTotalInCache(data.total_in_cache || data.count);
        toast({
          title: "โหลดข้อมูลสำเร็จ",
          description: `${data.count} ข่าว จาก ${getSourceLabel(data.source)}`,
        });
      } else if (data.data && data.data.length === 0) {
        setDataSource(data.source || 'empty');
        toast({
          title: "ไม่พบข่าวในช่วงเวลานี้",
          description: "ลองใช้ปุ่ม Import เพื่อเพิ่มข่าวด้วยตนเอง",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error('Error fetching news:', error);
      toast({
        title: "เกิดข้อผิดพลาด",
        description: "ไม่สามารถโหลดข้อมูลข่าวได้ กรุณาลองใหม่",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const getSourceLabel = (source: string) => {
    switch (source) {
      case 'forex_factory_xml': return 'Forex Factory (XML)';
      case 'forex_factory': return 'Forex Factory';
      case 'manual_import': return 'Manual Import';
      case 'cache': return 'Cache';
      case 'fallback': return 'Fallback Data';
      default: return source;
    }
  };

  // Auto-fetch on mount
  useEffect(() => {
    fetchNewsFromAPI();
  }, []);

  const handleRefresh = async () => {
    await fetchNewsFromAPI(true);
  };

  const handleImport = async () => {
    if (!importData.trim()) {
      toast({
        title: "ไม่มีข้อมูล",
        description: "กรุณาวาง XML หรือ JSON data",
        variant: "destructive",
      });
      return;
    }

    setIsImporting(true);
    try {
      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/import-economic-news`;
      
      const res = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          format: importFormat,
          data: importData,
          clearExisting: false,
        }),
      });
      
      const result = await res.json();
      
      if (result.success) {
        toast({
          title: "Import สำเร็จ",
          description: `นำเข้า ${result.total_imported} ข่าวเรียบร้อย`,
        });
        setImportDialogOpen(false);
        setImportData('');
        // Refresh to show new data
        await fetchNewsFromAPI();
      } else {
        toast({
          title: "Import ล้มเหลว",
          description: result.error || "เกิดข้อผิดพลาดในการนำเข้าข้อมูล",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error('Import error:', error);
      toast({
        title: "เกิดข้อผิดพลาด",
        description: "ไม่สามารถนำเข้าข้อมูลได้",
        variant: "destructive",
      });
    } finally {
      setIsImporting(false);
    }
  };

  const handleCopyJSON = async () => {
    const jsonOutput = JSON.stringify(newsData, null, 2);
    await navigator.clipboard.writeText(jsonOutput);
    setCopiedId('json');
    toast({
      title: "คัดลอก JSON สำเร็จ",
      description: "ข้อมูลข่าวถูกคัดลอกไปยัง clipboard",
    });
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleCopyAPIEndpoint = async () => {
    const endpoint = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/economic-news`;
    await navigator.clipboard.writeText(endpoint);
    setCopiedId('api');
    toast({
      title: "คัดลอก API Endpoint สำเร็จ",
      description: "URL สำหรับเชื่อมต่อ EA ถูกคัดลอกแล้ว",
    });
    setTimeout(() => setCopiedId(null), 2000);
  };

  const formatDateHeader = (dateStr: string) => {
    const date = parseISO(dateStr + 'T00:00:00');
    
    if (isToday(date)) return 'วันนี้';
    if (isTomorrow(date)) return 'พรุ่งนี้';
    
    return format(date, 'EEEE d MMMM yyyy', { locale: th });
  };

  const toggleCountry = (country: string) => {
    setSelectedCountries(prev => 
      prev.includes(country) 
        ? prev.filter(c => c !== country)
        : [...prev, country]
    );
  };

  const toggleImpact = (impact: string) => {
    setSelectedImpact(prev => 
      prev.includes(impact) 
        ? prev.filter(i => i !== impact)
        : [...prev, impact]
    );
  };

  const highImpactCount = newsData.filter(n => n.impact === 'High').length;
  const mediumImpactCount = newsData.filter(n => n.impact === 'Medium').length;

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card className="bg-card/50">
          <CardContent className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/20">
                <Calendar className="w-5 h-5 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{newsData.length}</p>
                <p className="text-xs text-muted-foreground">ข่าวทั้งหมด</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-card/50">
          <CardContent className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-red-500/20">
                <AlertTriangle className="w-5 h-5 text-red-400" />
              </div>
              <div>
                <p className="text-2xl font-bold">{highImpactCount}</p>
                <p className="text-xs text-muted-foreground">High Impact</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-card/50">
          <CardContent className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-orange-500/20">
                <TrendingUp className="w-5 h-5 text-orange-400" />
              </div>
              <div>
                <p className="text-2xl font-bold">{mediumImpactCount}</p>
                <p className="text-xs text-muted-foreground">Medium Impact</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card className="bg-card/50">
          <CardContent className="p-4">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-green-500/20">
                <Database className="w-5 h-5 text-green-400" />
              </div>
              <div>
                <p className="text-2xl font-bold">{totalInCache}</p>
                <p className="text-xs text-muted-foreground">ใน Cache</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* API Integration Card */}
      <Card className="border-primary/30 bg-primary/5">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between flex-wrap gap-3">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/20">
                <ExternalLink className="w-5 h-5 text-primary" />
              </div>
              <div>
                <CardTitle className="text-lg">EA Integration API</CardTitle>
                <CardDescription>ใช้ API นี้เชื่อมต่อกับ News Filter ใน EA</CardDescription>
              </div>
            </div>
            <div className="flex gap-2">
              <Dialog open={importDialogOpen} onOpenChange={setImportDialogOpen}>
                <DialogTrigger asChild>
                  <Button variant="outline" size="sm">
                    <Upload className="w-4 h-4 mr-2" />
                    Import Data
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-2xl">
                  <DialogHeader>
                    <DialogTitle>Import Economic News</DialogTitle>
                    <DialogDescription>
                      วาง XML หรือ JSON data จาก Forex Factory
                    </DialogDescription>
                  </DialogHeader>
                  
                  <Tabs value={importFormat} onValueChange={(v) => setImportFormat(v as 'json' | 'xml')}>
                    <TabsList className="grid w-full grid-cols-2">
                      <TabsTrigger value="xml" className="flex items-center gap-2">
                        <FileCode className="w-4 h-4" />
                        XML
                      </TabsTrigger>
                      <TabsTrigger value="json" className="flex items-center gap-2">
                        <FileJson className="w-4 h-4" />
                        JSON
                      </TabsTrigger>
                    </TabsList>
                    
                    <TabsContent value="xml" className="space-y-4">
                      <div className="p-3 rounded-lg bg-muted text-sm">
                        <p className="font-medium mb-1">XML Source:</p>
                        <code className="text-primary">https://www.forexfactory.com/calendar.xml</code>
                      </div>
                      <Textarea
                        placeholder="วาง XML data ที่นี่... (เริ่มด้วย <weeklyevents>)"
                        value={importData}
                        onChange={(e) => setImportData(e.target.value)}
                        className="min-h-[300px] font-mono text-xs"
                      />
                    </TabsContent>
                    
                    <TabsContent value="json" className="space-y-4">
                      <div className="p-3 rounded-lg bg-muted text-sm">
                        <p className="font-medium mb-1">JSON Format:</p>
                        <code className="text-primary text-xs">
                          {'[{"title":"...", "country":"USD", "date":"...", "impact":"High", ...}]'}
                        </code>
                      </div>
                      <Textarea
                        placeholder='วาง JSON array ที่นี่... (เริ่มด้วย [{"title":...}])'
                        value={importData}
                        onChange={(e) => setImportData(e.target.value)}
                        className="min-h-[300px] font-mono text-xs"
                      />
                    </TabsContent>
                  </Tabs>
                  
                  <DialogFooter>
                    <Button variant="outline" onClick={() => setImportDialogOpen(false)}>
                      ยกเลิก
                    </Button>
                    <Button onClick={handleImport} disabled={isImporting}>
                      {isImporting ? (
                        <>
                          <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                          กำลังนำเข้า...
                        </>
                      ) : (
                        <>
                          <Upload className="w-4 h-4 mr-2" />
                          Import
                        </>
                      )}
                    </Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
              
              <Button 
                variant="outline" 
                size="sm"
                onClick={handleCopyAPIEndpoint}
              >
                {copiedId === 'api' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
                คัดลอก URL
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="p-3 rounded-lg bg-background/50 font-mono text-sm overflow-x-auto">
            GET {import.meta.env.VITE_SUPABASE_URL}/functions/v1/economic-news
          </div>
          <div className="flex items-center gap-4 mt-3 text-xs text-muted-foreground flex-wrap">
            <span>* ระบบอัพเดทอัตโนมัติทุก 1 ชั่วโมง จาก Forex Factory XML Feed</span>
            {lastUpdated && (
              <span className="text-primary">
                อัพเดทล่าสุด: {format(new Date(lastUpdated), 'HH:mm dd/MM/yyyy', { locale: th })}
              </span>
            )}
            {dataSource && dataSource !== 'loading' && (
              <Badge variant="outline" className="text-xs">
                {getSourceLabel(dataSource)}
              </Badge>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Filters */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="flex items-center gap-2">
              <Filter className="w-5 h-5" />
              ตัวกรอง
            </CardTitle>
            <div className="flex gap-2">
              <Button 
                variant="outline" 
                size="sm"
                onClick={handleCopyJSON}
              >
                {copiedId === 'json' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
                คัดลอก JSON
              </Button>
              <Button 
                variant="outline" 
                size="sm" 
                onClick={handleRefresh}
                disabled={isLoading}
              >
                <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
                รีเฟรช
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="ค้นหาข่าว..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
          
          {/* Impact Filter */}
          <div>
            <p className="text-sm font-medium mb-2">ระดับผลกระทบ</p>
            <div className="flex flex-wrap gap-2">
              {['High', 'Medium', 'Low', 'Holiday'].map(impact => (
                <Badge
                  key={impact}
                  variant="outline"
                  className={`cursor-pointer transition-colors ${
                    selectedImpact.includes(impact)
                      ? `${IMPACT_COLORS[impact].bg} ${IMPACT_COLORS[impact].text} ${IMPACT_COLORS[impact].border}`
                      : 'opacity-50'
                  }`}
                  onClick={() => toggleImpact(impact)}
                >
                  {impact}
                </Badge>
              ))}
            </div>
          </div>
          
          {/* Country Filter */}
          <div>
            <p className="text-sm font-medium mb-2">สกุลเงิน</p>
            <div className="flex flex-wrap gap-2">
              {countries.map(country => (
                <Badge
                  key={country}
                  variant="outline"
                  className={`cursor-pointer transition-colors ${
                    selectedCountries.length === 0 || selectedCountries.includes(country)
                      ? 'bg-secondary'
                      : 'opacity-50'
                  }`}
                  onClick={() => toggleCountry(country)}
                >
                  {COUNTRY_FLAGS[country] || '🌐'} {country}
                </Badge>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* News List */}
      <div className="space-y-6">
        {Object.keys(groupedByDate).sort().map(dateKey => (
          <div key={dateKey}>
            <div className="flex items-center gap-2 mb-3">
              <Calendar className="w-4 h-4 text-primary" />
              <h3 className="font-semibold text-primary">{formatDateHeader(dateKey)}</h3>
              <Badge variant="secondary" className="ml-2">
                {groupedByDate[dateKey].length} ข่าว
              </Badge>
            </div>
            
            <div className="space-y-2">
              {groupedByDate[dateKey].map((news, idx) => (
                <Card 
                  key={`${dateKey}-${idx}`}
                  className={`transition-all hover:border-primary/30 ${
                    news.impact === 'High' ? 'border-red-500/30' : ''
                  }`}
                >
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-start gap-3">
                        <div className="text-2xl">{COUNTRY_FLAGS[news.country] || '🌐'}</div>
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <p className="font-medium">{news.title}</p>
                            <Badge
                              variant="outline"
                              className={`${IMPACT_COLORS[news.impact].bg} ${IMPACT_COLORS[news.impact].text} ${IMPACT_COLORS[news.impact].border}`}
                            >
                              {news.impact}
                            </Badge>
                          </div>
                          <div className="flex items-center gap-4 text-sm text-muted-foreground">
                            <span className="flex items-center gap-1">
                              <Clock className="w-3 h-3" />
                              {format(parseISO(news.date), 'HH:mm')}
                            </span>
                            <span>{news.country}</span>
                          </div>
                        </div>
                      </div>
                      
                      {(news.forecast || news.previous) && (
                        <div className="flex gap-4 text-sm">
                          {news.forecast && (
                            <div className="text-right">
                              <p className="text-muted-foreground text-xs">Forecast</p>
                              <p className="font-medium text-primary">{news.forecast}</p>
                            </div>
                          )}
                          {news.previous && (
                            <div className="text-right">
                              <p className="text-muted-foreground text-xs">Previous</p>
                              <p className="font-medium">{news.previous}</p>
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        ))}
        
        {Object.keys(groupedByDate).length === 0 && (
          <Card>
            <CardContent className="py-8 text-center text-muted-foreground">
              <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
              <p>ไม่พบข่าวที่ตรงกับเงื่อนไข</p>
              <p className="text-sm mt-2">ลองใช้ปุ่ม "Import Data" เพื่อเพิ่มข่าวด้วยตนเอง</p>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
};

export default EconomicCalendar;
