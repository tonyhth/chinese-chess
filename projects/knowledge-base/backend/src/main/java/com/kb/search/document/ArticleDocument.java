package com.kb.search.document;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class ArticleDocument {
    private Long articleId;
    private String title;
    private TitleSuggest titleSuggest;
    private String summary;
    private String content;
    private Long categoryId;
    private String categoryName;
    private List<Long> tagIds;
    private List<String> tagNames;
    private Long authorId;
    private String authorName;
    private String status;
    private LocalDateTime updatedAt;

    @Data
    public static class TitleSuggest {
        private List<String> input;
        private int weight;

        public static TitleSuggest of(String title) {
            TitleSuggest suggest = new TitleSuggest();
            suggest.setInput(List.of(title));
            suggest.setWeight(10);
            return suggest;
        }
    }
}
