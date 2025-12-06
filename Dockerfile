FROM hexpm/elixir:1.14.5-erlang-26.0.2-debian-bullseye-20230612 as build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set environment variables
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy and install dependencies
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy source code
COPY lib ./lib
COPY priv ./priv
COPY assets ./assets

# Build assets and digest
RUN mix assets.deploy

# Compile the app
RUN mix compile

# Build the release
RUN mix release

# Runtime stage
FROM debian:bullseye-slim AS app

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Set environment variable to enable the Phoenix server
ENV PHX_SERVER=true

WORKDIR /app

# Copy the release
COPY --from=build /app/_build/prod/rel/expense_pilot ./
COPY --from=build /app/config/certs/global-bundle.pem /etc/ssl/certs/ca-certificates.pem
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.pem

# Copy entrypoint script
COPY docker-entrypoint.sh ./
RUN chmod +x /app/docker-entrypoint.sh

CMD ["/app/docker-entrypoint.sh"]
