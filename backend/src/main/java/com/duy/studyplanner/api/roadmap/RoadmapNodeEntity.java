package com.duy.studyplanner.api.roadmap;

import com.duy.studyplanner.api.common.OwnedEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "roadmap_nodes")
public class RoadmapNodeEntity extends OwnedEntity {
    @Column(name = "subject_id", nullable = false)
    private UUID subjectId;
    @Column(name = "parent_id")
    private UUID parentId;
    @Column(nullable = false, length = 160)
    private String title;
    @Column(nullable = false, columnDefinition = "text")
    private String note;
    @Column(nullable = false, length = 20)
    private String status;
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;
    @Column(name = "due_at")
    private Instant dueAt;

    protected RoadmapNodeEntity() {}
    public RoadmapNodeEntity(UUID id, UUID userId, UUID subjectId, UUID parentId, String title,
            String note, String status, int sortOrder, Instant dueAt) {
        super(id, userId);
        this.subjectId = subjectId; this.parentId = parentId; this.title = title;
        this.note = note; this.status = status; this.sortOrder = sortOrder; this.dueAt = dueAt;
    }
    public UUID getSubjectId() { return subjectId; }
    public UUID getParentId() { return parentId; }
    public String getTitle() { return title; }
    public String getNote() { return note; }
    public String getStatus() { return status; }
    public int getSortOrder() { return sortOrder; }
    public Instant getDueAt() { return dueAt; }
    public void update(UUID subjectId, UUID parentId, String title, String note, String status, int sortOrder, Instant dueAt) {
        this.subjectId = subjectId; this.parentId = parentId; this.title = title;
        this.note = note; this.status = status; this.sortOrder = sortOrder; this.dueAt = dueAt;
    }
}
