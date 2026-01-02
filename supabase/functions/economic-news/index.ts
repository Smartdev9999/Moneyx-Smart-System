import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// News data structure for EA compatibility
interface NewsEvent {
  title: string;
  country: string;
  date: string;
  impact: 'Low' | 'Medium' | 'High' | 'Holiday';
  forecast: string;
  previous: string;
}

// Simplified format for EA consumption
interface EANewsFormat {
  title: string;
  currency: string;
  timestamp: number;          // Unix timestamp (seconds)
  timestamp_gmt: string;      // ISO 8601 GMT format
  impact_level: number;       // 0=Holiday, 1=Low, 2=Medium, 3=High
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

// Sample cached news data (in production, this would come from Forex Factory API or database)
const CACHED_NEWS: NewsEvent[] = [
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

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const format = url.searchParams.get('format') || 'ea'; // 'ea' or 'raw'
    const currency = url.searchParams.get('currency'); // Filter by currency
    const impact = url.searchParams.get('impact'); // Filter by impact level
    const days = parseInt(url.searchParams.get('days') || '7'); // Days from now

    let filteredNews = [...CACHED_NEWS];

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

    // Filter by date range (next N days)
    const now = new Date();
    const endDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
    filteredNews = filteredNews.filter(n => {
      const newsDate = new Date(n.date);
      return newsDate >= now && newsDate <= endDate;
    });

    // Sort by date
    filteredNews.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

    // Response format
    let responseData: NewsEvent[] | EANewsFormat[];
    if (format === 'raw') {
      responseData = filteredNews;
    } else {
      responseData = convertToEAFormat(filteredNews);
    }

    const response = {
      success: true,
      count: responseData.length,
      last_updated: new Date().toISOString(),
      data: responseData,
    };

    console.log(`Returning ${responseData.length} news events (format: ${format}, currency: ${currency || 'all'}, impact: ${impact || 'all'})`);

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
