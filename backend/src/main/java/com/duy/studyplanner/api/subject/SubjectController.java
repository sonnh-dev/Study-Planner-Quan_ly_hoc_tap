package com.duy.studyplanner.api.subject;

import com.duy.studyplanner.api.auth.UserRepository;
import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
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
@RequestMapping("/api/v1/subjects")
public class SubjectController {
    private final SubjectRepository subjects;
    private final UserRepository users;

    public SubjectController(SubjectRepository subjects, UserRepository users) {
        this.subjects = subjects;
        this.users = users;
    }

    @GetMapping
    ApiResponse<List<SubjectResponse>> list(@AuthenticationPrincipal String email) {
        UUID userId = userId(email);
        return ApiResponse.success(subjects.findAllByUserIdOrderByName(userId).stream()
                .map(SubjectResponse::from).toList());
    }

    @PutMapping("/{id}")
    ApiResponse<SubjectResponse> upsert(
            @AuthenticationPrincipal String email,
            @PathVariable UUID id,
            @Valid @RequestBody SubjectRequest request) {
        UUID userId = userId(email);
        SubjectEntity subject = subjects.findById(id)
                .map(existing -> {
                    if (!existing.getUserId().equals(userId)) {
                        throw new ApiException("01203", "Subject not found", HttpStatus.NOT_FOUND);
                    }
                    existing.update(request.name().trim(), request.color());
                    return existing;
                })
                .orElseGet(() -> new SubjectEntity(id, userId, request.name().trim(), request.color()));
        return ApiResponse.success(SubjectResponse.from(subjects.save(subject)));
    }

    private UUID userId(String email) {
        return users.findByEmail(email)
                .orElseThrow(() -> new ApiException("01204", "User not found", HttpStatus.UNAUTHORIZED))
                .getId();
    }

    public record SubjectRequest(@NotBlank @Size(max = 120) String name, @NotBlank @Size(max = 20) String color) {}
    public record SubjectResponse(UUID id, String name, String color, String updatedAt) {
        static SubjectResponse from(SubjectEntity subject) {
            return new SubjectResponse(subject.getId(), subject.getName(), subject.getColor(), subject.getUpdatedAt().toString());
        }
    }
}
