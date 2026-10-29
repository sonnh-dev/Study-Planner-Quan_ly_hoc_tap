package com.duy.studyplanner.api.roadmap;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RoadmapNodeRepository extends JpaRepository<RoadmapNodeEntity, UUID> {
    List<RoadmapNodeEntity> findAllBySubjectIdAndUserIdOrderBySortOrder(UUID subjectId, UUID userId);
    Optional<RoadmapNodeEntity> findByIdAndUserId(UUID id, UUID userId);
}
