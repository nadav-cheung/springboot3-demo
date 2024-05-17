# 基础镜像使用 OpenJDK 17 的官方镜像，这是因为它是预构建的，保证了基础环境的稳定和安全
FROM openjdk:17-slim as builder

# 设置作者或维护者的标签（可选）
LABEL maintainer="nadav.cheung@gmail.com"

# 更新软件包列表，并安装 Maven
RUN apt-get update && \
    apt-get install -y maven

# 验证 Maven 安装
RUN mvn -version

# 为我们的应用程序设置工作目录
WORKDIR application

# 首先只复制构建系统所需的文件（如 Maven/Gradle 的配置文件），这可以利用 Docker 的层缓存机制，提高后续构建速度
COPY pom.xml .

# 安装依赖，这样当依赖不变时，不会每次构建都重新下载
RUN mvn dependency:go-offline

# 现在复制源代码并构建实际的应用程序
COPY src src

# 使用 Maven 包装我们的应用程序
# 考虑到多核构建可以提高效率，我们可以使用 -T 选项
RUN mvn clean package -U -X -DskipTests -Dcheckstyle.skip=true

# 运行阶段，使用 JRE 图像可以减少最终镜像的大小
FROM openjdk:17

WORKDIR application

# 从构建阶段复制已经打包好的 jar 文件
COPY --from=builder application/target/*.jar application.jar

# 添加环境变量，例如时区
ENV TZ=Asia/Shanghai

# 解决时区问题
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置JAVA_OPTS环境变量
ENV JAVA_OPTS="-Xms512m -Xmx1024m"

# 暴露应用需要的端口
EXPOSE 8080

# 指定容器启动时执行的命令
CMD java $JAVA_OPTS -jar -jar application.jar
