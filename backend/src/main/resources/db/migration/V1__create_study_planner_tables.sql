CREATE TABLE app_users (
    id UUID PRIMARY KEY,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE subjects (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    color VARCHAR(20) NOT NULL DEFAULT '#5685F7',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_subjects_user_updated ON subjects(user_id, updated_at);
CREATE TABLE study_events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    title VARCHAR(160) NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    reminder_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_study_event_duration CHECK (ends_at > starts_at)
);
CREATE INDEX idx_events_user_start ON study_events(user_id, starts_at);
CREATE TABLE roadmap_nodes (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES roadmap_nodes(id) ON DELETE CASCADE,
    title VARCHAR(160) NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'planned',
    sort_order INTEGER NOT NULL DEFAULT 0,
    due_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_roadmap_status CHECK (status IN ('planned', 'in_progress', 'done'))
);
CREATE INDEX idx_roadmap_subject_order ON roadmap_nodes(subject_id, parent_id, sort_order);
CREATE TABLE mindmap_nodes (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES mindmap_nodes(id) ON DELETE CASCADE,
    title VARCHAR(160) NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    position_x DOUBLE PRECISION NOT NULL DEFAULT 0,
    position_y DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mindmap_subject ON mindmap_nodes(subject_id);
