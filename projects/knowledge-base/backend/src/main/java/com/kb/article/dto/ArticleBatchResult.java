package com.kb.article.dto;

import lombok.Data;

import java.util.List;

@Data
public class ArticleBatchResult {
    private int successCount;
    private int failCount;
    private List<Long> failedIds;

    public static ArticleBatchResult allSuccess(int count) {
        ArticleBatchResult r = new ArticleBatchResult();
        r.setSuccessCount(count);
        r.setFailCount(0);
        r.setFailedIds(List.of());
        return r;
    }

    public static ArticleBatchResult partial(int success, List<Long> failed) {
        ArticleBatchResult r = new ArticleBatchResult();
        r.setSuccessCount(success);
        r.setFailCount(failed.size());
        r.setFailedIds(failed);
        return r;
    }
}
