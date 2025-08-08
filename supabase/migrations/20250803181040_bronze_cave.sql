/*
  # Fix Infinite Recursion in Appointment Policies

  1. Policy Updates
    - Remove circular dependencies between appointments and appointment_attendees
    - Create simpler, non-recursive policies
    - Maintain proper security without infinite loops

  2. Security Changes
    - Direct user ID checks without cross-table references
    - Separate policies for different access patterns
    - Clean policy logic without recursion
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Users can read appointments they created or are invited to" ON appointments;
DROP POLICY IF EXISTS "Users can manage attendees for appointments they created" ON appointment_attendees;
DROP POLICY IF EXISTS "Users can read attendees for their appointments" ON appointment_attendees;
DROP POLICY IF EXISTS "Users can update their own response" ON appointment_attendees;

-- Create new non-recursive policies for appointments
CREATE POLICY "Users can read their own appointments"
  ON appointments
  FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Admins and agents can read all appointments"
  ON appointments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'agent')
    )
  );

CREATE POLICY "Users can update their own appointments"
  ON appointments
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Admins and agents can update all appointments"
  ON appointments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'agent')
    )
  );

-- Create new non-recursive policies for appointment_attendees
CREATE POLICY "Users can read their own attendance"
  ON appointment_attendees
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Appointment creators can read attendees"
  ON appointment_attendees
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM appointments
      WHERE appointments.id = appointment_attendees.appointment_id
      AND appointments.created_by = auth.uid()
    )
  );

CREATE POLICY "Admins and agents can read all attendees"
  ON appointment_attendees
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'agent')
    )
  );

CREATE POLICY "Users can update their own response"
  ON appointment_attendees
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Appointment creators can manage attendees"
  ON appointment_attendees
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM appointments
      WHERE appointments.id = appointment_attendees.appointment_id
      AND appointments.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM appointments
      WHERE appointments.id = appointment_attendees.appointment_id
      AND appointments.created_by = auth.uid()
    )
  );

CREATE POLICY "Admins and agents can manage all attendees"
  ON appointment_attendees
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'agent')
    )
  );