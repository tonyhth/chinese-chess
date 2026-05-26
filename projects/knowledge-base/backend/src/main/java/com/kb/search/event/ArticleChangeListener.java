package com.kb.search.event;

import com.kb.search.service.EsSyncService;
import com.kb.search.service.SearchService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Slf4j
@Component
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class ArticleChangeListener {

    private final EsSyncService esSyncService;
    private final SearchService searchService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onArticleChange(ArticleChangeEvent event) {
        // 双写 ES
        esSyncService.sync(event.getEntityType(), event.getEntityId(), event.getOperation());
        // 清除搜索缓存
        searchService.evictAllSearchCache();
    }
}
