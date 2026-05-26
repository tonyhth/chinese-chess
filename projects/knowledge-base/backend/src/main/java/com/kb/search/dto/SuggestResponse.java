package com.kb.search.dto;

import lombok.Data;

import java.util.List;

@Data
public class SuggestResponse {
    private List<SuggestItem> suggestions;

    @Data
    public static class SuggestItem {
        private String text;
        private Long articleId;
    }
}
