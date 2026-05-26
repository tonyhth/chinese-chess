package com.kb.search.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class SearchResponse {
    private Long total;
    private Integer page;
    private Integer size;
    private List<SearchHit> hits;
    private boolean cached;

    @Data
    public static class SearchHit {
        private Long articleId;
        private String title;
        private String summary;
        private List<String> contentHighlights;
        private String categoryName;
        private List<String> tagNames;
        private String authorName;
        private LocalDateTime updatedAt;
    }
}
