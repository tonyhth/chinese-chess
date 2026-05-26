FROM docker.elastic.co/elasticsearch/elasticsearch:8.12.0

# 安装 IK 分词插件（版本需与 ES 版本匹配）
RUN elasticsearch-plugin install --batch https://get.infini.cloud/elasticsearch/analysis-ik/8.12.0

# 复制自定义词典
COPY config/kb_custom.dic /usr/share/elasticsearch/config/analysis-ik/kb_custom.dic

# IK 配置中引用自定义词典（追加 ext_dict）
RUN sed -i 's|</properties>|<entry key="ext_dict">kb_custom.dic</entry>\n</properties>|' \
    /usr/share/elasticsearch/plugins/analysis-ik/config/IKAnalyzer.cfg.xml

ENV discovery.type=single-node
ENV xpack.security.enabled=false
ENV ES_JAVA_OPTS="-Xms512m -Xmx512m"
