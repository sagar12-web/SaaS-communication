import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ReportRequest {
  type: 'weekly' | 'monthly' | 'custom';
  startDate?: string;
  endDate?: string;
  userId?: string;
  format?: 'json' | 'pdf' | 'csv';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { type, startDate, endDate, userId, format = 'json' }: ReportRequest = await req.json()

    // Calculate date range based on report type
    let reportStartDate = startDate;
    let reportEndDate = endDate;

    if (type === 'weekly') {
      const now = new Date();
      const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      reportStartDate = weekAgo.toISOString();
      reportEndDate = now.toISOString();
    } else if (type === 'monthly') {
      const now = new Date();
      const monthAgo = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate());
      reportStartDate = monthAgo.toISOString();
      reportEndDate = now.toISOString();
    }

    // Generate comprehensive report data
    const [ticketsData, contactsData, dealsData, appointmentsData] = await Promise.all([
      generateTicketReport(supabaseClient, reportStartDate, reportEndDate, userId),
      generateContactReport(supabaseClient, reportStartDate, reportEndDate, userId),
      generateDealReport(supabaseClient, reportStartDate, reportEndDate, userId),
      generateAppointmentReport(supabaseClient, reportStartDate, reportEndDate, userId),
    ]);

    const report = {
      meta: {
        type,
        startDate: reportStartDate,
        endDate: reportEndDate,
        generatedAt: new Date().toISOString(),
        userId,
      },
      summary: {
        totalTickets: ticketsData.total,
        resolvedTickets: ticketsData.resolved,
        newContacts: contactsData.new,
        totalRevenue: dealsData.revenue,
        appointmentsHeld: appointmentsData.completed,
      },
      tickets: ticketsData,
      contacts: contactsData,
      deals: dealsData,
      appointments: appointmentsData,
    };

    // Handle different output formats
    if (format === 'csv') {
      const csv = generateCsvReport(report);
      return new Response(csv, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="report-${type}-${Date.now()}.csv"`,
        },
      });
    }

    if (format === 'pdf') {
      // In a real implementation, you would generate a PDF using a library like Puppeteer
      // For now, return JSON with a note
      return new Response(
        JSON.stringify({
          ...report,
          note: 'PDF generation not implemented in demo. Use JSON or CSV format.',
        }),
        {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    return new Response(
      JSON.stringify(report),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    )
  } catch (error) {
    console.error('Error generating report:', error);
    return new Response(
      JSON.stringify({
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    )
  }
})

async function generateTicketReport(supabase: any, startDate: string, endDate: string, userId?: string) {
  let query = supabase
    .from('tickets')
    .select(`
      id,
      subject,
      status,
      priority,
      created_at,
      updated_at,
      customer:profiles!customer_id(name, email),
      assignedTo:profiles!assigned_to(name, email)
    `);

  if (startDate) query = query.gte('created_at', startDate);
  if (endDate) query = query.lte('created_at', endDate);
  if (userId) query = query.or(`customer_id.eq.${userId},assigned_to.eq.${userId}`);

  const { data, error } = await query;

  if (error) throw error;

  const total = data?.length || 0;
  const resolved = data?.filter((t: any) => t.status === 'resolved').length || 0;
  const byStatus = data?.reduce((acc: any, ticket: any) => {
    acc[ticket.status] = (acc[ticket.status] || 0) + 1;
    return acc;
  }, {}) || {};

  return {
    total,
    resolved,
    byStatus,
    details: data || [],
  };
}

async function generateContactReport(supabase: any, startDate: string, endDate: string, userId?: string) {
  let query = supabase
    .from('contacts')
    .select('*');

  if (startDate) query = query.gte('created_at', startDate);
  if (endDate) query = query.lte('created_at', endDate);
  if (userId) query = query.eq('created_by', userId);

  const { data, error } = await query;

  if (error) throw error;

  const total = data?.length || 0;
  const byStatus = data?.reduce((acc: any, contact: any) => {
    acc[contact.status] = (acc[contact.status] || 0) + 1;
    return acc;
  }, {}) || {};

  return {
    new: total,
    byStatus,
    details: data || [],
  };
}

async function generateDealReport(supabase: any, startDate: string, endDate: string, userId?: string) {
  let query = supabase
    .from('deals')
    .select(`
      *,
      contact:contacts(name, company)
    `);

  if (startDate) query = query.gte('created_at', startDate);
  if (endDate) query = query.lte('created_at', endDate);
  if (userId) query = query.eq('created_by', userId);

  const { data, error } = await query;

  if (error) throw error;

  const total = data?.length || 0;
  const revenue = data?.reduce((sum: number, deal: any) => sum + (deal.value || 0), 0) || 0;
  const won = data?.filter((d: any) => d.stage === 'closed-won').length || 0;
  const lost = data?.filter((d: any) => d.stage === 'closed-lost').length || 0;

  return {
    total,
    revenue,
    won,
    lost,
    conversionRate: total > 0 ? Math.round((won / total) * 100) : 0,
    details: data || [],
  };
}

async function generateAppointmentReport(supabase: any, startDate: string, endDate: string, userId?: string) {
  let query = supabase
    .from('appointments')
    .select('*');

  if (startDate) query = query.gte('start_time', startDate);
  if (endDate) query = query.lte('start_time', endDate);
  if (userId) query = query.eq('created_by', userId);

  const { data, error } = await query;

  if (error) throw error;

  const total = data?.length || 0;
  const completed = data?.filter((a: any) => a.status === 'completed').length || 0;
  const cancelled = data?.filter((a: any) => a.status === 'cancelled').length || 0;

  return {
    total,
    completed,
    cancelled,
    completionRate: total > 0 ? Math.round((completed / total) * 100) : 0,
    details: data || [],
  };
}

function generateCsvReport(report: any): string {
  const lines = [
    'Report Summary',
    `Type,${report.meta.type}`,
    `Generated At,${report.meta.generatedAt}`,
    `Start Date,${report.meta.startDate}`,
    `End Date,${report.meta.endDate}`,
    '',
    'Key Metrics',
    `Total Tickets,${report.summary.totalTickets}`,
    `Resolved Tickets,${report.summary.resolvedTickets}`,
    `New Contacts,${report.summary.newContacts}`,
    `Total Revenue,$${report.summary.totalRevenue}`,
    `Appointments Held,${report.summary.appointmentsHeld}`,
    '',
    'Ticket Details',
    'ID,Subject,Status,Priority,Created At,Customer,Assigned To',
  ];

  report.tickets.details.forEach((ticket: any) => {
    lines.push(`${ticket.id},${ticket.subject},${ticket.status},${ticket.priority},${ticket.created_at},${ticket.customer?.name || ''},${ticket.assignedTo?.name || ''}`);
  });

  return lines.join('\n');
}