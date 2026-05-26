package com.kb;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@MapperScan("com.kb.*.mapper")
@EnableScheduling
public class KbApplication {
    public static void main(String[] args) {
        SpringApplication.run(KbApplication.class, args);
    }
}
