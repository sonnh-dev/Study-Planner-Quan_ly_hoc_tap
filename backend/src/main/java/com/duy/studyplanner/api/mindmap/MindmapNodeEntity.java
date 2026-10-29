package com.duy.studyplanner.api.mindmap;

import com.duy.studyplanner.api.common.OwnedEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "mindmap_nodes")
public class MindmapNodeEntity extends OwnedEntity {
    @Column(name = "subject_id", nullable = false)
    private UUID subjectId;
    @Column(name = "parent_id")
    private UUID parentId;
    @Column(nullable = false, length = 160)
    private String title;
    @Column(nullable = false, columnDefinition = "text")
    private String content;
    @Column(name = "position_x", nullable = false)
    private double positionX;
    @Column(name = "position_y", nullable = false)
    private double positionY;

    protected MindmapNodeEntity() {}
    public MindmapNodeEntity(UUID id, UUID userId, UUID subjectId, UUID parentId, String title,
            String content, double positionX, double positionY) {
        super(id, userId);
        this.subjectId = subjectId; this.parentId = parentId; this.title = title;
        this.content = content; this.positionX = positionX; this.positionY = positionY;
    }
    public UUID getSubjectId() { return subjectId; }
    public UUID getParentId() { return parentId; }
    public String getTitle() { return title; }
    public String getContent() { return content; }
    public double getPositionX() { return positionX; }
    public double getPositionY() { return positionY; }
    public void update(UUID subjectId, UUID parentId, String title, String content, double x, double y) {
        this.subjectId = subjectId; this.parentId = parentId; this.title = title;
        this.content = content; this.positionX = x; this.positionY = y;
    }
}
