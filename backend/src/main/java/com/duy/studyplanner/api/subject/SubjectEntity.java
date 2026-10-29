package com.duy.studyplanner.api.subject;

import com.duy.studyplanner.api.common.OwnedEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "subjects")
public class SubjectEntity extends OwnedEntity {
    @Column(nullable = false, length = 120)
    private String name;
    @Column(nullable = false, length = 20)
    private String color;
    protected SubjectEntity() {}
    public SubjectEntity(UUID id, UUID userId, String name, String color) {
        super(id, userId);
        this.name = name;
        this.color = color;
    }
    public String getName() { return name; }
    public String getColor() { return color; }
    public void update(String name, String color) { this.name = name; this.color = color; }
}
