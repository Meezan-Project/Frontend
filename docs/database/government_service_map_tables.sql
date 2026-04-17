-- Future-ready schema for Government Service Map feature.
-- SQL is PostgreSQL-friendly and can be adapted for MySQL/SQL Server.

create table if not exists government_places (
  id bigserial primary key,
  external_id varchar(64) not null unique,
  source_type varchar(16) not null,
  source_numeric_id varchar(32) not null,
  name varchar(255) not null,
  category varchar(255) not null,
  type_key varchar(32) not null,
  lat double precision not null,
  lng double precision not null,
  address text,
  working_hours text,
  is_user_jurisdiction boolean not null default false,
  raw_tags_json jsonb,
  fetched_at_utc timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_government_places_type_key
  on government_places(type_key);

create index if not exists idx_government_places_geo
  on government_places(lat, lng);

create table if not exists user_favorite_government_places (
  id bigserial primary key,
  user_id bigint not null,
  government_place_id bigint not null references government_places(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, government_place_id)
);

create table if not exists user_recent_government_places (
  id bigserial primary key,
  user_id bigint not null,
  government_place_id bigint not null references government_places(id) on delete cascade,
  last_opened_at timestamptz not null default now(),
  unique (user_id, government_place_id)
);

create index if not exists idx_user_recent_places_user_last_opened
  on user_recent_government_places(user_id, last_opened_at desc);

create table if not exists government_place_search_logs (
  id bigserial primary key,
  user_id bigint,
  query_text varchar(255),
  selected_type_key varchar(32),
  favorites_only boolean not null default false,
  map_center_lat double precision,
  map_center_lng double precision,
  map_zoom numeric(5,2),
  searched_at_utc timestamptz not null default now()
);

create table if not exists government_place_feedback (
  id bigserial primary key,
  user_id bigint,
  government_place_id bigint references government_places(id) on delete set null,
  feedback_type varchar(32) not null,
  note text,
  created_at timestamptz not null default now()
);
