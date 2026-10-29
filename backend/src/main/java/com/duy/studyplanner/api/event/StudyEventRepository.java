package com.duy.studyplanner.api.event;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StudyEventRepository extends JpaRepository<StudyEventEntity, UUID> {
    List<StudyEventEntity> findAllByUserIdOrderByStartsAt(UUID userId);
    Optional<StudyEventEntity> findByIdAndUserId(UUID id, UUID userId);
}
