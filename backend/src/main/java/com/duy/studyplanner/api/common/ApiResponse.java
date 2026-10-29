package com.duy.studyplanner.api.common;

import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

public record ApiResponse<T>(String requestId, String errorCode, String errorMessage, T result) {
    public static <T> ApiResponse<T> success(T result) {
        var attributes = RequestContextHolder.getRequestAttributes();
        String requestId = attributes instanceof ServletRequestAttributes servletAttributes
                ? servletAttributes.getRequest().getHeader("X-Request-Id")
                : null;
        return new ApiResponse<>(requestId, "00000", "Success", result);
    }
}
