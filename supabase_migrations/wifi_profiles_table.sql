-- Create wifi_profiles table for storing user Wi-Fi credentials
CREATE TABLE IF NOT EXISTS wifi_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ssid TEXT NOT NULL,
    password TEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS wifi_profiles_user_id_idx ON wifi_profiles(user_id);
CREATE INDEX IF NOT EXISTS wifi_profiles_user_id_is_default_idx ON wifi_profiles(user_id, is_default);
CREATE INDEX IF NOT EXISTS wifi_profiles_user_id_ssid_idx ON wifi_profiles(user_id, ssid);

-- Enable Row Level Security
ALTER TABLE wifi_profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own Wi-Fi profiles" ON wifi_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own Wi-Fi profiles" ON wifi_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own Wi-Fi profiles" ON wifi_profiles
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own Wi-Fi profiles" ON wifi_profiles
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_wifi_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_wifi_profiles_updated_at_trigger
    BEFORE UPDATE ON wifi_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_wifi_profiles_updated_at();

-- Create function to ensure only one default profile per user
CREATE OR REPLACE FUNCTION ensure_single_default_wifi_profile()
RETURNS TRIGGER AS $$
BEGIN
    -- If this profile is being set as default
    IF NEW.is_default = TRUE THEN
        -- Unset all other default profiles for this user
        UPDATE wifi_profiles 
        SET is_default = FALSE 
        WHERE user_id = NEW.user_id 
        AND id != NEW.id 
        AND is_default = TRUE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to ensure only one default profile per user
CREATE TRIGGER ensure_single_default_wifi_profile_trigger
    BEFORE INSERT OR UPDATE ON wifi_profiles
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_default_wifi_profile();

-- Grant necessary permissions
GRANT ALL ON wifi_profiles TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
