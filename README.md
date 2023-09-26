# test-kemal

an example of kemal

- sqlite
- static linking
- docker multi-stage build

## Installation

TODO: Write installation instructions here

## Usage

- build docker image `test-kemal`

```shell
docker build -t test-kemal --build-arg http_proxy=http://172.21.64.1:55556  .
```

- create docker network `mnet`

```shell
docker network create -o com.docker.network.bridge.name=mnet mnet
```

- run docker container `test-kemal` in network `mnet`

```shell
docker run -dit --name test-kemal --net mnet -p 3000:3000/tcp test-kemal
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/test-kemal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [lost22git](https://github.com/your-github-user) - creator and maintainer
