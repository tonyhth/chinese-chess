package com.kb.search.event;

import lombok.Getter;

@Getter
public class ArticleChangeEvent {
    private final String entityType;
    private final Long entityId;
    private final String operation; // CREATE, UPDATE, DELETE

    public ArticleChangeEvent(String entityType, Long entityId, String operation) {
        this.entityType = entityType;
        this.entityId = entityId;
        this.operation = operation;
    }
}
