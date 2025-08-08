/*
  # CRM Contacts and Deals Schema

  1. New Tables
    - `contacts`
      - `id` (uuid, primary key)
      - `name` (text)
      - `email` (text, unique)
      - `phone` (text, optional)
      - `company` (text)
      - `position` (text)
      - `avatar` (text, optional)
      - `tags` (text array)
      - `last_contact` (timestamp)
      - `status` (enum: lead, prospect, customer, churned)
      - `source` (text)
      - `notes` (text)
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `deals`
      - `id` (uuid, primary key)
      - `title` (text)
      - `value` (decimal)
      - `stage` (enum: lead, qualified, proposal, negotiation, closed-won, closed-lost)
      - `probability` (integer, 0-100)
      - `contact_id` (uuid, references contacts)
      - `expected_close_date` (date)
      - `notes` (text)
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for CRM data access
*/

-- Create enums
CREATE TYPE contact_status AS ENUM ('lead', 'prospect', 'customer', 'churned');
CREATE TYPE deal_stage AS ENUM ('lead', 'qualified', 'proposal', 'negotiation', 'closed-won', 'closed-lost');

-- Create contacts table
CREATE TABLE IF NOT EXISTS contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  company text NOT NULL,
  position text NOT NULL,
  avatar text,
  tags text[] DEFAULT '{}',
  last_contact timestamptz DEFAULT now(),
  status contact_status DEFAULT 'lead',
  source text DEFAULT 'Manual',
  notes text DEFAULT '',
  created_by uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create deals table
CREATE TABLE IF NOT EXISTS deals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  value decimal(10,2) NOT NULL DEFAULT 0,
  stage deal_stage DEFAULT 'lead',
  probability integer DEFAULT 0 CHECK (probability >= 0 AND probability <= 100),
  contact_id uuid REFERENCES contacts(id) ON DELETE CASCADE NOT NULL,
  expected_close_date date,
  notes text DEFAULT '',
  created_by uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;

-- Policies for contacts
CREATE POLICY "Users can read all contacts"
  ON contacts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent', 'user')
    )
  );

CREATE POLICY "Users can create contacts"
  ON contacts
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update contacts they created"
  ON contacts
  FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

-- Policies for deals
CREATE POLICY "Users can read all deals"
  ON deals
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent', 'user')
    )
  );

CREATE POLICY "Users can create deals"
  ON deals
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update deals they created"
  ON deals
  FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

-- Triggers for updated_at
CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deals_updated_at BEFORE UPDATE ON deals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_company ON contacts(company);
CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_created_by ON contacts(created_by);
CREATE INDEX idx_deals_contact_id ON deals(contact_id);
CREATE INDEX idx_deals_stage ON deals(stage);
CREATE INDEX idx_deals_created_by ON deals(created_by);