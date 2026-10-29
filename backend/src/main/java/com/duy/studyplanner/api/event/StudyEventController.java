package com.duy.studyplanner.api.event;

import com.duy.studyplanner.api.auth.UserRepository;
import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
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
@RequestMapping("/api/v1/events")
public class StudyEventController {
    private final StudyEventRepository events;
    private final UserRepository users;
    public StudyEventController(StudyEventRepository events, UserRepository users) {
        this.events = events; this.users = users;
    }
    @GetMapping
    ApiResponse<List<EventResponse>> list(@AuthenticationPrincipal String email) {
        UUID userId = userId(email);
        return ApiResponse.success(events.findAllByUserIdOrderByStartsAt(userId).stream().map(EventResponse::from).toList());
    }
    @PutMapping("/{id}")
    ApiResponse<EventResponse> upsert(@AuthenticationPrincipal String email, @PathVariable UUID id, @Valid @RequestBody EventRequest request) {
        if (!request.endsAt().isAfter(request.startsAt())) {
            throw new ApiException("01102", "End time must be after start time", HttpStatus.BAD_REQUEST);
        }
        UUID userId = userId(email);
        StudyEventEntity event = events.findById(id).map(existing -> {
            if (!existing.getUserId().equals(userId)) throw new ApiException("01205", "Event not found", HttpStatus.NOT_FOUND);
            existing.update(request.title().trim(), request.details(), request.startsAt(), request.endsAt(), request.reminderAt());
            return existing;
        }).orElseGet(() -> new StudyEventEntity(id, userId, request.title().trim(), request.details(),
                request.startsAt(), request.endsAt(), request.reminderAt()));
        return ApiResponse.success(EventResponse.from(events.save(event)));
    }
    private UUID userId(String email) {
        return users.findByEmail(email).orElseThrow(() -> new ApiException("01204", "User not found", HttpStatus.UNAUTHORIZED)).getId();
    }
    public record EventRequest(@NotBlank @Size(max = 160) String title, @Size(max = 5000) String details,
            @NotNull Instant startsAt, @NotNull Instant endsAt, Instant reminderAt) {
        public EventRequest { if (details == null) details = ""; }
    }
    public record EventResponse(UUID id, String title, String details, Instant startsAt, Instant endsAt, Instant reminderAt) {
        static EventResponse from(StudyEventEntity event) {
            return new EventResponse(event.getId(), event.getTitle(), event.getDetails(), event.getStartsAt(), event.getEndsAt(), event.getReminderAt());
        }
    }
}
