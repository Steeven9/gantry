[![Release](https://img.shields.io/github/release/shizunge/gantry.svg)](https://github.com/shizunge/gantry/releases/latest)
[![Docker Pulls](https://img.shields.io/docker/pulls/shizunge/gantry.svg)](https://hub.docker.com/r/shizunge/gantry)
[![Docker Image Size](https://img.shields.io/docker/image-size/shizunge/gantry/latest.svg)](https://hub.docker.com/r/shizunge/gantry)
[![Build](https://github.com/shizunge/gantry/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/shizunge/gantry/actions/workflows/build.yml)
[![codecov](https://codecov.io/gh/shizunge/gantry/graph/badge.svg?token=47MWUJOH4Q)](https://codecov.io/gh/shizunge/gantry)

# Gantry - Docker service updater

[*Gantry*](https://github.com/shizunge/gantry) updates docker swarm services to newer images.

## Usage

*Gantry* automatically runs `docker service update` command to update selected services to newer images with the same tag. It is inspired by but [enhanced Shepherd](docs/migration.md).

*Gantry* is released as a container [image](https://hub.docker.com/r/shizunge/gantry). You can create a docker service and run it on a swarm manager node.

```
docker service create \
  --name gantry \
  --mode replicated-job \
  --constraint "node.role==manager" \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --env "GANTRY_NODE_NAME={{.Node.Hostname}}" \
  shizunge/gantry
```

Or with docker compose, see the [example](examples/README.md).

You can also run *Gantry* as a script outside the container `source ./src/entrypoint.sh`. *Gantry* is written to work with `busybox ash` as well as `bash`.

## Configurations

You can configure the most behaviors of *Gantry* via environment variables.

### Common ones

| Environment Variable  | Default |Description |
|-----------------------|---------|------------|
| GANTRY_LOG_LEVEL      | INFO | Control how many logs generated by *Gantry*. Valid values are `NONE`, `ERROR`, `WARN`, `INFO`, `DEBUG` (case sensitive). |
| GANTRY_NODE_NAME      |      | Add node name to logs. |
| GANTRY_POST_RUN_CMD   |      | Command(s) to `eval` after each updating iteration. |
| GANTRY_PRE_RUN_CMD    |      | Command(s) to `eval` before each updating iteration. |
| GANTRY_SLEEP_SECONDS  | 0    | Interval between two updates. Set it to 0 to run *Gantry* once and then exit. When this is a non-zero value, after an updating, *Gantry* will sleep until the next scheduled update. The actual sleep time is this value minus time spent on updating services. |
| TZ                    |      | Set timezone for time in logs. |

*Gantry* bases on Docker command line, [environment variables](https://docs.docker.com/engine/reference/commandline/cli/#environment-variables) for Docker command line also works for *Gantry*.

### To login to registries

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_REGISTRY_CONFIG        | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_CONFIG_FILE   | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_CONFIGS_FILE  | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_HOST          | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_HOST_FILE     | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_PASSWORD      | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_PASSWORD_FILE | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_USER          | | See [Authentication](#authentication). |
| GANTRY_REGISTRY_USER_FILE     | | See [Authentication](#authentication). |

### To select services

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_SERVICES_EXCLUDED         | | A space separated list of services names that are excluded from updating. |
| GANTRY_SERVICES_EXCLUDED_FILTERS | | A space separated list of [filters](https://docs.docker.com/engine/reference/commandline/service_ls/#filter), e.g. `label=project=project-a`. Exclude services which match the given filters from updating. Note that multiple filters will be logical **ANDED**. |
| GANTRY_SERVICES_FILTERS          | | A space separated list of [filters](https://docs.docker.com/engine/reference/commandline/service_ls/#filter) that are accepted by `docker service ls --filter` to select services to update, e.g. `label=project=project-a`. Note that multiple filters will be logical **ANDED**. |
| GANTRY_SERVICES_SELF             | | This is optional. When running as a docker service, *Gantry* will try to find the service name of itself automatically, and update itself firstly. The manifest inspection will be always performed on the *Gantry* service to avoid an infinity loop of updating itself. User can use this to ask *Gantry* to update another service firstly. |

### To check if new images are available

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_MANIFEST_CMD     | buildx | Valid values are `buildx`, `manifest`, and `none`.<br>Set which command for manifest inspection. Also see FAQ section [when to set `GANTRY_MANIFEST_CMD`](docs/faq.md#when-to-set-gantry_manifest_cmd).<ul><li>[`docker buildx imagetools inspect`](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/)</li><li>[`docker manifest inspect`](https://docs.docker.com/engine/reference/commandline/manifest_inspect/)</li></ul>Set to `none` to skip checking the manifest. As a result of skipping, `docker service update` always runs. In case you add `--force` to `GANTRY_UPDATE_OPTIONS`, you also want to disable the inspection. |
| GANTRY_MANIFEST_OPTIONS |       | [Options](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/#options) added to the `docker buildx imagetools inspect` or [options](https://docs.docker.com/engine/reference/commandline/manifest_inspect/#options) to `docker manifest inspect`, depending on `GANTRY_MANIFEST_CMD` value. |

### To add options to services update

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_ROLLBACK_ON_FAILURE    | true  | Set to `true` to enable rollback when updating fails. Set to `false` to disable the rollback. |
| GANTRY_ROLLBACK_OPTIONS       |       | [Options](https://docs.docker.com/engine/reference/commandline/service_update/#options) added to the `docker service update --rollback` command. |
| GANTRY_UPDATE_JOBS            | false | Set to `true` to update replicated-job or global-job. Set to `false` to disable updating jobs. |
| GANTRY_UPDATE_OPTIONS         |       | [Options](https://docs.docker.com/engine/reference/commandline/service_update/#options) added to the `docker service update` command. |
| GANTRY_UPDATE_TIMEOUT_SECONDS | 300   | Error out if updating of a single service takes longer than the given time. |

### After updating

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_CLEANUP_IMAGES           | true  | Set to `true` to clean up the updated images. Set to `false` to disable the cleanup. Before cleaning up, *Gantry* will try to remove any *exited* and *dead* containers that are using the images. |
| GANTRY_CLEANUP_IMAGES_OPTIONS   |       | [Options](https://docs.docker.com/engine/reference/commandline/service_create/#options) added to the `docker service create` command to create a global job for images removal. You can use this to add a label to the service or the containers. |
| GANTRY_NOTIFICATION_APPRISE_URL |       | Enable notifications on service update with [apprise](https://github.com/caronc/apprise-api). This must point to the notification endpoint (e.g. `http://apprise:8000/notify`) |
| GANTRY_NOTIFICATION_TITLE       |       | Add an additional message to the notification title. |

## Authentication

If you only need to login to a single registry, you can use the environment variables  `GANTRY_REGISTRY_USER`, `GANTRY_REGISTRY_PASSWORD`, `GANTRY_REGISTRY_HOST` and `GANTRY_REGISTRY_CONFIG` to provide the authentication information. You may also use the `*_FILE` variants to pass the information through files. The files can be added to the service via [docker secret](https://docs.docker.com/engine/swarm/secrets/). `GANTRY_REGISTRY_HOST` and `GANTRY_REGISTRY_CONFIG` are optional. Use `GANTRY_REGISTRY_HOST` when you are not using Docker Hub. Use `GANTRY_REGISTRY_CONFIG` when you want to enable authentication for only selected services.

If the images of services are hosted on multiple registries that are required authentication, you should provide a configuration file to the *Gantry* and set `GANTRY_REGISTRY_CONFIGS_FILE` correspondingly. You can use [docker secret](https://docs.docker.com/engine/swarm/secrets/) to provision the configuration file. The configuration file must be in the following format:

* Each line should contain 4 columns, which are either `<TAB>` or `<SPACE>` separated. The columns are 
```
<config name> <host> <user> <password>
```
> * config name: an identifier for the account.
> * host: the registry to authenticate against, e.g. docker.io.
> * user: the user name to authenticate as.
> * password: the password to authenticate with.
* Lines starting with  `#` are comments.
* Empty lines, comment lines and invalid lines are ignored.

You need to tell *Gantry* to use a named config rather than the default one when updating a particular service. The named configurations are set via either `GANTRY_REGISTRY_CONFIG`, `GANTRY_REGISTRY_CONFIG_FILE` or `GANTRY_REGISTRY_CONFIGS_FILE`. This can be done by adding the following label to the service `gantry.auth.config=<config-name>`. *Gantry* creates [Docker configuration files](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files) and adds `--config <config-name>` to the Docker command line for the corresponding services.

> NOTE: You also want to manually add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` and `GANTRY_ROLLBACK_OPTIONS` when you enable authentication.

> NOTE: You can use `GANTRY_REGISTRY_CONFIGS_FILE` together with other authentication environment variables.

> NOTE: *Gantry* uses `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER` to obtain Docker Hub rate when `GANTRY_REGISTRY_HOST` is empty or `docker.io`. You can also use their `_FILE` variants. If either password or user is empty, *Gantry* reads the Docker Hub rate for anonymous users.

## FAQ

[FAQ](docs/faq.md)

[Migrate from *Shepherd*](docs/migration.md)

## Development

*Gantry* is written to work with `busybox ash` (v1.35+), thus it could run easily in an alpine-based container without additional packages installed. One exception is that the notification feature requires `curl`. *Gantry* is also tested in `bash`.

[shellcheck](https://github.com/koalaman/shellcheck) will run on push to enforce the best practices of writing shell scripts. Some checks are disabled thanks to `busybox ash` supports more features than POSIX `sh`. You can find the list of disabled checks in [.shellcheckrc](.shellcheckrc).

To run `shellcheck` locally:
```
shellcheck src/*.sh tests/*.sh
```

[The tests folder](./tests) contains end-to-end tests, which cover the majority of the configuration options.

## Contacts

If you have any problems or questions, please contact me through a [GitHub issue](https://github.com/shizunge/gantry/issues).
