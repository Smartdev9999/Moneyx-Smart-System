import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

// News data structure
interface NewsEvent {
  title: string;
  country: string;
  date: string;
  impact: 'Low' | 'Medium' | 'High' | 'Holiday';
  forecast: string;
  previous: string;
}

// Database cache structure
interface NewsCacheRow {
  id: string;
  title: string;
  country: string;
  event_date: string;
  impact: string;
  forecast: string | null;
  previous: string | null;
  actual: string | null;
  source: string;
  created_at: string;
  updated_at: string;
}

// Simplified format for EA consumption
interface EANewsFormat {
  title: string;
  currency: string;
  timestamp: number;
  timestamp_gmt: string;
  impact_level: number;
  impact: string;
  forecast: string;
  previous: string;
}

const IMPACT_TO_LEVEL: Record<string, number> = {
  'Holiday': 0,
  'Low': 1,
  'Medium': 2,
  'High': 3,
};

// Extract CDATA content or tag content from XML
function extractCDATA(xml: string, tagName: string): string {
  // Try CDATA first
  const cdataRegex = new RegExp(`<${tagName}>\\s*<!\\[CDATA\\[\\s*([\\s\\S]*?)\\s*\\]\\]>\\s*</${tagName}>`, 'i');
  const cdataMatch = xml.match(cdataRegex);
  if (cdataMatch) {
    return cdataMatch[1].trim();
  }
  
  // Try regular tag content
  const tagRegex = new RegExp(`<${tagName}>([^<]*)</${tagName}>`, 'i');
  const tagMatch = xml.match(tagRegex);
  if (tagMatch) {
    return tagMatch[1].trim();
  }
  
  // Check for empty/self-closing tag
  const emptyRegex = new RegExp(`<${tagName}\\s*/>`, 'i');
  if (emptyRegex.test(xml)) {
    return '';
  }
  
  return '';
}

// Normalize impact string
function normalizeImpact(impact: string): 'Low' | 'Medium' | 'High' | 'Holiday' {
  const normalized = impact.toLowerCase().trim();
  if (normalized === 'high' || normalized === 'red') return 'High';
  if (normalized === 'medium' || normalized === 'orange') return 'Medium';
  if (normalized === 'holiday') return 'Holiday';
  return 'Low';
}

// Parse Forex Factory XML date format: MM-DD-YYYY + 12hr time
function parseForexFactoryXMLDate(dateStr: string, timeStr: string): Date {
  try {
    // dateStr: "01-05-2026" (MM-DD-YYYY)
    const dateParts = dateStr.trim().split('-');
    if (dateParts.length !== 3) {
      console.warn(`Invalid date format: ${dateStr}`);
      return new Date();
    }
    
    const month = parseInt(dateParts[0], 10) - 1; // JS months are 0-indexed
    const day = parseInt(dateParts[1], 10);
    const year = parseInt(dateParts[2], 10);
    
    // Parse time: "3:00pm", "12:30am", etc
    let hours = 0;
    let minutes = 0;
    
    if (timeStr && timeStr.trim()) {
      const timeMatch = timeStr.trim().match(/(\d{1,2}):(\d{2})(am|pm)?/i);
      if (timeMatch) {
        hours = parseInt(timeMatch[1], 10);
        minutes = parseInt(timeMatch[2], 10);
        const period = timeMatch[3]?.toLowerCase();
        if (period === 'pm' && hours < 12) hours += 12;
        if (period === 'am' && hours === 12) hours = 0;
      }
    }
    
    // Fair Economy Media XML provides times in UTC directly
    // (verified by comparing with Forex Factory website in Bangkok timezone)
    const utcDate = new Date(Date.UTC(year, month, day, hours, minutes));
    
    console.log(`Date parsing: ${dateStr} ${timeStr} -> ${utcDate.toISOString()}`);
    
    return utcDate;
  } catch (e) {
    console.error('Error parsing date:', dateStr, timeStr, e);
    return new Date();
  }
}

// XML feed sources (Fair Economy Media mirrors Forex Factory data)
const XML_SOURCES = [
  'https://nfs.faireconomy.media/ff_calendar_thisweek.xml',
  'https://cdn-nfs.faireconomy.media/ff_calendar_thisweek.xml',
];

