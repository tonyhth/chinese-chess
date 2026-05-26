package com.kb.search.config;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch.indices.CreateIndexRequest;
import co.elastic.clients.elasticsearch.indices.ExistsRequest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.InputStream;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
public class EsIndexInitializer implements ApplicationRunner {

    private static final String INDEX_NAME = "kb_article";

    private final ElasticsearchClient esClient;
    private final ObjectMapper objectMapper;

    @Override
    public void run(ApplicationArguments args) {
        try {
            boolean exists = esClient.indices()
                    .exists(ExistsRequest.of(e -> e.index(INDEX_NAME)))
                    .value();

            if (exists) {
                log.info("ES 索引 '{}' 已存在，跳过创建", INDEX_NAME);
                return;
            }

            ClassPathResource resource = new ClassPathResource("es/mapping.json");
            String mappingJson;
            try (InputStream is = resource.getInputStream()) {
                JsonNode root = objectMapper.readTree(is);
                mappingJson = objectMapper.writeValueAsString(root);
            }

            // 用 raw JSON 创建索引
            esClient.indices().create(c -> c
                    .index(INDEX_NAME)
            );

            log.info("ES 索引 '{}' 创建成功", INDEX_NAME);
        } catch (Exception e) {
            log.error("ES 索引初始化失败: {}", e.getMessage());
        }
    }
}
