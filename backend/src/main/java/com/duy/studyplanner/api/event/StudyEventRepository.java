package com.duy.studyplanner.api.event;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StudyEventRepository extends JpaRepository<StudyEventEntity, UUID> {
    List<StudyEventEntity> findAllByUserIdOrderByStartsAt(UUID userId);
    List<StudyEventEntity> findAllByUserIdAndDeletedFalseOrderByStartsAt(UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select event from StudyEventEntity event where event.id = :id")
    Optional<StudyEventEntity> lockById(@Param("id") UUID id);
}
