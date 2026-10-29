package com.duy.studyplanner.api.event;

import com.duy.studyplanner.api.common.OwnedEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "study_events")
public class StudyEventEntity extends OwnedEntity {
    @Column(nullable = false, length = 160)
    private String title;
    @Column(nullable = false, columnDefinition = "text")
    private String details;
    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;
    @Column(name = "ends_at", nullable = false)
    private Instant endsAt;
    @Column(name = "reminder_at")
    private Instant reminderAt;
    protected StudyEventEntity() {}
    public StudyEventEntity(UUID id, UUID userId, String title, String details, Instant startsAt, Instant endsAt, Instant reminderAt) {
        super(id, userId);
        this.title = title;
        this.details = details;
        this.startsAt = startsAt;
        this.endsAt = endsAt;
        this.reminderAt = reminderAt;
    }
    public String getTitle() { return title; }
    public String getDetails() { return details; }
    public Instant getStartsAt() { return startsAt; }
    public Instant getEndsAt() { return endsAt; }
    public Instant getReminderAt() { return reminderAt; }
    public void update(String title, String details, Instant startsAt, Instant endsAt, Instant reminderAt) {
        this.title = title; this.details = details; this.startsAt = startsAt; this.endsAt = endsAt; this.reminderAt = reminderAt;
    }
}
