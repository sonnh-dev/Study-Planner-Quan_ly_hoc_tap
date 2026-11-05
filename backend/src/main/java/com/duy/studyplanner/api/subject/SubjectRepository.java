package com.duy.studyplanner.api.subject;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface SubjectRepository extends JpaRepository<SubjectEntity, UUID> {
    List<SubjectEntity> findAllByUserIdOrderByName(UUID userId);
    List<SubjectEntity> findAllByUserIdAndDeletedFalseOrderByName(UUID userId);
    Optional<SubjectEntity> findByIdAndUserIdAndDeletedFalse(UUID id, UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select subject from SubjectEntity subject where subject.id = ?1")
    Optional<SubjectEntity> lockById(UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select subject from SubjectEntity subject where subject.id = ?1 and subject.userId = ?2")
    Optional<SubjectEntity> lockByIdAndUserId(UUID id, UUID userId);
}
