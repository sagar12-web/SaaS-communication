/*
  # Scheduling and Appointments Schema

  1. New Tables
    - `appointments`
      - `id` (uuid, primary key)
      - `title` (text)
      - `description` (text)
      - `start_time` (timestamptz)
      - `end_time` (timestamptz)
      - `location` (text)
      - `meeting_link` (text, optional)
      - `type` (enum: meeting, call, demo, consultation)
      - `status` (enum: scheduled, confirmed, completed, cancelled)
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `appointment_attendees`
      - `id` (uuid, primary key)
      - `appointment_id` (uuid, references appointments)
      - `user_id` (uuid, references profiles)
      - `response` (enum: pending, accepted, declined)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for appointment management
*/

-- Create enums
CREATE TYPE appointment_type AS ENUM ('meeting', 'call', 'demo', 'consultation');
CREATE TYPE appointment_status AS ENUM ('scheduled', 'confirmed', 'completed', 'cancelled');
CREATE TYPE attendee_response AS ENUM ('pending', 'accepted', 'declined');

-- Create appointments table
CREATE TABLE IF NOT EXISTS appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text DEFAULT '',
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  location text DEFAULT '',
  meeting_link text,
  type appointment_type DEFAULT 'meeting',
  status appointment_status DEFAULT 'scheduled',
  created_by uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_time_range CHECK (end_time > start_time)
);

-- Create appointment_attendees table
CREATE TABLE IF NOT EXISTS appointment_attendees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid REFERENCES appointments(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  response attendee_response DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  UNIQUE(appointment_id, user_id)
);

-- Enable RLS
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_attendees ENABLE ROW LEVEL SECURITY;

-- Policies for appointments
CREATE POLICY "Users can read appointments they created or are invited to"
  ON appointments
  FOR SELECT
  TO authenticated
  USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM appointment_attendees 
      WHERE appointment_id = id AND user_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

CREATE POLICY "Users can create appointments"
  ON appointments
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update appointments they created"
  ON appointments
  FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

-- Policies for appointment_attendees
CREATE POLICY "Users can read attendees for their appointments"
  ON appointment_attendees
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM appointments 
      WHERE id = appointment_id AND created_by = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role IN ('admin', 'agent')
    )
  );

CREATE POLICY "Users can manage attendees for appointments they created"
  ON appointment_attendees
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM appointments 
      WHERE id = appointment_id AND created_by = auth.uid()
    )
  );

CREATE POLICY "Users can update their own response"
  ON appointment_attendees
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Triggers for updated_at
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes
CREATE INDEX idx_appointments_created_by ON appointments(created_by);
CREATE INDEX idx_appointments_start_time ON appointments(start_time);
CREATE INDEX idx_appointments_end_time ON appointments(end_time);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointment_attendees_appointment_id ON appointment_attendees(appointment_id);
CREATE INDEX idx_appointment_attendees_user_id ON appointment_attendees(user_id);