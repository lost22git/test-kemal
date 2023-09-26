FROM crystallang/crystal:latest-alpine as builder

WORKDIR /project

ARG http_proxy

RUN export HTTP_PROXY=${http_proxy} && export HTTPS_PROXY=${http_proxy}
RUN apk add --update --no-cache --force-overwrite sqlite-dev sqlite-static

COPY . .

RUN shards build --release --static --stats --time



FROM alpine:latest

WORKDIR /app

COPY --from=builder --chmod=777 /project/bin ./bin
COPY --from=builder /project/fighter.db ./

EXPOSE 3000/tcp

ENTRYPOINT ["./bin/test-kemal"]
