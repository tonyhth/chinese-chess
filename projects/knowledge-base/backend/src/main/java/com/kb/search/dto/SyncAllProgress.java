package com.kb.search.dto;

import lombok.Data;

import java.time.Instant;
import java.util.List;

@Data
public class SyncAllProgress {
    private long total;
    private long synced;
    private double percent;
    private String status; // running | completed | failed
}
