package com.duy.studyplanner.api.roadmap;

import com.duy.studyplanner.api.auth.UserRepository;
import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
import com.duy.studyplanner.api.subject.SubjectRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class RoadmapController {
    private final RoadmapNodeRepository nodes;
    private final SubjectRepository subjects;
    private final UserRepository users;

    public RoadmapController(RoadmapNodeRepository nodes, SubjectRepository subjects, UserRepository users) {
        this.nodes = nodes; this.subjects = subjects; this.users = users;
    }

    @GetMapping("/subjects/{subjectId}/roadmap")
    ApiResponse<List<RoadmapResponse>> list(@AuthenticationPrincipal String email, @PathVariable UUID subjectId,
            @RequestParam(name = "includeDeleted", defaultValue = "false") boolean includeDeleted) {
        UUID userId = userId(email);
        if (subjects.findByIdAndUserIdAndDeletedFalse(subjectId, userId).isEmpty()) {
            throw new ApiException("01203", "Subject not found", HttpStatus.NOT_FOUND);
        }
        var rows = includeDeleted ? nodes.findAllBySubjectIdAndUserIdOrderBySortOrder(subjectId, userId)
                : nodes.findAllBySubjectIdAndUserIdAndDeletedFalseOrderBySortOrder(subjectId, userId);
        return ApiResponse.success(rows.stream().map(RoadmapResponse::from).toList());
    }

    @PutMapping("/roadmap/{id}")
    @Transactional
    ApiResponse<RoadmapResponse> upsert(@AuthenticationPrincipal String email, @PathVariable UUID id,
            @Valid @RequestBody RoadmapRequest request) {
        UUID userId = userId(email);
        lockSubject(request.subjectId(), userId);
        if (!List.of("planned", "in_progress", "done").contains(request.status())) {
            throw new ApiException("01103", "Invalid roadmap status", HttpStatus.BAD_REQUEST);
        }
        var existing = nodes.findById(id);
        existing.ifPresent(node -> {
            if (!node.getUserId().equals(userId) || !node.getSubjectId().equals(request.subjectId())) {
                throw new ApiException("01206", "Roadmap node not found", HttpStatus.NOT_FOUND);
            }
            if (node.isDeleted()) {
                throw new ApiException("01213", "Roadmap node was deleted", HttpStatus.GONE);
            }
        });
        UUID parentId = resolveParent(request.parentId(), id, request.subjectId(), userId);
        RoadmapNodeEntity node = existing.map(current -> {
            current.update(request.subjectId(), parentId, request.title().trim(), request.note(),
                    request.status(), request.sortOrder(), request.dueAt());
            return current;
        }).orElseGet(() -> new RoadmapNodeEntity(id, userId, request.subjectId(), parentId,
                request.title().trim(), request.note(), request.status(), request.sortOrder(), request.dueAt()));
        return ApiResponse.success(RoadmapResponse.from(nodes.save(node)));
    }

    @DeleteMapping("/subjects/{subjectId}/roadmap/{id}")
    @Transactional
    ApiResponse<Void> delete(@AuthenticationPrincipal String email, @PathVariable UUID subjectId,
            @PathVariable UUID id) {
        UUID userId = userId(email);
        subjects.lockByIdAndUserId(subjectId, userId).filter(subject -> !subject.isDeleted()).ifPresent(subject ->
                nodes.findByIdAndUserId(id, userId)
                        .filter(node -> node.getSubjectId().equals(subjectId) && !node.isDeleted())
                        .ifPresent(node -> {
                            nodes.findAllBySubjectIdAndUserIdAndParentIdAndDeletedFalse(subjectId, userId, id)
                                    .forEach(RoadmapNodeEntity::detach);
                            node.markDeleted();
                        }));
        return ApiResponse.success(null);
    }

    private UUID resolveParent(UUID parentId, UUID id, UUID subjectId, UUID userId) {
        var visited = new HashSet<UUID>();
        visited.add(id);
        for (UUID ancestorId = parentId; ancestorId != null; ) {
            if (!visited.add(ancestorId)) {
                throw new ApiException("01207", "Roadmap connection would form a cycle", HttpStatus.BAD_REQUEST);
            }
            var ancestor = nodes.findByIdAndUserId(ancestorId, userId)
                    .orElseThrow(() -> new ApiException("01206", "Parent roadmap node not found", HttpStatus.NOT_FOUND));
            if (!ancestor.getSubjectId().equals(subjectId)) {
                throw new ApiException("01207", "Invalid roadmap parent", HttpStatus.BAD_REQUEST);
            }
            if (ancestor.isDeleted()) return ancestorId.equals(parentId) ? null : parentId;
            ancestorId = ancestor.getParentId();
        }
        return parentId;
    }

    private void lockSubject(UUID subjectId, UUID userId) {
        if (subjects.lockByIdAndUserId(subjectId, userId).filter(subject -> !subject.isDeleted()).isEmpty()) {
            throw new ApiException("01203", "Subject not found", HttpStatus.NOT_FOUND);
        }
    }
    private UUID userId(String email) {
        return users.findByEmail(email).orElseThrow(() ->
                new ApiException("01204", "User not found", HttpStatus.UNAUTHORIZED)).getId();
    }
    public record RoadmapRequest(@NotNull UUID subjectId, UUID parentId,
            @NotBlank @Size(max = 160) String title, @Size(max = 5000) String note,
            @NotBlank String status, int sortOrder, Instant dueAt) {
        public RoadmapRequest { if (note == null) note = ""; if (status == null) status = "planned"; }
    }
    public record RoadmapResponse(UUID id, UUID subjectId, UUID parentId, String title,
            String note, String status, int sortOrder, Instant dueAt, boolean deleted) {
        static RoadmapResponse from(RoadmapNodeEntity node) {
            return new RoadmapResponse(node.getId(), node.getSubjectId(), node.getParentId(),
                    node.getTitle(), node.getNote(), node.getStatus(), node.getSortOrder(), node.getDueAt(), node.isDeleted());
        }
    }
}
