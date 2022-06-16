FROM hashicorp/terraform:1.0.9

RUN apk --no-cache add curl

ENV PROVIDER=google
RUN curl -LO https://github.com/GoogleCloudPlatform/terraformer/releases/download/$(curl -s https://api.github.com/repos/GoogleCloudPlatform/terraformer/releases/latest | grep tag_name | cut -d '"' -f 4)/terraformer-${PROVIDER}-linux-amd64
RUN chmod +x terraformer-${PROVIDER}-linux-amd64
RUN mv terraformer-${PROVIDER}-linux-amd64 /usr/local/bin/terraformer

WORKDIR /terraform
