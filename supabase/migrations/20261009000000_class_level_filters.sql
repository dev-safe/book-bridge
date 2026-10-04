-- Class level, subject and school filters (#31).
--
-- Lookup tables instead of enums so the Francophone system (CP–CM2,
-- 6ème–Terminale) can be added later by inserting rows with a new `system`.
-- New listing FKs stay nullable: existing listings remain valid and simply
-- don't match level/subject/school filters until the seller edits them. The
-- app requires class level + subject on create/edit.
--
-- Admins add schools/subjects with plain SQL inserts; clients are read-only.

-- 1. Lookup tables -----------------------------------------------------------
create table if not exists public.class_levels (
  id         uuid primary key default gen_random_uuid(),
  system     text not null,
  code       text not null,
  label      text not null,
  sort_order integer not null,
  created_at timestamptz not null default now(),
  unique (system, code)
);

create table if not exists public.subjects (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.schools (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  town       text,
  region     text,
  created_at timestamptz not null default now()
);

create unique index if not exists schools_name_town_key
  on public.schools (lower(name), lower(coalesce(town, '')));
create index if not exists schools_lower_name_idx
  on public.schools (lower(name) text_pattern_ops);

alter table public.class_levels enable row level security;
alter table public.subjects enable row level security;
alter table public.schools enable row level security;

drop policy if exists "Class levels are public." on public.class_levels;
create policy "Class levels are public." on public.class_levels
  for select to anon, authenticated using (true);

drop policy if exists "Subjects are public." on public.subjects;
create policy "Subjects are public." on public.subjects
  for select to anon, authenticated using (true);

drop policy if exists "Schools are public." on public.schools;
create policy "Schools are public." on public.schools
  for select to anon, authenticated using (true);

revoke all on public.class_levels, public.subjects, public.schools
  from public, anon, authenticated;
grant select on public.class_levels, public.subjects, public.schools
  to anon, authenticated;

-- 2. Seeds -------------------------------------------------------------------
insert into public.class_levels (system, code, label, sort_order) values
  ('gce', 'class_1', 'Class 1', 10),
  ('gce', 'class_2', 'Class 2', 20),
  ('gce', 'class_3', 'Class 3', 30),
  ('gce', 'class_4', 'Class 4', 40),
  ('gce', 'class_5', 'Class 5', 50),
  ('gce', 'class_6', 'Class 6', 60),
  ('gce', 'form_1', 'Form 1', 110),
  ('gce', 'form_2', 'Form 2', 120),
  ('gce', 'form_3', 'Form 3', 130),
  ('gce', 'form_4', 'Form 4', 140),
  ('gce', 'form_5', 'Form 5', 150),
  ('gce', 'lower_sixth', 'Lower Sixth', 210),
  ('gce', 'upper_sixth', 'Upper Sixth', 220)
on conflict (system, code) do nothing;

insert into public.subjects (code, name, sort_order) values
  ('english_language', 'English Language', 10),
  ('literature_in_english', 'Literature in English', 20),
  ('french', 'French', 30),
  ('mathematics', 'Mathematics', 40),
  ('further_mathematics', 'Further Mathematics', 50),
  ('physics', 'Physics', 60),
  ('chemistry', 'Chemistry', 70),
  ('biology', 'Biology', 80),
  ('human_biology', 'Human Biology', 90),
  ('computer_science', 'Computer Science', 100),
  ('ict', 'ICT', 110),
  ('economics', 'Economics', 120),
  ('commerce', 'Commerce', 130),
  ('accounting', 'Accounting', 140),
  ('geography', 'Geography', 150),
  ('history', 'History', 160),
  ('citizenship', 'Citizenship', 170),
  ('religious_studies', 'Religious Studies', 180),
  ('philosophy', 'Philosophy', 190),
  ('geology', 'Geology', 200),
  ('food_science', 'Food Science and Nutrition', 210),
  ('agriculture', 'Agriculture', 220),
  ('physical_education', 'Physical Education', 230),
  ('general', 'General / Other', 1000)
on conflict (code) do nothing;

-- Starter list only; admins extend it with plain inserts.
insert into public.schools (name, town, region) values
  ('Saint Joseph''s College Sasse', 'Buea', 'South West'),
  ('Bishop Rogan College', 'Buea', 'South West'),
  ('Baptist High School Buea', 'Buea', 'South West'),
  ('Government Bilingual High School Molyko', 'Buea', 'South West'),
  ('Saker Baptist College', 'Limbe', 'South West'),
  ('Government High School Limbe', 'Limbe', 'South West'),
  ('Queen of the Rosary College Okoyong', 'Mamfe', 'South West'),
  ('Government Bilingual High School Kumba', 'Kumba', 'South West'),
  ('Sacred Heart College Mankon', 'Bamenda', 'North West'),
  ('Presbyterian Secondary School Mankon', 'Bamenda', 'North West'),
  ('Our Lady of Lourdes College Mankon', 'Bamenda', 'North West'),
  ('Government Bilingual High School Down Town', 'Bamenda', 'North West'),
  ('Cameroon College of Arts, Science and Technology', 'Bambili', 'North West'),
  ('Cameroon Protestant College', 'Bali', 'North West'),
  ('Saint Augustine''s College Nso', 'Kumbo', 'North West'),
  ('Government Bilingual High School Etoug-Ebe', 'Yaoundé', 'Centre'),
  ('Government Bilingual High School Deido', 'Douala', 'Littoral')
on conflict do nothing;

-- 3. Listing and profile FKs -------------------------------------------------
alter table public.listings
  add column if not exists class_level_id uuid
    references public.class_levels (id) on delete set null,
  add column if not exists subject_id uuid
    references public.subjects (id) on delete set null,
  add column if not exists school_id uuid
    references public.schools (id) on delete set null;

create index if not exists listings_class_level_id_idx
  on public.listings (class_level_id);
create index if not exists listings_subject_id_idx
  on public.listings (subject_id);
create index if not exists listings_school_id_idx
  on public.listings (school_id);

-- Self-declared default school for the sell form (not verified).
alter table public.profiles
  add column if not exists school_id uuid
    references public.schools (id) on delete set null;

-- 4. Client grants (column grants are additive to #60's lists) --------------
grant insert (class_level_id, subject_id, school_id),
      update (class_level_id, subject_id, school_id)
  on public.listings to authenticated;
grant update (school_id) on public.profiles to authenticated;
