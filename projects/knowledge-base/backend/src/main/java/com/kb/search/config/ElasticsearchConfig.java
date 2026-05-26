package com.kb.search.config;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.json.jackson.JacksonJsonpMapper;
import co.elastic.clients.transport.rest_client.RestClientTransport;
import org.apache.http.HttpHost;
import org.elasticsearch.client.RestClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
public class ElasticsearchConfig {

    @Value("${spring.elasticsearch.uris}")
    private String esUris;

    @Bean
    public RestClient restClient() {
        // 支持逗号分隔多节点，格式: http://host:port 或 https://host:port
        String[] parts = esUris.split(",");
        HttpHost[] hosts = new HttpHost[parts.length];
        for (int i = 0; i < parts.length; i++) {
            hosts[i] = HttpHost.create(parts[i].trim());
        }
        return RestClient.builder(hosts).build();
    }

    @Bean
    public ElasticsearchClient elasticsearchClient(RestClient restClient) {
        RestClientTransport transport = new RestClientTransport(restClient, new JacksonJsonpMapper());
        return new ElasticsearchClient(transport);
    }
}
