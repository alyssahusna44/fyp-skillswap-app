# UniKL TutorFind – Final Year Project by Azwin & Alyssa

**UniKL TutorFind** is a peer-to-peer skill-matching application developed as a Final Year Project for Universiti Kuala Lumpur. The app enables users to exchange skills by matching learners with tutors and communicating via in-app chat.

## Tech Stack

This project uses **Flutter** for the frontend and **Supabase** as the backend (an open-source Firebase alternative built on **PostgreSQL**). The backend manages user data, skill listings, chat functionality, and user reviews.

> ⚠️ **Note:** The backend services (including the Supabase database) are still under active development. Features and data structures may change as the project evolves.

## Database Structure

The database is designed using a relational schema and includes the following key tables:

- **users**: Stores user profile information.
- **skills**: Contains a list of skills available for teaching and learning.
- **user_skills**: A join table linking users with skills, specifying whether a user wants to teach or learn a skill.
- **chats** & **chat_members**: Manage chat sessions and participant membership.
- **messages**: Stores chat messages.
- **reviews**: Records user ratings and feedback.

The full SQL schema is available in the `schema.sql` file.

## Getting Started

To run this project locally:

1. Create a new project in [Supabase](https://supabase.com/).
2. Open the SQL editor in your Supabase dashboard and run the contents of `Supabase SQL Script.sql` to set up the tables.
3. Set up your Flutter environment.
4. Configure your environment variables using your Supabase API keys.

Refer to the **Software Requirements Specification (SRS)** document for full system requirements and architecture details.

## Contact

For any questions or collaborations, feel free to connect with the project team via [LinkedIn](https://www.linkedin.com/).
