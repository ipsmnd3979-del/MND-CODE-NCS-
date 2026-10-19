-- MND CODE — PostgreSQL schema (initial migration)
-- Run: psql "$DATABASE_URL" -f schema.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE user_role AS ENUM ('student', 'admin');
CREATE TYPE content_status AS ENUM ('draft', 'published');
CREATE TYPE course_level AS ENUM ('Beginner', 'Intermediate', 'Advanced');

CREATE TABLE users (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 80),
  email          citext UNIQUE NOT NULL,
  password_hash  text NOT NULL,                 -- Argon2id hash; never plain text
  role           user_role NOT NULL DEFAULT 'student',
  email_verified boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz
);

CREATE TABLE sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  ip          inet,
  user_agent  text
);
CREATE INDEX ON sessions (user_id);

CREATE TABLE courses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          text UNIQUE NOT NULL,
  title         text NOT NULL,
  category      text NOT NULL,
  level         course_level NOT NULL,
  short_desc    text NOT NULL,
  overview      text,
  meta          jsonb NOT NULL DEFAULT '{}',   -- audience, prerequisites, objectives, tools, faqs
  status        content_status NOT NULL DEFAULT 'draft',
  sort_order    int NOT NULL DEFAULT 0,
  seo_title     text,
  seo_desc      text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE modules (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  position    int NOT NULL,
  title       text NOT NULL,
  summary     text,
  key_terms   text[] NOT NULL DEFAULT '{}',
  is_project  boolean NOT NULL DEFAULT false,
  is_optional boolean NOT NULL DEFAULT false,
  UNIQUE (course_id, position)
);

CREATE TABLE lessons (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id   uuid NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
  position    int NOT NULL,
  slug        text NOT NULL,
  title       text NOT NULL,
  minutes_est int NOT NULL DEFAULT 35,
  content     jsonb NOT NULL DEFAULT '{}',   -- what, why, body, example, diagram, exercise, mistakes, summary, further
  status      content_status NOT NULL DEFAULT 'draft',
  published_at timestamptz,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (module_id, position),
  UNIQUE (module_id, slug)
);

CREATE TABLE quiz_questions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid REFERENCES lessons(id) ON DELETE CASCADE,
  module_id   uuid REFERENCES modules(id) ON DELETE CASCADE,
  prompt      text NOT NULL,
  options     jsonb NOT NULL,            -- ["A", "B", ...]
  answer_idx  int NOT NULL,
  explanation text NOT NULL,
  CHECK (lesson_id IS NOT NULL OR module_id IS NOT NULL)
);

CREATE TABLE enrollments (
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id   uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, course_id)
);

CREATE TABLE lesson_progress (
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id    uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  completed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);

CREATE TABLE quiz_attempts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id  uuid REFERENCES lessons(id) ON DELETE SET NULL,
  course_id  uuid REFERENCES courses(id) ON DELETE SET NULL,
  score      int NOT NULL CHECK (score >= 0),
  total      int NOT NULL CHECK (total > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON quiz_attempts (user_id, created_at DESC);

CREATE TABLE bookmarks (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id  uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);

CREATE TABLE contact_submissions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  email         citext NOT NULL,
  phone         text,
  course_interest text,
  subject       text NOT NULL,
  message       text NOT NULL CHECK (char_length(message) <= 2000),
  is_read       boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  purge_after   timestamptz NOT NULL DEFAULT now() + interval '18 months'  -- retention control
);

CREATE TABLE announcements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label      text,
  body       text NOT NULL,
  link_path  text CHECK (link_path IS NULL OR link_path LIKE '/%'),
  link_text  text,
  is_active  boolean NOT NULL DEFAULT false,
  starts_at  timestamptz,
  ends_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE audit_events (
  id         bigserial PRIMARY KEY,
  actor_id   uuid REFERENCES users(id) ON DELETE SET NULL,
  action     text NOT NULL,
  entity     text,
  entity_id  text,
  details    jsonb NOT NULL DEFAULT '{}',
  ip         inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON audit_events (created_at DESC);
