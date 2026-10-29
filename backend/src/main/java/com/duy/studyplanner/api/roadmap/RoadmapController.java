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
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class RoadmapController {
    private final RoadmapNodeRepository nodes;
    private final SubjectRepository subjects;
    private final UserRepository users;

    public RoadmapController(RoadmapNodeRepository nodes, SubjectRepository subjects, UserRepository users) {
        this.nodes = nodes; this.subjects = subjects; this.users = users;
    }

    @GetMapping("/subjects/{subjectId}/roadmap")
    ApiResponse<List<RoadmapResponse>> list(@AuthenticationPrincipal String email, @PathVariable UUID subjectId) {
        UUID userId = userId(email);
        requireSubject(subjectId, userId);
        return ApiResponse.success(nodes.findAllBySubjectIdAndUserIdOrderBySortOrder(subjectId, userId)
                .stream().map(RoadmapResponse::from).toList());
    }

    @PutMapping("/roadmap/{id}")
    ApiResponse<RoadmapResponse> upsert(@AuthenticationPrincipal String email, @PathVariable UUID id,
            @Valid @RequestBody RoadmapRequest request) {
        UUID userId = userId(email);
        requireSubject(request.subjectId(), userId);
        if (request.parentId() != null) {
            RoadmapNodeEntity parent = nodes.findByIdAndUserId(request.parentId(), userId)
                    .orElseThrow(() -> new ApiException("01206", "Parent roadmap node not found", HttpStatus.NOT_FOUND));
            if (!parent.getSubjectId().equals(request.subjectId()) || parent.getId().equals(id)) {
                throw new ApiException("01207", "Invalid roadmap parent", HttpStatus.BAD_REQUEST);
            }
        }
        if (!List.of("planned", "in_progress", "done").contains(request.status())) {
            throw new ApiException("01103", "Invalid roadmap status", HttpStatus.BAD_REQUEST);
        }
        RoadmapNodeEntity node = nodes.findById(id).map(existing -> {
            if (!existing.getUserId().equals(userId)) throw new ApiException("01206", "Roadmap node not found", HttpStatus.NOT_FOUND);
            existing.update(request.subjectId(), request.parentId(), request.title().trim(), request.note(),
                    request.status(), request.sortOrder(), request.dueAt());
            return existing;
        }).orElseGet(() -> new RoadmapNodeEntity(id, userId, request.subjectId(), request.parentId(),
                request.title().trim(), request.note(), request.status(), request.sortOrder(), request.dueAt()));
        return ApiResponse.success(RoadmapResponse.from(nodes.save(node)));
    }

    private void requireSubject(UUID subjectId, UUID userId) {
        if (subjects.findByIdAndUserId(subjectId, userId).isEmpty()) {
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
            String note, String status, int sortOrder, Instant dueAt) {
        static RoadmapResponse from(RoadmapNodeEntity node) {
            return new RoadmapResponse(node.getId(), node.getSubjectId(), node.getParentId(),
                    node.getTitle(), node.getNote(), node.getStatus(), node.getSortOrder(), node.getDueAt());
        }
    }
}
