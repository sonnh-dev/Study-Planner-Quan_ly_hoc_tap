package com.duy.studyplanner.api.auth;

import com.duy.studyplanner.api.common.ApiException;
import com.duy.studyplanner.api.common.ApiResponse;
import com.duy.studyplanner.api.config.JwtService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthController(UserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @PostMapping("/register")
    ApiResponse<AuthResult> register(@Valid @RequestBody AuthRequest request) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (users.existsByEmail(email)) {
            throw new ApiException("01201", "Email is already registered", HttpStatus.CONFLICT);
        }
        UserEntity user = users.save(new UserEntity(email, passwordEncoder.encode(request.password())));
        return ApiResponse.success(new AuthResult(jwtService.create(user.getEmail()), user.getEmail()));
    }

    @PostMapping("/login")
    ApiResponse<AuthResult> login(@Valid @RequestBody AuthRequest request) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        UserEntity user = users.findByEmail(email)
                .filter(found -> passwordEncoder.matches(request.password(), found.getPasswordHash()))
                .orElseThrow(() -> new ApiException("01202", "Email or password is incorrect", HttpStatus.UNAUTHORIZED));
        return ApiResponse.success(new AuthResult(jwtService.create(user.getEmail()), user.getEmail()));
    }

    public record AuthRequest(
            @NotBlank @Email @Size(max = 254) String email,
            @NotBlank @Size(min = 8, max = 72) String password) {}

    public record AuthResult(String token, String email) {}
}
