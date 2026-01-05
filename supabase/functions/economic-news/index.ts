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

// Parse impact from Forex Factory format
function parseImpact(impactClass: string): 'Low' | 'Medium' | 'High' | 'Holiday' {
  if (impactClass.includes('high') || impactClass.includes('red')) return 'High';
  if (impactClass.includes('medium') || impactClass.includes('orange')) return 'Medium';
  if (impactClass.includes('holiday') || impactClass.includes('gray')) return 'Holiday';
  return 'Low';
}

// Fetch news from Forex Factory calendar
async function fetchForexFactoryNews(): Promise<NewsEvent[]> {
  const news: NewsEvent[] = [];
  
  try {
    // Forex Factory Calendar URL (weekly view)
    const today = new Date();
    const weekStart = new Date(today);
    weekStart.setDate(today.getDate() - today.getDay()); // Start of week (Sunday)
    
    // We'll fetch 2 weeks of data
    const urls = [];
    for (let week = 0; week < 2; week++) {
      const weekDate = new Date(weekStart);
      weekDate.setDate(weekStart.getDate() + (week * 7));
      const monthStr = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'][weekDate.getMonth()];
      const dayStr = weekDate.getDate();
      const yearStr = weekDate.getFullYear();
      urls.push(`https://www.forexfactory.com/calendar?week=${monthStr}${dayStr}.${yearStr}`);
    }
    
    console.log('Fetching from Forex Factory...');
    
    for (const url of urls) {
      try {
        const response = await fetch(url, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        });
        
        if (!response.ok) {
          console.error(`Failed to fetch ${url}: ${response.status}`);
          continue;
        }
        
        const html = await response.text();
        
        // Parse the HTML to extract news events
        const eventRegex = /<tr[^>]*class="[^"]*calendar__row[^"]*"[^>]*>([\s\S]*?)<\/tr>/gi;
        const titleRegex = /<span[^>]*class="[^"]*calendar__event-title[^"]*"[^>]*>([^<]+)<\/span>/i;
        const currencyRegex = /<td[^>]*class="[^"]*calendar__currency[^"]*"[^>]*>([^<]+)<\/td>/i;
        const impactRegex = /<td[^>]*class="[^"]*calendar__impact[^"]*"[^>]*>[\s\S]*?<span[^>]*class="([^"]+)"[^>]*>/i;
        const forecastRegex = /<td[^>]*class="[^"]*calendar__forecast[^"]*"[^>]*>([^<]*)<\/td>/i;
        const previousRegex = /<td[^>]*class="[^"]*calendar__previous[^"]*"[^>]*>([^<]*)<\/td>/i;
        const dateRegex = /<td[^>]*class="[^"]*calendar__date[^"]*"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/i;
        const timeRegex = /<td[^>]*class="[^"]*calendar__time[^"]*"[^>]*>([^<]+)<\/td>/i;
        
        let match;
        let currentDate = '';
        
        while ((match = eventRegex.exec(html)) !== null) {
          const row = match[1];
          
          // Extract date (if present in this row)
          const dateMatch = row.match(dateRegex);
          if (dateMatch) {
            currentDate = dateMatch[1].trim();
          }
          
          // Extract title
          const titleMatch = row.match(titleRegex);
          if (!titleMatch) continue;
          
          const title = titleMatch[1].trim();
          
          // Extract currency
          const currencyMatch = row.match(currencyRegex);
          const currency = currencyMatch ? currencyMatch[1].trim() : 'USD';
          
          // Extract impact
          const impactMatch = row.match(impactRegex);
          const impact = impactMatch ? parseImpact(impactMatch[1]) : 'Low';
          
          // Extract forecast
          const forecastMatch = row.match(forecastRegex);
          const forecast = forecastMatch ? forecastMatch[1].trim() : '';
          
          // Extract previous
          const previousMatch = row.match(previousRegex);
          const previous = previousMatch ? previousMatch[1].trim() : '';
          
          // Extract time
          const timeMatch = row.match(timeRegex);
          const timeStr = timeMatch ? timeMatch[1].trim() : '00:00';
          
          // Build date string
          if (currentDate) {
            try {
              const eventDate = parseForexFactoryDate(currentDate, timeStr, today.getFullYear());
              if (eventDate) {
                news.push({
                  title,
                  country: currency,
                  date: eventDate.toISOString(),
                  impact,
                  forecast,
                  previous,
                });
              }
            } catch (e) {
              console.error('Error parsing date:', e);
            }
          }
        }
      } catch (fetchError) {
        console.error(`Error fetching ${url}:`, fetchError);
      }
    }
    
    console.log(`Parsed ${news.length} events from Forex Factory`);
    
  } catch (error) {
    console.error('Error fetching Forex Factory:', error);
  }
  
  return news;
}

