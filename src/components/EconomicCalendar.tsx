import { useState, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  Calendar, 
  Clock, 
  Globe, 
  AlertTriangle, 
  TrendingUp, 
  TrendingDown,
  RefreshCw,
  Search,
  Filter,
  Copy,
  Check,
  ExternalLink
} from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { format, parseISO, isToday, isTomorrow, addDays, startOfDay } from 'date-fns';
import { th } from 'date-fns/locale';

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

// Sample data from Forex Factory
const SAMPLE_NEWS_DATA: NewsEvent[] = [
  {"title":"BOJ Summary of Opinions","country":"JPY","date":"2025-12-28T18:50:00-05:00","impact":"Low","forecast":"","previous":""},
  {"title":"Pending Home Sales m/m","country":"USD","date":"2025-12-29T10:00:00-05:00","impact":"Medium","forecast":"1.0%","previous":"1.9%"},
  {"title":"Natural Gas Storage","country":"USD","date":"2025-12-29T12:00:00-05:00","impact":"Low","forecast":"-169B","previous":"-167B"},
  {"title":"Crude Oil Inventories","country":"USD","date":"2025-12-29T17:00:00-05:00","impact":"Low","forecast":"-2.0M","previous":"-1.3M"},
  {"title":"KOF Economic Barometer","country":"CHF","date":"2025-12-30T03:00:00-05:00","impact":"Low","forecast":"101.5","previous":"101.7"},
  {"title":"Spanish Flash CPI y/y","country":"EUR","date":"2025-12-30T03:00:00-05:00","impact":"Low","forecast":"2.8%","previous":"3.0%"},
  {"title":"HPI m/m","country":"USD","date":"2025-12-30T09:00:00-05:00","impact":"Low","forecast":"0.1%","previous":"0.0%"},
  {"title":"S&P/CS Composite-20 HPI y/y","country":"USD","date":"2025-12-30T09:00:00-05:00","impact":"Low","forecast":"1.1%","previous":"1.4%"},
  {"title":"Chicago PMI","country":"USD","date":"2025-12-30T09:45:00-05:00","impact":"Low","forecast":"39.8","previous":"36.3"},
  {"title":"FOMC Meeting Minutes","country":"USD","date":"2025-12-30T14:00:00-05:00","impact":"High","forecast":"","previous":""},
  {"title":"API Weekly Statistical Bulletin","country":"USD","date":"2025-12-30T16:30:00-05:00","impact":"Low","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"JPY","date":"2025-12-30T19:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Manufacturing PMI","country":"CNY","date":"2025-12-30T20:30:00-05:00","impact":"Medium","forecast":"49.2","previous":"49.2"},
  {"title":"Non-Manufacturing PMI","country":"CNY","date":"2025-12-30T20:30:00-05:00","impact":"Low","forecast":"49.6","previous":"49.5"},
  {"title":"RatingDog Manufacturing PMI","country":"CNY","date":"2025-12-30T20:45:00-05:00","impact":"Low","forecast":"49.8","previous":"49.9"},
  {"title":"German Bank Holiday","country":"EUR","date":"2025-12-31T02:02:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Unemployment Claims","country":"USD","date":"2025-12-31T08:30:00-05:00","impact":"High","forecast":"219K","previous":"214K"},
  {"title":"Crude Oil Inventories","country":"USD","date":"2025-12-31T10:30:00-05:00","impact":"Low","forecast":"0.5M","previous":"0.4M"},
  {"title":"Natural Gas Storage","country":"USD","date":"2025-12-31T12:00:00-05:00","impact":"Low","forecast":"-51B","previous":"-166B"},
  {"title":"Bank Holiday","country":"NZD","date":"2025-12-31T15:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"AUD","date":"2025-12-31T16:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"JPY","date":"2025-12-31T19:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"CNY","date":"2025-12-31T19:01:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"CHF","date":"2026-01-01T01:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"French Bank Holiday","country":"EUR","date":"2026-01-01T02:01:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"German Bank Holiday","country":"EUR","date":"2026-01-01T02:02:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Italian Bank Holiday","country":"EUR","date":"2026-01-01T02:03:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"GBP","date":"2026-01-01T03:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"CAD","date":"2026-01-01T08:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"USD","date":"2026-01-01T08:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"NZD","date":"2026-01-01T15:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"JPY","date":"2026-01-01T19:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"CNY","date":"2026-01-01T19:01:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Bank Holiday","country":"CHF","date":"2026-01-02T01:00:00-05:00","impact":"Holiday","forecast":"","previous":""},
  {"title":"Nationwide HPI m/m","country":"GBP","date":"2026-01-02T02:00:00-05:00","impact":"Low","forecast":"0.1%","previous":"0.3%"},
  {"title":"Spanish Manufacturing PMI","country":"EUR","date":"2026-01-02T03:15:00-05:00","impact":"Low","forecast":"51.2","previous":"51.5"},
  {"title":"Italian Manufacturing PMI","country":"EUR","date":"2026-01-02T03:45:00-05:00","impact":"Low","forecast":"50.0","previous":"50.6"},
  {"title":"French Final Manufacturing PMI","country":"EUR","date":"2026-01-02T03:50:00-05:00","impact":"Low","forecast":"50.6","previous":"50.6"},
  {"title":"German Final Manufacturing PMI","country":"EUR","date":"2026-01-02T03:55:00-05:00","impact":"Low","forecast":"47.7","previous":"47.7"},
  {"title":"Final Manufacturing PMI","country":"EUR","date":"2026-01-02T04:00:00-05:00","impact":"Low","forecast":"49.2","previous":"49.2"},
  {"title":"M3 Money Supply y/y","country":"EUR","date":"2026-01-02T04:00:00-05:00","impact":"Low","forecast":"2.7%","previous":"2.8%"},
  {"title":"Private Loans y/y","country":"EUR","date":"2026-01-02T04:00:00-05:00","impact":"Low","forecast":"2.8%","previous":"2.8%"},
  {"title":"Final Manufacturing PMI","country":"GBP","date":"2026-01-02T04:30:00-05:00","impact":"Low","forecast":"51.2","previous":"51.2"},
  {"title":"Manufacturing PMI","country":"CAD","date":"2026-01-02T09:30:00-05:00","impact":"Low","forecast":"","previous":"48.4"},
  {"title":"Final Manufacturing PMI","country":"USD","date":"2026-01-02T09:45:00-05:00","impact":"Low","forecast":"51.8","previous":"51.8"},
  {"title":"FOMC Member Paulson Speaks","country":"USD","date":"2026-01-03T10:15:00-05:00","impact":"Low","forecast":"","previous":""},
  {"title":"FOMC Member Paulson Speaks","country":"USD","date":"2026-01-03T14:30:00-05:00","impact":"Low","forecast":"","previous":""}
];

const EconomicCalendar = ({ initialData }: EconomicCalendarProps) => {
  const { toast } = useToast();
  const [newsData, setNewsData] = useState<NewsEvent[]>(initialData || SAMPLE_NEWS_DATA);
  const [isLoading, setIsLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCountries, setSelectedCountries] = useState<string[]>([]);
  const [selectedImpact, setSelectedImpact] = useState<string[]>(['High', 'Medium', 'Low', 'Holiday']);
  const [copiedId, setCopiedId] = useState<string | null>(null);

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
    
    // Sort each group by time
    Object.keys(groups).forEach(key => {
      groups[key].sort((a, b) => 
        new Date(a.date).getTime() - new Date(b.date).getTime()
      );
    });
    
    return groups;
  }, [filteredNews]);

  const handleRefresh = async () => {
    setIsLoading(true);
    // In production, this would fetch from the edge function
    await new Promise(resolve => setTimeout(resolve, 1000));
    toast({
      title: "รีเฟรชข้อมูลสำเร็จ",
      description: `โหลด ${newsData.length} ข่าวเรียบร้อย`,
    });
    setIsLoading(false);
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
    const endpoint = `${window.location.origin}/api/news`;
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
    const now = new Date();
    
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
              <div className="p-2 rounded-lg bg-blue-500/20">
                <Globe className="w-5 h-5 text-blue-400" />
              </div>
              <div>
                <p className="text-2xl font-bold">{countries.length}</p>
                <p className="text-xs text-muted-foreground">สกุลเงิน</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* API Integration Card */}
      <Card className="border-primary/30 bg-primary/5">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/20">
                <ExternalLink className="w-5 h-5 text-primary" />
              </div>
              <div>
                <CardTitle className="text-lg">EA Integration API</CardTitle>
                <CardDescription>ใช้ API นี้เชื่อมต่อกับ News Filter ใน EA</CardDescription>
              </div>
            </div>
            <Button 
              variant="outline" 
              size="sm"
              onClick={handleCopyAPIEndpoint}
            >
              {copiedId === 'api' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
              คัดลอก URL
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="p-3 rounded-lg bg-background/50 font-mono text-sm">
            GET https://lkbhomsulgycxawwlnfh.supabase.co/functions/v1/economic-news
          </div>
          <p className="text-xs text-muted-foreground mt-2">
            * ระบบ EA สามารถเรียก API นี้เพื่อรับข้อมูลข่าวในรูปแบบ JSON พร้อมใช้งานกับ News Filter
          </p>
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
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
};

export default EconomicCalendar;
