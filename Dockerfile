
# Use the latest Erlang/OTP 25 image
FROM erlang:26.0.1

# Set environment variables
ENV ELIXIR_VERSION="v1.14.0" \
    LANG=C.UTF-8

# Install dependencies and Elixir
RUN set -xe \
    && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
    && ELIXIR_DOWNLOAD_SHA256="ac129e266a1e04cdc389551843ec3dbdf36086bb2174d3d7e7936e820735003b" \
    && curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
    && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/local/src/elixir \
    && tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
    && rm elixir-src.tar.gz \
    && cd /usr/local/src/elixir \
    && make install clean

# Install mix dependencies
RUN mix local.hex --force && mix local.rebar --force

# Set the working directory
WORKDIR /app


# COPY priv/models/llama/checkpoint.pb1 /app/checkpoint.pb1
# COPY priv/models/llama/checkpoint.pb2 /app/checkpoint.pb2
# COPY priv/models/llama/checkpoint.pb3 /app/checkpoint.pb3
# Copy project files
ADD . /app

# Expose port for the Phoenix server
EXPOSE 5000

# Command to run when starting the container
# CMD ["mix", "phx.server"]
CMD ["iex"]

# End of Dockerfile