// Parse Forex Factory date format (e.g., "Mon Jan 6")
function parseForexFactoryDate(dateStr: string, timeStr: string, year: number): Date | null {
  try {
    const months: Record<string, number> = {
      'Jan': 0, 'Feb': 1, 'Mar': 2, 'Apr': 3, 'May': 4, 'Jun': 5,
      'Jul': 6, 'Aug': 7, 'Sep': 8, 'Oct': 9, 'Nov': 10, 'Dec': 11
    };
    
    // Parse date like "Mon Jan 6" or "Jan 6"
    const parts = dateStr.split(/\s+/).filter(p => p.length > 0);
    let month = -1;
    let day = 0;
    
    for (const part of parts) {
      if (months[part] !== undefined) {
        month = months[part];
      } else if (/^\d+$/.test(part)) {
        day = parseInt(part, 10);
      }
    }
    
    if (month === -1 || day === 0) return null;
    
    // Parse time like "8:30am" or "10:00pm" or "All Day"
    let hours = 0;
    let minutes = 0;
    
    if (timeStr && timeStr !== 'All Day' && timeStr !== 'Tentative') {
      const timeMatch = timeStr.match(/(\d{1,2}):(\d{2})(am|pm)?/i);
      if (timeMatch) {
        hours = parseInt(timeMatch[1], 10);
        minutes = parseInt(timeMatch[2], 10);
        if (timeMatch[3]?.toLowerCase() === 'pm' && hours < 12) hours += 12;
        if (timeMatch[3]?.toLowerCase() === 'am' && hours === 12) hours = 0;
      }
    }
    
    // Create date in EST timezone (Forex Factory uses EST)
    const date = new Date(Date.UTC(year, month, day, hours + 5, minutes)); // EST = UTC-5
    
    return date;
  } catch (e) {
    console.error('Date parse error:', e);
    return null;
  }
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
  const { data, error } = await supabase
    .from('economic_news_cache')
    .select('*')
    .gte('event_date', new Date().toISOString())
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
async function updateNewsCache(supabase: SupabaseClient, news: NewsEvent[]): Promise<void> {
  if (news.length === 0) {
    console.log('No news to cache');
    return;
  }
  
  // Delete old events (before today)
  const { error: deleteError } = await supabase
    .from('economic_news_cache')
    .delete()
    .lt('event_date', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());
    
  if (deleteError) {
    console.error('Error deleting old cache:', deleteError);
  }
  
  // Upsert new events
  const records = news.map(item => ({
    title: item.title,
    country: item.country,
    event_date: item.date,
    impact: item.impact,
    forecast: item.forecast,
    previous: item.previous,
    source: 'forex_factory',
    updated_at: new Date().toISOString(),
  }));
  
  const { error: upsertError } = await supabase
    .from('economic_news_cache')
    .upsert(records as any, { onConflict: 'title,country,event_date' });
    
  if (upsertError) {
    console.error('Error upserting cache:', upsertError);
  } else {
    console.log(`Cached ${records.length} news events`);
  }
  
  // Update metadata
  await supabase
    .from('economic_news_metadata')
    .upsert({
      id: 'main',
      last_updated: new Date().toISOString(),
      last_source: 'forex_factory',
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
    const days = parseInt(url.searchParams.get('days') || '7');
    const refresh = url.searchParams.get('refresh') === 'true';

    // Initialize Supabase client with service role for cache management
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let newsData: NewsEvent[] = [];
    let source = 'cache';

    // Check if we should refresh the cache
    const needsRefresh = refresh || await shouldRefreshCache(supabase);
    
    if (needsRefresh) {
      console.log('Refreshing news cache from Forex Factory...');
      const freshNews = await fetchForexFactoryNews();
      
      if (freshNews.length > 0) {
        await updateNewsCache(supabase, freshNews);
        newsData = freshNews;
        source = 'forex_factory';
      } else {
        // Fallback to cache if fetch failed
        newsData = await getNewsFromCache(supabase);
        if (newsData.length === 0) {
          newsData = FALLBACK_NEWS;
          source = 'fallback';
        }
      }
    } else {
      // Use cached data
      newsData = await getNewsFromCache(supabase);
      if (newsData.length === 0) {
        newsData = FALLBACK_NEWS;
        source = 'fallback';
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
      return newsDate >= now && newsDate <= endDate;
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
      .select('last_updated')
      .eq('id', 'main')
      .single();

    const metaInfo = metadata as { last_updated: string } | null;

    const response = {
      success: true,
      count: responseData.length,
      source,
      last_updated: metaInfo?.last_updated || new Date().toISOString(),
      next_update: new Date(Date.now() + 60 * 60 * 1000).toISOString(), // Next hour
      data: responseData,
    };

    console.log(`Returning ${responseData.length} news events (format: ${format}, source: ${source})`);

    return new Response(
      JSON.stringify(response),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
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
