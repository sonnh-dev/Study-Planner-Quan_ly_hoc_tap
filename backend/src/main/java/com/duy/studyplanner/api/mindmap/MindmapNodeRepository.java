package com.duy.studyplanner.api.mindmap;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MindmapNodeRepository extends JpaRepository<MindmapNodeEntity, UUID> {
    List<MindmapNodeEntity> findAllBySubjectIdAndUserIdAndDeletedFalse(UUID subjectId, UUID userId);
    List<MindmapNodeEntity> findAllBySubjectIdAndUserIdAndParentIdAndDeletedFalse(
            UUID subjectId, UUID userId, UUID parentId);
    Optional<MindmapNodeEntity> findByIdAndUserId(UUID id, UUID userId);
}
