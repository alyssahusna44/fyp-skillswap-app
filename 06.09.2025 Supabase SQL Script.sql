-- Create the users table to store user information
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email text UNIQUE NOT NULL,
  name text,
  location text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create the skills table to hold all skill names
CREATE TABLE skills (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text UNIQUE NOT NULL,
  category text
);

-- Create a junction table to link users and skills, specifying if the user can teach or learn a skill
-- This table handles the many-to-many relationship between users and skills
CREATE TABLE user_skills (
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  skill_id uuid REFERENCES skills(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('teach', 'learn')),
  PRIMARY KEY (user_id, skill_id, type)
);

-- Create the chats table to represent individual chat conversations
CREATE TABLE chats (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at timestamp with time zone DEFAULT now()
);

-- Create a junction table to link users to a chat, enabling multiple members in a single chat
CREATE TABLE chat_members (
  chat_id uuid REFERENCES chats(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (chat_id, user_id)
);

-- Create the messages table to store all chat messages
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id uuid REFERENCES chats(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES users(id) ON DELETE CASCADE,
  text text NOT NULL,
  sent_at timestamp with time zone DEFAULT now(),
  is_read boolean DEFAULT FALSE
);

-- Create the reviews table to store user ratings and comments
-- It links a reviewer to the user they are reviewing
CREATE TABLE reviews (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id uuid REFERENCES users(id) ON DELETE CASCADE,
  reviewed_user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now()
);

-- Optional: Create a function to update the `updated_at` column automatically
-- This is a common practice in PostgreSQL
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Optional: Add a trigger to the users table to call the update function on every update
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
