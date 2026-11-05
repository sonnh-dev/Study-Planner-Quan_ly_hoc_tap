package com.duy.studyplanner.api.mindmap;

import com.duy.studyplanner.api.auth.UserRepository;
import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
import com.duy.studyplanner.api.subject.SubjectRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class MindmapController {
    private final MindmapNodeRepository nodes;
    private final SubjectRepository subjects;
    private final UserRepository users;

    public MindmapController(MindmapNodeRepository nodes, SubjectRepository subjects, UserRepository users) {
        this.nodes = nodes; this.subjects = subjects; this.users = users;
    }
    @GetMapping("/subjects/{subjectId}/mindmap")
    ApiResponse<List<MindmapResponse>> list(@AuthenticationPrincipal String email, @PathVariable UUID subjectId) {
        UUID userId = userId(email);
        requireSubject(subjectId, userId);
        return ApiResponse.success(nodes.findAllBySubjectIdAndUserIdAndDeletedFalse(subjectId, userId)
                .stream().map(MindmapResponse::from).toList());
    }
    @PutMapping("/mindmap/{id}")
    @Transactional
    ApiResponse<MindmapResponse> upsert(@AuthenticationPrincipal String email, @PathVariable UUID id,
            @Valid @RequestBody MindmapRequest request) {
        UUID userId = userId(email);
        lockSubject(request.subjectId(), userId);
        MindmapNodeEntity node = nodes.findById(id).map(existing -> {
            if (!existing.getUserId().equals(userId) || !existing.getSubjectId().equals(request.subjectId())) {
                throw new ApiException("01208", "Mindmap node not found", HttpStatus.NOT_FOUND);
            }
            if (existing.isDeleted()) {
                throw new ApiException("01210", "Mindmap node was deleted", HttpStatus.GONE);
            }
            return existing;
        }).orElseGet(() -> new MindmapNodeEntity(id, userId, request.subjectId(), null,
                request.title().trim(), request.content(), request.x(), request.y()));
        UUID parentId = resolveParent(request.parentId(), id, request.subjectId(), userId);
        node.update(request.subjectId(), parentId, request.title().trim(),
                request.content(), request.x(), request.y());
        return ApiResponse.success(MindmapResponse.from(nodes.save(node)));
    }

    @DeleteMapping("/subjects/{subjectId}/mindmap/{id}")
    @Transactional
    ApiResponse<Void> delete(@AuthenticationPrincipal String email, @PathVariable UUID subjectId, @PathVariable UUID id) {
        UUID userId = userId(email);
        lockSubject(subjectId, userId);
        nodes.findByIdAndUserId(id, userId)
                .filter(node -> node.getSubjectId().equals(subjectId) && !node.isDeleted())
                .ifPresent(node -> {
                    nodes.findAllBySubjectIdAndUserIdAndParentIdAndDeletedFalse(subjectId, userId, id)
                            .forEach(MindmapNodeEntity::detach);
                    node.markDeleted();
                });
        return ApiResponse.success(null);
    }

    private UUID resolveParent(UUID parentId, UUID id, UUID subjectId, UUID userId) {
        var visited = new HashSet<UUID>();
        visited.add(id);
        for (UUID ancestorId = parentId; ancestorId != null; ) {
            if (!visited.add(ancestorId)) {
                throw new ApiException("01209", "Mindmap connection would form a cycle", HttpStatus.BAD_REQUEST);
            }
            MindmapNodeEntity ancestor = nodes.findByIdAndUserId(ancestorId, userId)
                    .orElseThrow(() -> new ApiException("01208", "Parent mindmap node not found", HttpStatus.NOT_FOUND));
            if (!ancestor.getSubjectId().equals(subjectId)) {
                throw new ApiException("01209", "Invalid mindmap parent", HttpStatus.BAD_REQUEST);
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
    private void requireSubject(UUID subjectId, UUID userId) {
        if (subjects.findByIdAndUserIdAndDeletedFalse(subjectId, userId).isEmpty()) {
            throw new ApiException("01203", "Subject not found", HttpStatus.NOT_FOUND);
        }
    }
    private UUID userId(String email) {
        return users.findByEmail(email).orElseThrow(() ->
                new ApiException("01204", "User not found", HttpStatus.UNAUTHORIZED)).getId();
    }
    public record MindmapRequest(@NotNull UUID subjectId, UUID parentId, @NotBlank @Size(max = 160) String title,
            @Size(max = 5000) String content, double x, double y) {
        public MindmapRequest { if (content == null) content = ""; }
    }
    public record MindmapResponse(UUID id, UUID subjectId, UUID parentId, String title,
            String content, double x, double y) {
        static MindmapResponse from(MindmapNodeEntity node) {
            return new MindmapResponse(node.getId(), node.getSubjectId(), node.getParentId(),
                    node.getTitle(), node.getContent(), node.getPositionX(), node.getPositionY());
        }
    }
}