// Fetch and parse economic news XML feed
async function fetchForexFactoryXML(): Promise<{ news: NewsEvent[]; source: string }> {
  const news: NewsEvent[] = [];
  
  for (const xmlUrl of XML_SOURCES) {
    try {
      console.log(`Trying XML source: ${xmlUrl}`);
      
      const response = await fetch(xmlUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/xml, text/xml, */*',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      });
      
      console.log(`Response status: ${response.status} ${response.statusText}`);
      
      if (!response.ok) {
        console.warn(`Failed to fetch from ${xmlUrl}: ${response.status}`);
        continue;
      }
      
      const xmlText = await response.text();
      console.log(`Received XML (${xmlText.length} bytes)`);
      
      // Debug: Log first 500 chars
      if (xmlText.length < 100) {
        console.warn(`XML content too short: ${xmlText}`);
        continue;
      }
      
      // Parse each <event> block
      const eventRegex = /<event>([\s\S]*?)<\/event>/gi;
      let match;
      
      while ((match = eventRegex.exec(xmlText)) !== null) {
        const eventXml = match[1];
        
        const title = extractCDATA(eventXml, 'title');
        const country = extractCDATA(eventXml, 'country');
        const dateStr = extractCDATA(eventXml, 'date');
        const timeStr = extractCDATA(eventXml, 'time');
        const impactStr = extractCDATA(eventXml, 'impact');
        const forecast = extractCDATA(eventXml, 'forecast');
        const previous = extractCDATA(eventXml, 'previous');
        
        if (!title || !country || !dateStr) {
          continue;
        }
        
        const eventDate = parseForexFactoryXMLDate(dateStr, timeStr);
        const impact = normalizeImpact(impactStr);
        
        news.push({
          title,
          country,
          date: eventDate.toISOString(),
          impact,
          forecast,
          previous,
        });
      }
      
      console.log(`Parsed ${news.length} events from ${xmlUrl}`);
      
      if (news.length > 0) {
        const sourceName = xmlUrl.includes('cdn-') ? 'faireconomy_cdn' : 'faireconomy_xml';
        return { news, source: sourceName };
      }
      
    } catch (error) {
      console.error(`Error fetching from ${xmlUrl}:`, error);
    }
  }
  
  console.log('All XML sources failed, returning empty array');
  return { news: [], source: 'none' };
}

// Convert to EA-friendly format
function convertToEAFormat(news: NewsEvent[]): EANewsFormat[] {
  return news.map(item => {
    const date = new Date(item.date);
    return {
      title: item.title,
      currency: item.country,
      timestamp: Math.floor(date.getTime() / 1000),
      timestamp_gmt: date.toISOString(),
      impact_level: IMPACT_TO_LEVEL[item.impact] ?? 1,
      impact: item.impact,
      forecast: item.forecast,
      previous: item.previous,
    };
  });
}

// Get news from database cache
async function getNewsFromCache(supabase: SupabaseClient): Promise<NewsEvent[]> {
  // Get news from today onwards
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const { data, error } = await supabase
    .from('economic_news_cache')
    .select('*')
    .gte('event_date', today.toISOString())
    .order('event_date', { ascending: true });
    
  if (error) {
    console.error('Error fetching from cache:', error);
    return [];
  }
  
  const rows = data as NewsCacheRow[] | null;
  
  return (rows || []).map(item => ({
    title: item.title,
    country: item.country,
    date: item.event_date,
    impact: item.impact as 'Low' | 'Medium' | 'High' | 'Holiday',
    forecast: item.forecast || '',
    previous: item.previous || '',
  }));
}

// Update news cache in database
async function updateNewsCache(supabase: SupabaseClient, news: NewsEvent[], source: string): Promise<void> {
  if (news.length === 0) {
    console.log('No news to cache');
    return;
  }
  
  // Delete old events (before today)
  const today = new Date();
  today.setDate(today.getDate() - 1);
  
  const { error: deleteError } = await supabase
    .from('economic_news_cache')
    .delete()
    .lt('event_date', today.toISOString());
    
  if (deleteError) {
    console.error('Error deleting old cache:', deleteError);
  }
  
  // Prepare records for upsert
  const records = news.map(item => ({
    title: item.title,
    country: item.country,
    event_date: item.date,
    impact: item.impact,
    forecast: item.forecast || null,
    previous: item.previous || null,
    source: source,
    updated_at: new Date().toISOString(),
  }));
  
  // Upsert in batches of 100
  const batchSize = 100;
  let totalUpserted = 0;
  
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const { error: upsertError } = await supabase
      .from('economic_news_cache')
      .upsert(batch as any, { onConflict: 'title,country,event_date' });
      
    if (upsertError) {
      console.error(`Error upserting batch ${i / batchSize}:`, upsertError);
    } else {
      totalUpserted += batch.length;
    }
  }
  
  console.log(`Cached ${totalUpserted}/${records.length} news events`);
  
  // Update metadata
  await supabase
    .from('economic_news_metadata')
    .upsert({
      id: 'main',
      last_updated: new Date().toISOString(),
      last_source: source,
      event_count: news.length,
      error_message: null,
    } as any);
}

// Check if cache needs refresh (older than 1 hour)
async function shouldRefreshCache(supabase: SupabaseClient): Promise<boolean> {
  const { data } = await supabase
    .from('economic_news_metadata')
    .select('last_updated')
    .eq('id', 'main')
    .single();
    
  if (!data) return true;
  
  const metaData = data as { last_updated: string };
  const lastUpdated = new Date(metaData.last_updated);
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  
  return lastUpdated < oneHourAgo;
}

// Fallback static news data
const FALLBACK_NEWS: NewsEvent[] = [
  { title: "NFP (Non-Farm Payrolls)", country: "USD", date: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(), impact: "High", forecast: "", previous: "" },
  { title: "ECB Interest Rate Decision", country: "EUR", date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(), impact: "High", forecast: "", previous: "" },
  { title: "CPI y/y", country: "USD", date: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString(), impact: "High", forecast: "", previous: "" },
  { title: "Manufacturing PMI", country: "EUR", date: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(), impact: "Medium", forecast: "", previous: "" },
  { title: "Retail Sales m/m", country: "USD", date: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString(), impact: "Medium", forecast: "", previous: "" },
];

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const format = url.searchParams.get('format') || 'ea';
    const currency = url.searchParams.get('currency');
    const impact = url.searchParams.get('impact');
    const days = parseInt(url.searchParams.get('days') || '14');
    const refresh = url.searchParams.get('refresh') === 'true';
    const clearCache = url.searchParams.get('clear') === 'true';

    // Initialize Supabase client with service role for cache management
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Handle clear cache request - delete all records first
    if (clearCache) {
      console.log('Clearing all economic news cache...');
      const { error: clearError, count } = await supabase
        .from('economic_news_cache')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all
      
      if (clearError) {
        console.error('Error clearing cache:', clearError);
      } else {
        console.log(`Cleared cache (deleted records)`);
      }
    }

    let newsData: NewsEvent[] = [];
    let source = 'cache';

    // Check if we should refresh the cache
    const needsRefresh = refresh || clearCache || await shouldRefreshCache(supabase);
    
    if (needsRefresh) {
      console.log('Refreshing news cache from Fair Economy Media XML feed...');
      const { news: freshNews, source: fetchSource } = await fetchForexFactoryXML();
      
      if (freshNews.length > 0) {
        await updateNewsCache(supabase, freshNews, fetchSource);
        newsData = freshNews;
        source = fetchSource;
      } else {
        // Fallback to cache if fetch failed
        console.log('XML fetch returned 0 events, falling back to cache...');
        newsData = await getNewsFromCache(supabase);
        if (newsData.length === 0) {
          console.log('Cache is empty, using fallback data...');
          newsData = FALLBACK_NEWS;
          source = 'fallback';
        } else {
          source = 'cache';
        }
      }
    } else {
      // Use cached data
      newsData = await getNewsFromCache(supabase);
      if (newsData.length === 0) {
        console.log('Cache is empty, attempting XML fetch...');
        const { news: freshNews, source: fetchSource } = await fetchForexFactoryXML();
        if (freshNews.length > 0) {
          await updateNewsCache(supabase, freshNews, fetchSource);
          newsData = freshNews;
          source = fetchSource;
        } else {
          newsData = FALLBACK_NEWS;
          source = 'fallback';
        }
      }
    }

    // Apply filters
    let filteredNews = [...newsData];

    // Filter by currency
    if (currency) {
      const currencies = currency.toUpperCase().split(',');
      filteredNews = filteredNews.filter(n => currencies.includes(n.country));
    }

    // Filter by impact
    if (impact) {
      const impacts = impact.split(',').map(i => i.charAt(0).toUpperCase() + i.slice(1).toLowerCase());
      filteredNews = filteredNews.filter(n => impacts.includes(n.impact));
    }

    // Filter by date range
    const now = new Date();
    const endDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    filteredNews = filteredNews.filter(n => {
      const newsDate = new Date(n.date);
      return newsDate >= new Date(now.getTime() - 24 * 60 * 60 * 1000) && newsDate <= endDate;
    });

    // Sort by date
    filteredNews.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

    // Format response
    let responseData: NewsEvent[] | EANewsFormat[];
    if (format === 'raw') {
      responseData = filteredNews;
    } else {
      responseData = convertToEAFormat(filteredNews);
    }

    // Get last updated time
    const { data: metadata } = await supabase
      .from('economic_news_metadata')
      .select('last_updated, last_source, event_count')
      .eq('id', 'main')
      .single();

    const metaInfo = metadata as { last_updated: string; last_source: string; event_count: number } | null;

    const response = {
      success: true,
      count: responseData.length,
      total_in_cache: metaInfo?.event_count || newsData.length,
      source,
      last_updated: metaInfo?.last_updated || new Date().toISOString(),
      next_update: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      data: responseData,
    };

    console.log(`Returning ${responseData.length} news events (format: ${format}, source: ${source})`);

    return new Response(
      JSON.stringify(response),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300',
        },
      }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
