CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL UNIQUE,
    video_id UUID NOT NULL,
    email VARCHAR(320) NOT NULL,
    status VARCHAR(20) NOT NULL,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_notifications_video ON notifications(video_id);
