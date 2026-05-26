package com.kb.test;

import org.mockito.Mockito;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * 测试环境 Redis mock — 不实际连接 Redis
 */
@TestConfiguration
public class TestRedisConfig {

    @Bean
    @Primary
    public StringRedisTemplate stringRedisTemplate() {
        StringRedisTemplate mock = Mockito.mock(StringRedisTemplate.class);
        Mockito.when(mock.hasKey(Mockito.anyString())).thenReturn(false);
        return mock;
    }
}
