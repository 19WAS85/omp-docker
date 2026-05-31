# syntax=docker/dockerfile:1
FROM oven/bun

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl git iptables \
      python3 python3-pip python3-venv ripgrep fd-find \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/omp-venv \
 && /opt/omp-venv/bin/pip install --no-cache-dir ipykernel
ENV PATH="/opt/omp-venv/bin:$PATH"

RUN bun install -g @oh-my-pi/pi-coding-agent @oh-my-pi/pi-natives

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable --profile minimal \
 && . "$HOME/.cargo/env" \
 && bun install -g @napi-rs/cli \
 && cd /root/.bun/install/global/node_modules/@anush008/tokenizers \
 && napi build --platform --release \
 && rustup self uninstall -y \
 && bun uninstall -g @napi-rs/cli

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint

ARG update-token
RUN omp update

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/entrypoint"]

CMD ["omp"]
