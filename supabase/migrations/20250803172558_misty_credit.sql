/*
  # Support Tickets Schema

  1. New Tables
    - `tickets`
      - `id` (uuid, primary key)
      - `subject` (text)
      - `message` (text)
      - `status` (enum: open, in-progress, resolved, closed)
      - `priority` (enum: low, medium, high, urgent)
      - `customer_id` (uuid, references profiles)
      - `assigned_to` (uuid, references profiles, optional)
      - `tags` (text array)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `ticket_messages`
      - `id` (uuid, primary key)
      - `ticket_id` (uuid, references tickets)
      - `sender_id` (uuid, references profiles)
      - `content` (text)
      - `message_type` (enum: text, file, image)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add appropriate policies for ticket management
*/

-- Create enums
CREATE TYPE ticket_status AS ENUM ('open', 'in-progress', 'resolved', 'closed');
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE message_type AS ENUM ('text', 'file', 'image');

-- Create tickets table
CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject text NOT NULL,
  message text NOT NULL,
  status ticket_status DEFAULT 'open',
  priority ticket_priority DEFAULT 'medium',
  customer_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  tags text[] DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create ticket_messages table
CREATE TABLE IF NOT EXISTS ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES tickets(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content text NOT NULL,
  message_type message_type DEFAULT 'text',
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;

-- Policies for tickets
CREATE POLICY "Users can read their own tickets"
  ON tickets
  FOR SELECT
  TO authenticated
  USING (
    customer_id = auth.uid() OR 
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

CREATE POLICY "Users can create tickets"
  ON tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Agents can update tickets"
  ON tickets
  FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

-- Policies for ticket_messages
CREATE POLICY "Users can read messages for their tickets"
  ON ticket_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tickets 
      WHERE id = ticket_id AND (
        customer_id = auth.uid() OR 
        assigned_to = auth.uid() OR
        EXISTS (
          SELECT 1 FROM profiles 
          WHERE id = auth.uid() AND role IN ('admin', 'agent')
        )
      )
    )
  );

CREATE POLICY "Users can create messages"
  ON ticket_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

-- Triggers for updated_at
CREATE TRIGGER update_tickets_updated_at BEFORE UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_priority ON tickets(priority);
CREATE INDEX idx_ticket_messages_ticket_id ON ticket_messages(ticket_id);