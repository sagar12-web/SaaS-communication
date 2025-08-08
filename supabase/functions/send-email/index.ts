import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  template?: string;
  templateData?: Record<string, any>;
}

interface EmailTemplate {
  subject: string;
  html: string;
  text: string;
}

const templates: Record<string, EmailTemplate> = {
  welcome: {
    subject: 'Welcome to CommHub!',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2563eb;">Welcome to CommHub!</h1>
        <p>Hi {{name}},</p>
        <p>Thank you for joining CommHub - your complete communication tools platform.</p>
        <p>You can now:</p>
        <ul>
          <li>Manage customer support tickets</li>
          <li>Track contacts and deals in CRM</li>
          <li>Schedule appointments and meetings</li>
          <li>View analytics and reports</li>
        </ul>
        <p>Get started by logging into your account:</p>
        <a href="{{loginUrl}}" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
          Login to CommHub
        </a>
        <p>Best regards,<br>The CommHub Team</p>
      </div>
    `,
    text: `Welcome to CommHub!\n\nHi {{name}},\n\nThank you for joining CommHub - your complete communication tools platform.\n\nYou can now manage customer support tickets, track contacts and deals in CRM, schedule appointments and meetings, and view analytics and reports.\n\nGet started by logging into your account: {{loginUrl}}\n\nBest regards,\nThe CommHub Team`
  },
  ticket_created: {
    subject: 'Support Ticket Created - #{{ticketId}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2563eb;">Support Ticket Created</h1>
        <p>Hi {{customerName}},</p>
        <p>Your support ticket has been created successfully.</p>
        <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 16px 0;">
          <h3 style="margin: 0 0 8px 0;">Ticket Details</h3>
          <p><strong>Ticket ID:</strong> #{{ticketId}}</p>
          <p><strong>Subject:</strong> {{subject}}</p>
          <p><strong>Priority:</strong> {{priority}}</p>
          <p><strong>Status:</strong> {{status}}</p>
        </div>
        <p>Our support team will review your ticket and respond as soon as possible.</p>
        <p>You can track the progress of your ticket in your dashboard.</p>
        <p>Best regards,<br>CommHub Support Team</p>
      </div>
    `,
    text: `Support Ticket Created - #{{ticketId}}\n\nHi {{customerName}},\n\nYour support ticket has been created successfully.\n\nTicket Details:\n- Ticket ID: #{{ticketId}}\n- Subject: {{subject}}\n- Priority: {{priority}}\n- Status: {{status}}\n\nOur support team will review your ticket and respond as soon as possible.\n\nBest regards,\nCommHub Support Team`
  },
  appointment_reminder: {
    subject: 'Appointment Reminder - {{title}}',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2563eb;">Appointment Reminder</h1>
        <p>Hi {{attendeeName}},</p>
        <p>This is a reminder about your upcoming appointment.</p>
        <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 16px 0;">
          <h3 style="margin: 0 0 8px 0;">Appointment Details</h3>
          <p><strong>Title:</strong> {{title}}</p>
          <p><strong>Date & Time:</strong> {{startTime}}</p>
          <p><strong>Duration:</strong> {{duration}}</p>
          <p><strong>Location:</strong> {{location}}</p>
          {{#if meetingLink}}
          <p><strong>Meeting Link:</strong> <a href="{{meetingLink}}">Join Meeting</a></p>
          {{/if}}
        </div>
        <p>{{#if description}}{{description}}{{/if}}</p>
        <p>Please make sure to join on time.</p>
        <p>Best regards,<br>CommHub Team</p>
      </div>
    `,
    text: `Appointment Reminder - {{title}}\n\nHi {{attendeeName}},\n\nThis is a reminder about your upcoming appointment.\n\nAppointment Details:\n- Title: {{title}}\n- Date & Time: {{startTime}}\n- Duration: {{duration}}\n- Location: {{location}}\n{{#if meetingLink}}- Meeting Link: {{meetingLink}}\n{{/if}}\n{{#if description}}\n{{description}}\n{{/if}}\nPlease make sure to join on time.\n\nBest regards,\nCommHub Team`
  },
  weekly_report: {
    subject: 'Weekly Performance Report',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2563eb;">Weekly Performance Report</h1>
        <p>Hi {{userName}},</p>
        <p>Here's your weekly performance summary:</p>
        <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 16px 0;">
          <h3 style="margin: 0 0 16px 0;">This Week's Highlights</h3>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
            <div>
              <p><strong>Tickets Resolved:</strong> {{ticketsResolved}}</p>
              <p><strong>New Contacts:</strong> {{newContacts}}</p>
            </div>
            <div>
              <p><strong>Meetings Held:</strong> {{meetingsHeld}}</p>
              <p><strong>Revenue Generated:</strong> ${{revenue}}</p>
            </div>
          </div>
        </div>
        <p>Keep up the great work!</p>
        <a href="{{dashboardUrl}}" style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
          View Full Report
        </a>
        <p>Best regards,<br>CommHub Analytics Team</p>
      </div>
    `,
    text: `Weekly Performance Report\n\nHi {{userName}},\n\nHere's your weekly performance summary:\n\nThis Week's Highlights:\n- Tickets Resolved: {{ticketsResolved}}\n- New Contacts: {{newContacts}}\n- Meetings Held: {{meetingsHeld}}\n- Revenue Generated: ${{revenue}}\n\nKeep up the great work!\n\nView Full Report: {{dashboardUrl}}\n\nBest regards,\nCommHub Analytics Team`
  }
};

function renderTemplate(template: string, data: Record<string, any>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return data[key] || match;
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, template, templateData = {} }: EmailRequest = await req.json()

    let emailSubject = subject;
    let emailHtml = html;
    let emailText = text;

    // Use template if specified
    if (template && templates[template]) {
      const tmpl = templates[template];
      emailSubject = renderTemplate(tmpl.subject, templateData);
      emailHtml = renderTemplate(tmpl.html, templateData);
      emailText = renderTemplate(tmpl.text, templateData);
    }

    // In a real implementation, you would integrate with an email service like:
    // - SendGrid
    // - Mailgun
    // - AWS SES
    // - Postmark
    // - Resend

    // For demo purposes, we'll just log the email
    console.log('Email sent:', {
      to,
      subject: emailSubject,
      html: emailHtml,
      text: emailText,
    });

    // Simulate email sending
    await new Promise(resolve => setTimeout(resolve, 1000));

    const data = {
      success: true,
      message: 'Email sent successfully',
      recipients: Array.isArray(to) ? to.length : 1,
    };

    return new Response(
      JSON.stringify(data),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  } catch (error) {
    console.error('Error sending email:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  }
})