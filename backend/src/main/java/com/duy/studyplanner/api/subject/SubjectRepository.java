package com.duy.studyplanner.api.subject;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubjectRepository extends JpaRepository<SubjectEntity, UUID> {
    List<SubjectEntity> findAllByUserIdOrderByName(UUID userId);
    Optional<SubjectEntity> findByIdAndUserId(UUID id, UUID userId);
}
