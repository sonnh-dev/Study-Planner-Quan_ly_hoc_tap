package com.duy.studyplanner.api.mindmap;

import com.duy.studyplanner.api.auth.UserRepository;
import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
import com.duy.studyplanner.api.subject.SubjectRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
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
        return ApiResponse.success(nodes.findAllBySubjectIdAndUserId(subjectId, userId).stream().map(MindmapResponse::from).toList());
    }
    @PutMapping("/mindmap/{id}")
    ApiResponse<MindmapResponse> upsert(@AuthenticationPrincipal String email, @PathVariable UUID id,
            @Valid @RequestBody MindmapRequest request) {
        UUID userId = userId(email);
        requireSubject(request.subjectId(), userId);
        if (request.parentId() != null) {
            MindmapNodeEntity parent = nodes.findByIdAndUserId(request.parentId(), userId)
                    .orElseThrow(() -> new ApiException("01208", "Parent mindmap node not found", HttpStatus.NOT_FOUND));
            if (!parent.getSubjectId().equals(request.subjectId()) || parent.getId().equals(id)) {
                throw new ApiException("01209", "Invalid mindmap parent", HttpStatus.BAD_REQUEST);
            }
        }
        MindmapNodeEntity node = nodes.findById(id).map(existing -> {
            if (!existing.getUserId().equals(userId)) throw new ApiException("01208", "Mindmap node not found", HttpStatus.NOT_FOUND);
            existing.update(request.subjectId(), request.parentId(), request.title().trim(),
                    request.content(), request.x(), request.y());
            return existing;
        }).orElseGet(() -> new MindmapNodeEntity(id, userId, request.subjectId(), request.parentId(),
                request.title().trim(), request.content(), request.x(), request.y()));
        return ApiResponse.success(MindmapResponse.from(nodes.save(node)));
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
