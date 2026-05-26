package com.kb.permission.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.util.List;

@Data
public class BatchPermissionRequest {
    @NotEmpty
    private List<@NotNull PermissionGrantRequest> permissions;
}
