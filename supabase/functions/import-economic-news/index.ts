import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

interface NewsEvent {
  title: string;
  country: string;
  date: string;
  impact: 'Low' | 'Medium' | 'High' | 'Holiday';
  forecast: string;
  previous: string;
}

// Extract CDATA content or tag content from XML
function extractCDATA(xml: string, tagName: string): string {
  const cdataRegex = new RegExp(`<${tagName}>\\s*<!\\[CDATA\\[\\s*([\\s\\S]*?)\\s*\\]\\]>\\s*</${tagName}>`, 'i');
  const cdataMatch = xml.match(cdataRegex);
  if (cdataMatch) return cdataMatch[1].trim();
  
  const tagRegex = new RegExp(`<${tagName}>([^<]*)</${tagName}>`, 'i');
  const tagMatch = xml.match(tagRegex);
  if (tagMatch) return tagMatch[1].trim();
  
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
    const dateParts = dateStr.trim().split('-');
    if (dateParts.length !== 3) return new Date();
    
    const month = parseInt(dateParts[0], 10) - 1;
    const day = parseInt(dateParts[1], 10);
    const year = parseInt(dateParts[2], 10);
    
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
    
    // Convert ET to UTC (EST = UTC-5)
    const utcDate = new Date(Date.UTC(year, month, day, hours + 5, minutes));
    return utcDate;
  } catch (e) {
    return new Date();
  }
}

// Parse XML string to NewsEvent array
function parseXMLToEvents(xmlText: string): NewsEvent[] {
  const events: NewsEvent[] = [];
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
    
    if (!title || !country || !dateStr) continue;
    
    const eventDate = parseForexFactoryXMLDate(dateStr, timeStr);
    const impact = normalizeImpact(impactStr);
    
    events.push({
      title,
      country,
      date: eventDate.toISOString(),
      impact,
      forecast,
      previous,
    });
  }
  
  return events;
}

// Parse JSON array to NewsEvent array
function parseJSONToEvents(jsonData: any[]): NewsEvent[] {
  return jsonData.map(item => ({
    title: item.title || '',
    country: item.country || '',
    date: item.date ? new Date(item.date).toISOString() : new Date().toISOString(),
    impact: normalizeImpact(item.impact || 'Low'),
    forecast: item.forecast || '',
    previous: item.previous || '',
  })).filter(e => e.title && e.country);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { format, data, clearExisting } = body;
    
    if (!data) {
      return new Response(
        JSON.stringify({ success: false, error: 'No data provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    let events: NewsEvent[] = [];
    
    // Parse based on format
    if (format === 'xml') {
      console.log('Parsing XML data...');
      events = parseXMLToEvents(data);
    } else {
      // Default to JSON
      console.log('Parsing JSON data...');
      const jsonArray = typeof data === 'string' ? JSON.parse(data) : data;
      events = parseJSONToEvents(Array.isArray(jsonArray) ? jsonArray : [jsonArray]);
    }
    
    console.log(`Parsed ${events.length} events from ${format || 'json'} data`);
    
    if (events.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No valid events found in data' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Clear existing if requested
    if (clearExisting) {
      console.log('Clearing existing cache...');
      const { error: deleteError } = await supabase
        .from('economic_news_cache')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all
        
      if (deleteError) {
        console.error('Error clearing cache:', deleteError);
      }
    }
    
    // Prepare records for upsert
    const records = events.map(item => ({
      title: item.title,
      country: item.country,
      event_date: item.date,
      impact: item.impact,
      forecast: item.forecast || null,
      previous: item.previous || null,
      source: 'manual_import',
      updated_at: new Date().toISOString(),
    }));
    
    // Upsert in batches of 100
    const batchSize = 100;
    let totalUpserted = 0;
    let errors: string[] = [];
    
    for (let i = 0; i < records.length; i += batchSize) {
      const batch = records.slice(i, i + batchSize);
      const { error: upsertError } = await supabase
        .from('economic_news_cache')
        .upsert(batch as any, { onConflict: 'title,country,event_date' });
        
      if (upsertError) {
        console.error(`Error upserting batch ${i / batchSize}:`, upsertError);
        errors.push(upsertError.message);
      } else {
        totalUpserted += batch.length;
      }
    }
    
    // Update metadata
    await supabase
      .from('economic_news_metadata')
      .upsert({
        id: 'main',
        last_updated: new Date().toISOString(),
        last_source: 'manual_import',
        event_count: events.length,
        error_message: errors.length > 0 ? errors.join('; ') : null,
      } as any);
    
    console.log(`Successfully imported ${totalUpserted}/${events.length} events`);
    
    return new Response(
      JSON.stringify({
        success: true,
        message: `Successfully imported ${totalUpserted} events`,
        total_parsed: events.length,
        total_imported: totalUpserted,
        errors: errors.length > 0 ? errors : undefined,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    console.error('Import error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
